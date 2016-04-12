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
          dump/1,
          % payload
          create_entity/2,
          create_entity/3,
          create_property/2,
          create_property/3,
          create_rule/4,
          create_regexp/5,
          create_guard/5,
          create_stem/2,
          create_characteristic/3,
          get_entities/0,
          get_properties/1,
          get_entity_name/1,
          get_subrules/1,
          get_guards/2,
          get_stems/0,
          get_vocabularies/1,
          get_characteristics/2,
          ensure/1,
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
              voc    :: ets:tid (),
              dict   :: dict:dict () }).

% =============================================================================
% API
% =============================================================================

%
% management
%

start_link () ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, [], []).

dump (Target) ->
  gen_server:call (?MODULE, { Target, select, '_', '$_' }).

%
% setters
%

create_entity (Entity, Type) ->
  create_entity (Entity, Type, "").

create_entity (Entity, Type, Tag) ->
  Key = Entity,
  Object = #entity { name = Entity,
                     type = Type,
                     tag  = Tag },
  gen_server:cast (?MODULE, { model, create, Key, Object }).

create_property (Entity, Property) ->
  create_property (Entity, Property, "").

create_property (Entity, Property, Value) ->
  Key = Property,
  Object = #property { name   = Property,
                       value  = Value,
                       entity = Entity },
  gen_server:cast (?MODULE, { model, create, Key, Object }).

create_rule (Match, OrdinalX, OrdinalY, Name) ->
  Key = { Match, OrdinalX, OrdinalY },
  Object = #rule { instance = Key, name = Name },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

create_regexp (Match, OrdinalX, OrdinalY, Expression, Filters) ->
  Key = { Match, OrdinalX, OrdinalY },
  Object = #regexp { instance = Key, expression = Expression, filters = Filters },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

create_guard (Match, OrdinalX, OrdinalY, Entity, Property) ->
  Key = { Match, OrdinalX, OrdinalY },
  Object = #guard { instance = Key, entity = Entity, property = Property },
  gen_server:cast (?MODULE, { rule, create, Key, Object }).

create_stem (Vocabulary, Stem) ->
  Key = Stem,
  Object = #stem { stem = Stem, vocabulary = Vocabulary },
  gen_server:cast (?MODULE, { voc, create, Key, Object }).

create_characteristic (Vocabulary, Stem, Property) ->
  Key = { Stem, Property },
  Object = #characteristic { instance = Key, vocabulary = Vocabulary },
  gen_server:cast (?MODULE, { voc, create, Key, Object }).

%
% getters
%

get_entities () ->
  Mask = #entity { name = '$1', type = '_', tag = '_' },
  gen_server:call (?MODULE, { model, select, Mask, '$_' }).

get_properties (Entity) ->
  Mask = #property { name = '$1', value = '$2', entity = Entity },
  gen_server:call (?MODULE, { model, select, Mask, '$_' }).

get_entity_name (Property) ->
  Mask = #property { name = Property, value = '_', entity = '$1' },
  case gen_server:call (?MODULE, { model, select, Mask, '$1' }) of
    [] ->
      debug:error (?MODULE, "undefined property '~s'", [ Property ]),
      dispatcher:fatal_error ();
    [ Name ] -> Name
  end.

