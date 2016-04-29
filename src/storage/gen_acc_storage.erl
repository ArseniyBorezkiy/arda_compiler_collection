%% @doc Generic abstract key-value storage.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (gen_acc_storage).
-behaviour (gen_server).

%
% callbacks
%

-callback init () -> { ok, State :: term () } .
-callback terminate (State :: term ()) -> ok .

%
% api
%

-export ([
          % management
          start_link/2,
          add_module/2,          
          % interface
          call/3,
          cast/3,
          % internals
          create_table/2,
          delete_table/1,
          insert/3,
          insert_once/3,
          get/2,
          get_default/2,
          select/3,
          select_element/4,
          select_filter/4,
          delete/2,
          match_delete/3,
          match_filter_delete/4
        ]).

%
% gen server callbacks
%

-export ([
          init/1,
          handle_call/3,
          handle_cast/2,
          handle_info/2,
          terminate/2,
          code_change/3
        ]).

%
% headers
%

-include ("general.hrl").
-include ("gen_acc_storage.hrl").

%
% auxiliary types
%

-type name_t () :: atom () .
-type cmd_t ()  :: term () .

%
% basic types
%

-type fatalizer_t ()     :: fun ((format_t ()) -> ok) .
-type handler_t ()       :: function () .
-type handler_entry_t () :: { name_t (), handler_t () } .

-record (s, { modules    :: dict_t (name_t (), term ()),
              handlers   :: dict_t (cmd_t (), handler_entry_t ()),
              fatalizer  :: fatalizer_t () }).

% =============================================================================
% API
% =============================================================================

%
% management
%

-spec start_link
(
  Server    :: atom (),
  Fatalizer :: fatalizer_t ()
) -> { ok, pid () } | ignore | { error, term () } .

start_link (Server, Fatalizer) ->
  ?validate_function (Fatalizer, 1),
  gen_server:start_link ({ local, Server }, ?MODULE, [ Fatalizer ], []).

-spec add_module
(
  Server :: atom (),
  Module :: atom ()
) -> ok.

add_module (Server, Module) ->
  ?validate_atom (Module),
  gen_server:cast (Server, { add, module, Module }).

%
% interface
%

-spec call
(
  Server  :: atom (),
  Command :: term (),
  Args    :: term ()
) -> term () | error.

call (Server, Command, Args) ->
  case gen_server:call (Server, { command, Command, Args }) of
    error  -> throw (?e_error);
    Result -> Result
  end.

-spec cast
(
  Server  :: atom (),
  Command :: term (),
  Args    :: term ()
) -> ok.

cast (Server, Command, Args) ->
  gen_server:cast (Server, { command, Command, Args }).

%
% internal creaters and deleters
%

-spec create_table
(
  Table :: atom (),
  Type  :: set | ordered_set | bag | duplicate_bag
) -> tid_t ().

create_table (Table, Type) ->
  ?validate (Type, [ set, ordered_set, bag, duplicate_bag ]),
  ets:new (Table, [ Type, private, { keypos, 2 } ]).

-spec delete_table
(
  Table :: atom ()
) -> ok.

delete_table (Table) ->
  ets:delete (Table),
  ok.

%
% internal setters
%

-spec insert
(
  Table :: atom (),
  Key   :: term (),
  Value :: term ()
) -> ok.

