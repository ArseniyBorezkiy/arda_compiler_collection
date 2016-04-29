%% @doc Flexible debug service.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (acc_debug).

%
% api
%

-export ([
          % supervisor
          start_link/4,
          % settings
          set_console_level/1,
          set_log_level/1,
          set_language/1,
          get_language/0,
          % print
          log/3,
          % tools
          sprintf/2,
          parse_int/1
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

%
% basic types
%

-type level_t () :: unsigned_t ().

-record (state, { language :: atom (),
                  c_level  :: level_t (),
                  f_level  :: level_t (),
                  handle   :: io_device_t () }).

% =============================================================================
% API
% =============================================================================

%
% supervisor
%

start_link (File, Levf, Levc, Lang) ->
  Args = { File, Levf, Levc, Lang },
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, Args, []).

%
% settings
%

set_console_level (Level)
  when is_integer (Level), Level >= 0 ->
  gen_server:cast (?MODULE, { c_level, Level }).

set_log_level (Level)
  when is_integer (Level), Level >= 0 ->
  gen_server:cast (?MODULE, { f_level, Level }).

set_language (Language) ->
  ?validate (Language, ?languages),
  gen_server:cast (?MODULE, { language, set, Language }).

get_language () ->
  gen_server:call (?MODULE, { language, get }).

%
% low level api
%

log (Module, Level, Resource)
  when is_integer (Level), Level >= 0 ->
  Message = acc_resource:encode (Resource),
  gen_server:cast (?MODULE, { log, Module, Level, Message }).

%
% tools
%

sprintf (Message, Args) ->
  lists:flatten (io_lib:format (Message, Args)).

parse_int (String) ->
  case string:to_integer (String) of
    { error, _ } -> throw (error);
    { Int, _ } -> Int
  end.
    
% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

%
% intialization
%

init ({ File, Levf, Levc, Lang }) ->
  process_flag (trap_exit, true),
  { ok, Handle } = file:open (File, [ append ]),
  { Year, Month, Day } = erlang:date (),
  { Hour, Min, Sec }   = erlang:time(),
  Format   = "~p.~p.~p at ~p:~p:~p",
  Args     = [ ?BC_VERSION, ?FC_VERSION, Day, Month, Year, Hour, Min, Sec ],
  log_entry (Handle, "~n*** ", ?MODULE, "acc ~p.~p started " ++ Format, Args),
  Greeting = "Arda compiler collection server ~p.~p.~n~n",
  io:format (Greeting, [ ?BC_VERSION, ?FC_VERSION ]),
  { ok, #state { c_level  = Levc,
                 f_level  = Levf,
                 handle   = Handle,
                 language = Lang } }.

%
% dispatchers
%

handle_call ({ language, get }, _, State) ->
  { reply, State#state.language, State };

handle_call (_, _, State) ->
  { reply, ok, State }.

handle_cast ({ c_level, Level }, State) ->
  { noreply, State#state { c_level = Level } };

handle_cast ({ f_level, Level }, State) ->
  { noreply, State#state { f_level = Level } };

handle_cast ({ log, Module, Level, Message }, State) ->
  Prefix =
    case Level of
      ?DL_ERROR   -> "!!! ";
      ?DL_WARNING -> "! ";
      ?DL_SUCCESS -> "* ";
      _ -> ""
    end,
  case Level =< State#state.c_level of
    true  -> io:format ("~s~p: ~s.~n", [ Prefix, Module, Message ]);
    false -> ok
  end,
  Handle = State#state.handle,
  case Level =< State#state.f_level of
    true  -> log_entry (Handle, Prefix, Module, Message, []);
    false -> ok
  end,
  { noreply, State };

handle_cast ({ language, set, Language }, State) ->
  { noreply, State#state { language = Language } };

handle_cast (_, State) ->
  { noreply, State }.

%
% other
%

code_change (_, State, _) ->
  { ok, State }.

handle_info (_Info, State) ->
  { noreply, State }.

terminate (Reason, State) ->
  Handle = State#state.handle,
  { Year, Month, Day } = erlang:date (),
  { Hour, Min, Sec }   = erlang:time(),
  Format  = "~p.~p.~p at ~p:~p:~p",
  Args    = [ Day, Month, Year, Hour, Min, Sec ],
  case Reason of
    normal ->
      Message = "al normally shutdowned " ++ Format,
      log_entry (Handle, "*** ", ?MODULE, Message, Args);
    _ ->
      Message = "al terminated abnormally " ++ Format,
      log_entry (Handle, "!!! ", ?MODULE, Message, Args)
  end,
  file:close (Handle),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

log_entry (Handle, Prefix, Module, Message, Args) ->
  Format = Prefix ++ "~p: " ++ Message ++ ".~n",
  Text   = lists:flatten (io_lib:format (Format, [ Module | Args ])),
  file:write (Handle, list_to_binary (Text)).
