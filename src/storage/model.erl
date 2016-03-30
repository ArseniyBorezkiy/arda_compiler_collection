%% @doc Generic dynamically described grammatical model.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (model).
-behaviour (gen_server).

% API
-export ([
          % management
          start_link/0,
          % payload
          create_entity/2,
          create_property/3,
          create_match/1,
          create_rule/3,
          create_regexp/4,
          create_guard/4,
          get_entities/0,
          get_properties/1,
          ensure/2,
          ensure/3
        ]).

% GEN SERVER CALLBACKS
-export ([
          init/1,
          handle_call/3,
          handle_cast/2,
          handle_info/2,
          terminate/2,
          code_change/3
        ]).

% HEADERS
-include ("model.hrl").

% STATE
-record (s, { model  :: ets:tid (),
              rules  :: ets:tid (),
              dict   :: dict:dict () }).

% =============================================================================
% API
% =============================================================================

%
% management
%

start_link () ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, [], []).

%
% model setters
%

create_entity (Entity, Type) ->
  Key = Entity,
  Object = #entity { name = Entity,
                     type = Type },
  gen_server:cast (?MODULE, { model, create, Key, Object }).

create_property (Entity, Property, Value) ->
  Key = Property,
  Object = #property { name   = Property,
                       value  = Value,
                       entity = Entity },
  gen_server:cast (?MODULE, { model, create, Key, Object }).

create_match (Name) ->
  Key = Name,
  Object = #match { name = Name },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

create_rule (Match, Ordinal, Name) ->
  Key = { Match, Ordinal },
  Object = #rule { instance = Key, name = Name },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

create_regexp (Match, Ordinal, Expression, Filters) ->
  Key = { Match, Ordinal },
  Object = #regexp { instance = Key, expression = Expression, filters = Filters },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

create_guard (Match, Ordinal, Entity, Property) ->
  Key = { Match, Ordinal },
  Object = #guard { instance = Key, entity = Entity, property = Property },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

%
% model getters
%

get_entities () ->
  Mask = #entity { name = '$1', type = '_' },
  gen_server:call (?MODULE, { model, select, Mask }).

get_properties (Entity) ->
  Mask = #property { name = '$1', entity = Entity },
  gen_server:call (?MODULE, { model, select, Mask }).

%
% model parametres
%

ensure (Name, Value) ->
  ensure (Name, Value, fun (Value0) -> Value0 =:= Value end).

ensure (Name, Value, Condition)
  when is_function (Condition) ->
  gen_server:cast (?MODULE, { ensure, Name, Value, Condition }).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

init ([]) ->
  process_flag (trap_exit, true),
  Model = ets:new ('model storage', [ set, private, { keypos, 2 } ]),
  Rules = ets:new ('rules storage', [ bag, private, { keypos, 2 } ]),
  Dict  = dict:new (),
  State = #s { model = Model, rules = Rules, dict = Dict },
  { ok, State }.

terminate (_, _State) ->
  ok.

handle_info (_, State) ->
  { noreply, State }.

code_change (_, State, _) ->
  { ok, State }.

%
% dispatchers
%

handle_call ({ Target, select, Mask }, _, State) ->
  Table =
    case Target of
      rule  -> State#s.rules;
      model -> State#s.model
    end,
  Result = ets:select (Table, [ { Mask, [], ['$_'] } ]),
  { reply, Result, State }.

handle_cast ({ Target, create, Key, Object }, State) ->
  case Target of
    rule ->
      Table = State#s.rules,
      case ets:lookup (Table, Key) of
        [] -> ets:insert (Table, Object);
        Objects ->
          case lists:member (Object, Objects) of
            false -> ets:insert (Table, Object);
            true  ->
              debug:error (?MODULE, "redefinition of ~p", [ Object ]),
              dispatcher:fatal_error ()
          end
      end;
    model ->
      Table = State#s.model,
      case ets:lookup (Table, Key) of
        [] -> ets:insert (Table, Object);
        [ Other | _ ] ->
          debug:error (?MODULE, "redefinition of ~p as ~p", [ Object, Other ]),
          dispatcher:fatal_error ()
      end
  end,
  { noreply, State };

handle_cast ({ ensure, Name, Value, Condition }, State) ->
  Dict1 = State#s.dict,
  Dict2 =
    case dict:is_key (Name, Dict1) of
      false -> dict:store (Name, [ Value ], Dict1);
      true  ->        
        Values = dict:fetch (Name, Dict1),
        case lists:all (Condition, Values) of
          true  -> dict:store (Name, [ Value | Values ], Dict1);
          false ->
            Format = "insurance of ~p failed cause of ~p incompatible with ~p",
            debug:error (?MODULE, Format, [ Name, Value, Values ]),
            dispatcher:fatal_error (),
            Dict1
        end
    end,
  { noreply, State#s { dict = Dict2 } }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================