insert (Table, Key, Value) ->
  ets:insert (Table, #gas_entry { k = Key, v = Value }),
  ok.

-spec insert_once
(
  Table :: atom (),
  Key   :: term (),
  Value :: term ()
) -> ok.

insert_once (Table, Key, Value) ->
  case ets:insert (Table, #gas_entry { k = Key, v = Value }) of
    true  -> ok;
    false -> throw (?e_key_exists (Key))
  end.

%
% internal getters
%

-spec get
(
  Table :: atom (),
  Key   :: term ()
) -> term ().

get (Table, Key) ->
  case ets:lookup (Table, Key) of
    [] -> throw (?e_key_not_exists (Key));
    [ #gas_entry { k = Key, v = Value } ] -> Value;
    [ _ | _ ] -> throw (?e_key_ambiguity (Key))
  end.

-spec get_default
(
  Table :: atom (),
  Key   :: term ()
) -> undefined | term ().

get_default (Table, Key) ->
  case ets:lookup (Table, Key) of
    [] -> undefined;
    [ #gas_entry { k = Key, v = Value } ] -> Value;
    [ _ | _ ] -> throw (?e_key_ambiguity (Key))
  end.

-spec select
(
  Table       :: atom (),
  Key         :: term (),
  Value       :: term ()
) -> list (gas_entry_t ()).

select (Table, Key, Value) ->
  ets:select (Table, [ { #gas_entry { k = Key, v = Value }, [], [ '$_' ] } ]).

-spec select_element
(
  Table       :: atom (),
  Key         :: term (),
  Value       :: term (),
  Out         :: term ()
) -> list (term ()).

select_element (Table, Key, Value, Out)
  when Out =/= '$_' ->
  ?validate_atom (Out),
  ets:select (Table, [ { #gas_entry { k = Key, v = Value }, [], [ Out ] } ]).

-spec select_filter
(
  Table       :: atom (),
  Key         :: term (),
  Value       :: term (),
  Filter      :: fun ((gas_entry_t ()) -> boolean ())
) -> list (gas_entry_t ()).

select_filter (Table, Key, Value, Filter) ->
  ?validate_function (Filter, 1),
  Fun     = fun (Entry) -> Filter (Entry) end,
  Entries = ets:select (Table, [ { #gas_entry { k = Key, v = Value }, [], [ '$_' ] } ]),
  lists:filter (Fun, Entries).

%
% internal unsetters
%

-spec delete
(
  Table :: atom (),
  Key   :: term ()
) -> ok.

delete (Table, Key) ->
  get (Table, Key),
  ets:delete (Table, Key),
  ok.

-spec match_delete
(
  Table       :: atom (),
  Key         :: term (),
  Value       :: term ()
) -> list (gas_entry_t ()).

match_delete (Table, Key, Value) ->
  Entries = select (Table, Key, Value),
  Fun     = fun (#gas_entry { k = Key }) -> ets:delete (Table, Key) end,
  lists:foreach (Fun, Entries),
  Entries.

-spec match_filter_delete
(
  Table       :: atom (),
  Key         :: term (),
  Value       :: term (),
  Filter      :: fun ((gas_entry_t ()) -> boolean ())
) -> list (gas_entry_t ()).

match_filter_delete (Table, Key, Value, Filter) ->
  Entries = select (Table, Key, Value),
  Fun =
    fun (#gas_entry { k = Key } = Entry) ->
      case Filter (Entry) of
        false -> false;
        true  ->
          ets:delete (Table, Key),
          true
      end
    end,
  lists:filter (Fun, Entries).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

init ([ Fatalizer ]) ->
  process_flag (trap_exit, true),
  State = #s { fatalizer = Fatalizer,
               modules   = dict:new (),
               handlers  = dict:new () },
  { ok, State }.

terminate (_, State) ->
  Fun =
    fun (Module) ->
      Data = dict:fetch (Module, State#s.modules),
      Module:terminate (Data)
    end,
  lists:foreach (Fun, dict:fetch_keys (State#s.modules)),
  ok.

handle_info (_, State) ->
  { noreply, State }.

code_change (_, State, _) ->
  { ok, State }.

%
% call dispatchers
%

handle_call ({ command, Command, Args }, _, State) ->
  { reply, Reply, NewState } = handle_command (Command, Args, State),
  { reply, Reply, NewState }.

%
% cast dispatchers
%

handle_cast ({ add, module, Module }, State) ->
  case dict:is_key (Module, State#s.modules) of
    false ->
      { ok, Data, Handlers } = Module:init (),
      Fun =
        fun ({ Command, Handler }, Dict) ->
          dict:store (Command, { Module, Handler }, Dict)
        end,
      Dict1 = lists:foldl (Fun, State#s.handlers, Handlers),
      Dict2 = dict:store (Module, Data, State#s.modules),
      { noreply, State#s { handlers = Dict1, modules = Dict2 }};
    true ->
      (State#s.fatalizer) (?str_gas_module_exists (Module)),
      { noreply, State }
  end;

handle_cast ({ command, Command, Args }, State) ->
  { reply, _Reply, NewState } = handle_command (Command, Args, State),
  { noreply, NewState }.
  
% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

handle_command (Command, Args, State) ->
  case dict:is_key (Command, State#s.handlers) of
    false ->
      (State#s.fatalizer) (?str_gas_command_not_exists (Command)),
      { reply, error, State };
    true ->
      { Module, Handler } = dict:fetch (Command, State#s.handlers),
      Data = dict:fetch (Module, State#s.modules),
      try Handler (Args, Data) of
        { reply, Reply, NewData } ->
          Dict = dict:store (Module, NewData, State#s.modules),
          { reply, Reply, State#s { modules = Dict } };
        { noreply, NewData } ->
          Dict = dict:store (Module, NewData, State#s.modules),
          { reply, ok, State#s { modules = Dict } };
        { fatalize, Resource } ->
          (State#s.fatalizer) (Resource),
          { reply, error, State }
      catch
        throw : ?e_key_exists (Key) ->
          (State#s.fatalizer) (?str_gas_key_exists (Key)),
          { reply, error, State };
        throw : ?e_key_not_exists (Key) ->
          (State#s.fatalizer) (?str_gas_key_not_exists (Key)),
          { reply, error, State };
        throw : ?e_key_ambiguity (Key) ->
          (State#s.fatalizer) (?str_gas_many_object_exists (Key)),
          { reply, error, State };
        throw : ?e_module_runtime (Resource) ->
          (State#s.fatalizer) (Resource),
          { reply, error, State };
        error : undef ->
          (State#s.fatalizer) (?str_gas_command_not_exists (Command)),
          { reply, error, State }
      end
  end.