get_subrules (Match) ->
  Mask1     = #rule { instance = { Match, '_', '$1' }, name = '_' },
  Ordinals1 = gen_server:call (?MODULE, { rule, select, Mask1, '$1' }),
  Mask2     = #regexp { instance = { Match, '_', '$1' }, expression = '_', filters = '_' },
  Ordinals2 = gen_server:call (?MODULE, { rule, select, Mask2, '$1' }),
  OrdinalsY = sets:to_list(sets:from_list(lists:sort (Ordinals1 ++ Ordinals2))),
  Fun =
    fun (OrdinalY) ->
      SubMask1   = #rule { instance = { Match, '$1', OrdinalY }, name = '_' },
      SubRules1  = gen_server:call (?MODULE, { rule, select, SubMask1, '$_' }),
      SubMask2   = #regexp { instance = { Match, '$1', OrdinalY }, expression = '_', filters = '_' },
      SubRules2  = gen_server:call (?MODULE, { rule, select, SubMask2, '$_' }),
      GetX       =
        fun
          (#rule { instance = { _, OrdinalX, _ } }) -> OrdinalX;
          (#regexp { instance = { _, OrdinalX, _ } }) -> OrdinalX
        end,
      Comparator =
        fun (E1, E2) ->
          GetX (E1) < GetX (E2)
        end,
      lists:sort (Comparator, SubRules1 ++ SubRules2)
    end,
  lists:map (Fun, OrdinalsY).

get_guards (Match, OrdinalY) ->
  Mask = #guard { instance = { Match, '_', OrdinalY }, entity = '_', property = '$1' },
  gen_server:call (?MODULE, { rule, select, Mask, '$1' }).

get_stems () ->
  Mask = #stem { stem = '$1', vocabulary = '_' },
  gen_server:call (?MODULE, { voc, select, Mask, '$1' }).

get_vocabularies (Stem) ->
  Mask = #stem { stem = Stem, vocabulary = '$1' },
  gen_server:call (?MODULE, { voc, select, Mask, '$1' }).

get_characteristics (Vocabulary, Stem) ->
  Mask = #characteristic { instance = { Stem, '$1' }, vocabulary = Vocabulary },
  gen_server:call (?MODULE, { voc, select, Mask, '$1' }).

%
% parametres
%

ensure (Name) ->
  case gen_server:call (?MODULE, { ensure, Name }) of
    false -> throw (error);
    { true, Value } -> Value
  end.

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
  Voc   = ets:new ('vocabular storage', [ set, private, { keypos, 2 } ]),
  Dict  = dict:new (),
  State = #s { model = Model, rules = Rules, voc = Voc, dict = Dict },
  { ok, State }.

terminate (_, State) ->
  Model = State#s.model,
  Rules = State#s.rules,
  Voc   = State#s.voc,
  ets:delete (Model),
  ets:delete (Rules),
  ets:delete (Voc),
  ok.

handle_info (_, State) ->
  { noreply, State }.

code_change (_, State, _) ->
  { ok, State }.

%
% dispatchers
%

handle_call ({ Target, select, MaskIn, MaskOut }, _, State) ->
  Table =
    case Target of
      rule  -> State#s.rules;
      model -> State#s.model;
      voc   -> State#s.voc
    end,
  Result = ets:select (Table, [ { MaskIn, [], [ MaskOut ] } ]),
  { reply, Result, State };

handle_call ({ ensure, Name }, _, State) ->
  Dict  = State#s.dict,
  Value =
    case dict:is_key (Name, Dict) of
      true  -> { true, dict:fetch (Name, Dict) };
      false ->
        Format = "insurance of '~p' failed cause of avoid",
        debug:error (?MODULE, Format, [ Name ]),
        dispatcher:fatal_error (),
        false
    end,
  { reply, Value, State }.

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
              debug:error (?MODULE, "redefinition of ~p for ~p", [ Object, Key ]),
              dispatcher:fatal_error ()
          end
      end;
    model ->
      Table = State#s.model,
      case ets:lookup (Table, Key) of
        [] -> ets:insert (Table, Object);
        [ Other | _ ] ->
          debug:error (?MODULE, "redefinition of ~p as ~p for ~p", [ Object, Other, Key ]),
          dispatcher:fatal_error ()
      end;
    voc ->
      Table = State#s.voc,
      case ets:lookup (Table, Key) of
        [] -> ets:insert (Table, Object);
        [ Other | _ ] ->
          debug:error (?MODULE, "redefinition of ~p as ~p for ~p", [ Object, Other, Key ]),
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
