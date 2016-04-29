%% @doc Dynamically described syntax model.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (as_model).

%
% api
%

-export ([
          % management
          start_link/0,
          % am ensure module
          ensure/1,
          ensure/2,
          ensure/3,
          % am entity module
          create_entity/3,
          create_child_entity/5,
          select_entities/2,
          select_child_entities/4,
          get_entity_value/2,
          get_parent_entity/2,
          get_recursive_properties/4
        ]).

%
% headers
%

-include ("general.hrl").
-include ("s-model.hrl").

%
% reqired modules
%

-define (gas_modules, [ am_ensure, am_entity ]).

% =============================================================================
% API
% =============================================================================

%
% management
%

start_link () ->
  Fatalizer = fun (RC) -> ?d_error (RC) end,
  case gen_acc_storage:start_link (?MODULE, Fatalizer) of
    { ok, Pid } ->
      PlugIn = fun (M) -> gen_acc_storage:add_module (?MODULE, M) end,
      lists:foreach (PlugIn, ?gas_modules),
      { ok, Pid };
    Error -> Error
  end.

%
% am ensure module
%

ensure (Name) ->
  am_ensure:ensure (?MODULE, Name).

ensure (Name, Value) ->
  am_ensure:ensure (?MODULE, Name, Value).

ensure (Name, Value, Condition) ->
  am_ensure:ensure (?MODULE, Name, Value, Condition).

%
% am entity module
%

create_entity (Name, Type, Properties) ->
  am_entity:create_entity (?MODULE, Name, Type, Properties).

create_child_entity (Base, Type1, Name, Type2, Properties) ->
  am_entity:create_child_entity (?MODULE, Base, Type1, Name, Type2, Properties).

select_entities (Name, Type) ->
  am_entity:select_entities (?MODULE, Name, Type).

select_child_entities (Base, Type1, Name, Type2) ->
  am_entity:select_child_entities (?MODULE, Base, Type1, Name, Type2).

get_entity_value (Name, Type) ->
  am_entity:get_entity_value (?MODULE, Name, Type).

get_parent_entity (Name, Type) ->
  am_entity:get_parent_entity (?MODULE, Name, Type).

get_recursive_properties (Name, Type, PropName, Genealogist) ->
  am_entity:get_recursive_properties (?MODULE, Name, Type, PropName, Genealogist).
