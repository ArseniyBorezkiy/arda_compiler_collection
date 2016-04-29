%% @doc Dynamically described model's entity module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (am_entity).
-behaviour (gen_acc_storage).

%
% api
%

-export ([
          create_entity/4,
          add_property_value/5,
          create_child_entity/6,
          select_entities/3,
          select_child_entities/5,
          find_entity/4,
          delete_entities/4,
          get_entity_value/3,
          get_parent_entity/3,
          get_recursive_properties/4
        ]).

%
% gen acc storage callbacks
%

-export ([
          init/0,
          terminate/1
        ]).

%
% headers
%

-include ("general.hrl").
-include ("gen_acc_storage.hrl").
-include ("am_entity.hrl").

%
% basic types
%

-record (s, { table :: tid_t () }).

% =============================================================================
% API
% =============================================================================

-spec create_entity
(
  Server     :: atom (),
  Name       :: string (),
  Type       :: atom (),
  Properties :: list (term ())
) -> ok.

create_entity (Server, Name, Type, Properties) ->
  ?validate_list (Name),
  ?validate_atom (Type),
  ?validate_list (Properties),
  gen_acc_storage:cast (Server, create_entity, { Name, Type, Properties }).

-spec add_property_value
(
  Server     :: atom (),
  Name       :: string (),
  Type       :: atom (),
  PropName   :: atom (),
  PropValue  :: term ()
) -> ok.

add_property_value (Server, Name, Type, PropName, PropValue) ->
  ?validate_list (Name),
  ?validate_atom (Type),
  ?validate_atom (PropName),
  gen_acc_storage:cast (Server, add_property, { Name, Type, PropName, PropValue }).

-spec create_child_entity
(
  Server     :: atom (),
  Base       :: string (),
  Type1      :: atom (),
  Name       :: atom (),
  Type2      :: atom (),
  Properties :: list (term ())
) -> ok.

create_child_entity (Server, Bases, Type1, Name, Type2, Properties) ->
  ?validate_list (Bases),
  ?validate_list (Name),
  ?validate_atom (Type1),
  ?validate_atom (Type2),
  ?validate_list (Properties),
  Fun     = fun (Base) -> { Base, Type1 } end,
  Parents = lists:map (Fun, Bases),
  create_entity (Server, Name, Type2, [ { base, Parents } | Properties ]).

-spec select_entities
(
  Server     :: atom (),
  Name       :: string (),
  Type       :: atom ()
) -> list (gas_entry_t ()).

select_entities (Server, Name, Type) ->
  ?validate_list (Name),
  ?validate_atom (Type),
  gen_acc_storage:call (Server, select_entity, { Name, Type, '_' }).

-spec select_child_entities
(
  Server     :: atom (),
  Base       :: atom (),
  Type1      :: atom (),
  Name       :: atom (),
  Type2      :: atom ()
) -> list (gas_entry_t ()).

select_child_entities (Server, Base, Type1, Name, Type2) ->
  ?validate_list (Base),
  ?validate_list (Name),
  ?validate_atom (Type1),
  ?validate_atom (Type2),
  Fun =
    fun (#gas_entry { v = #entity_v { properties = Props } }) ->
      case proplists:get_value (base, Props) of
        undefined -> false;
        Parents ->
          lists:member ({ Base, Type1 }, Parents)
      end
    end,
  lists:filter (Fun, select_entities (Server, Name, Type2)).

-spec find_entity
(
  Server      :: atom (),
  Type        :: atom (),
  PropName    :: atom (),
  SubPropName :: string ()
) -> gas_entry_t ().

find_entity (Server, Type, PropName, SubPropName) ->  
  ?validate_atom (Type),
  ?validate_atom (PropName),
  ?validate_list (SubPropName),
  Entries = gen_acc_storage:call (Server, select_entity, { '_', Type, '_' }),
  Fun =
    fun
      (#gas_entry { v = #entity_v { properties = Props }} = Entry, false) ->
        case proplists:get_value (PropName, Props) of
          undefined -> false;
          SubProps ->
            case proplists:get_value (SubPropName, SubProps) of
              undefined -> false;
              _ -> Entry
            end
        end;
      (_, Acc) -> Acc
    end,
  case lists:foldl (Fun, false, Entries) of
    false ->
      Error = ?str_ament_uentity (PropName, SubPropName),
      gen_acc_storage:cast (Server, fatalize, Error),
      throw (?e_error);
    Entry -> Entry
  end.

-spec delete_entities
(
  Server      :: atom (),
  Type        :: atom (),
  PropName    :: atom (),
  PropValue   :: atom ()
) -> list (gas_entry_t ()).

delete_entities (Server, Type, PropName, PropValue) ->  
  ?validate_atom (Type),
  ?validate_atom (PropName),
  ?validate_atom (PropValue),
  Filter =
    fun (#gas_entry { v = #entity_v { properties = Props }}) ->
      case proplists:get_value (PropName, Props) of
        PropValue -> true;
        _ -> false
      end
    end,
  gen_acc_storage:call (Server, delete_entity, { Type, Filter }).

-spec get_entity_value
(
  Server     :: atom (),
  Name       :: string (),
  Type       :: atom ()
) -> entity_v_t () | error.

get_entity_value (Server, Name, Type) ->
  ?validate_list (Name),
  ?validate_atom (Type),
  gen_acc_storage:call (Server, get_entity, { Name, Type }).

-spec get_parent_entity
(
  Server     :: atom (),
  Name       :: atom (),
  Type       :: atom ()
) -> gas_entry_t ().

get_parent_entity (Server, Name, Type) ->
  ?validate_list (Name),
  ?validate_atom (Type),
  Entity = get_entity_value (Server, Name, Type),
  case proplists:get_value (base, Entity#entity_v.properties) of
    { Base, Type0 } ->
      Value = get_entity_value (Server, Base, Type0),
      #gas_entry { k = #entity_k { name = Name, type = Type0 },
                   v = Value };
    undefined ->
      Error = ?str_ament_eorphan (Name, Type),
      gen_acc_storage:cast (Server, fatalize, Error),
      throw (?e_error)
  end.

-spec get_recursive_properties
(
  Server      :: atom (),
  Name        :: atom (),
  Type        :: atom (),
  PropName    :: term ()
) -> list (PropValue :: term ()).

get_recursive_properties (Server, Name, Type, PropName) ->
  ?validate_list (Name),
  ?validate_atom (Type),
  ?validate_atom (PropName),
  Key = #entity_k { name = Name, type = Type },
  Genealogist =
    fun (#gas_entry { v = #entity_v { properties = Props }}) ->
      case proplists:get_value (base, Props) of
        undefined -> [];
        Names ->
          Fun  =
            fun ({ Name0, Type0 }) ->
              #entity_k { name = Name0, type = Type0 }
            end,
          Keys = lists:map (Fun, Names),
          Keys
      end
    end,
  do_get_rec_properties ([ Key ], Server, PropName, Genealogist, []).

% =============================================================================
% GEN ACC STORAGE CALLBACKS
% =============================================================================

%
% prologue and epilogue
%

init () ->
  State = #s { table = gen_acc_storage:create_table (?MODULE, set) },
  Handlers = [ { create_entity, fun handle_entity_create/2 },
               { add_property, fun handle_entity_add_property/2 },
               { select_entity, fun handle_entity_select/2 },
               { get_entity, fun handle_entity_get/2 },
               { delete_entity, fun handle_entity_delete/2 },
               { fatalize, fun handle_entity_fatalize/2 } ],
  { ok, State, Handlers }.

terminate (_State) ->
  ok.

%
% dispatchers - entity
%

handle_entity_create ({ Name, Type, Props }, #s { table = Table } = State) ->
  try
    Key   = #entity_k { name = Name, type = Type },
    Value = #entity_v { properties = Props },
    gen_acc_storage:insert_once (Table, Key, Value),
    { noreply, State }
  catch
    throw : ?e_key_exists (_) ->
      { fatalize, ?str_ament_eredefine (Name, Type) }
  end.

handle_entity_add_property ({ Name, Type, PropName, PropValue }, #s { table = Table } = State) ->
  Key   = #entity_k { name = Name, type = Type },
  Value = gen_acc_storage:get (Table, Key),
  Props = Value#entity_v.properties,
  case proplists:get_value (PropName, Props) of
    undefined ->
      { fatalize, ?str_ament_pundefined (Name, Type, PropName) };
    PropValues when is_list (PropValues) ->
      Property = { PropName, [ PropValue | PropValues ] },
      NewProps = lists:keyreplace (PropName, 1, Props, Property),
      NewValue = Value#entity_v { properties = NewProps },
      gen_acc_storage:insert (Table, Key, NewValue),
      { noreply, State };
    _ ->
      { fatalize, ?str_ament_pnlist (Name, Type, PropName) }
  end.

handle_entity_select ({ Name, Type, Props }, #s { table = Table } = State) ->
  Key      = #entity_k { name = Name, type = Type },
  Value    = #entity_v { properties = Props },
  Entities = gen_acc_storage:select (Table, Key, Value),
  { reply, Entities, State }.

handle_entity_get ({ Name, Type }, #s { table = Table } = State) ->
  Key   = #entity_k { name = Name, type = Type },
  Value = gen_acc_storage:get (Table, Key),
  { reply, Value, State }.

handle_entity_delete ({ Type, Filter }, #s { table = Table } = State) ->
  Key      = #entity_k { name = '_', type = Type },
  Value    = #entity_v { properties = '_' },
  Entities = gen_acc_storage:match_filter_delete (Table, Key, Value, Filter),
  { reply, Entities, State }.

handle_entity_fatalize ({ Resource }, _State) ->
  { fatalize, Resource }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

do_get_rec_properties ([], _Server, _PropName, _Gen, Props) -> Props;
do_get_rec_properties ([ Key | Tail ], Server, PropName, Gen, Props1) ->
  Value  = get_entity_value (Server, Key#entity_k.name, Key#entity_k.type),
  Props2 =
    case proplists:get_value (PropName, Value#entity_v.properties) of
      undefined -> Props1;
      PropValue -> PropValue ++ Props1
    end,
  Keys = Gen (#gas_entry { k = Key, v = Value }),
  do_get_rec_properties (Keys ++ Tail, Server, PropName, Gen, Props2).
