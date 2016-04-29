%% @doc Dynamically described lexical model.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_model).

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
          add_property_value/4,
          create_child_entity/5,
          select_entities/2,
          select_child_entities/4,
          find_entity/3,
          delete_entities/3,
          get_entity_value/2,
          get_parent_entity/2,
          get_recursive_properties/3,
          % am lrule module
          create_composite/5,
          create_vocabular/6,
          create_expression/5,
          create_guard/7,
          select_subrules/1,
          select_guards/2,
          % am voc module
          create_vocabulary/1,
          select_vocabularies/0,
          create_stem/3,
          find_stem/2,
          select_stems/3
        ]).

%
% headers
%

-include ("l-model.hrl").

%
% reqired modules
%

-define (gas_modules, [ am_ensure, am_entity, am_lrule, am_voc ]).

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

add_property_value (Name, Type, PropName, PropValue) ->
  am_entity:add_property_value (?MODULE, Name, Type, PropName, PropValue).

create_child_entity (Bases, Type1, Name, Type2, Properties) ->
  am_entity:create_child_entity (?MODULE, Bases, Type1, Name, Type2, Properties).

select_entities (Name, Type) ->
  am_entity:select_entities (?MODULE, Name, Type).

select_child_entities (Base, Type1, Name, Type2) ->
  am_entity:select_child_entities (?MODULE, Base, Type1, Name, Type2).

find_entity (Type, PropName, SubPropName) ->
  am_entity:find_entity (?MODULE, Type, PropName, SubPropName).

delete_entities (Type, PropName, PropValue) ->
  am_entity:delete_entities (?MODULE, Type, PropName, PropValue).

get_entity_value (Name, Type) ->
  am_entity:get_entity_value (?MODULE, Name, Type).

get_parent_entity (Name, Type) ->
  am_entity:get_parent_entity (?MODULE, Name, Type).

get_recursive_properties (Name, Type, PropName) ->
  am_entity:get_recursive_properties (?MODULE, Name, Type, PropName).

%
% am lrule module
%

create_composite (Node, Name, X, Y, D) ->
  am_lrule:create_composite (?MODULE, Node, Name, X, Y, D).

create_vocabular (Node, Name, Voc, X, Y, D) ->
  am_lrule:create_vocabular (?MODULE, Node, Name, Voc, X, Y, D).

create_expression (Node, Expr, X, Y, D) ->
  am_lrule:create_expression (?MODULE, Node, Expr, X, Y, D).

create_guard (Node, Name, Base, Type, X, Y, S) ->
  am_lrule:create_guard (?MODULE, Node, Name, Base, Type, X, Y, S).

select_subrules (Node) ->
  am_lrule:select_subrules (?MODULE, Node).

select_guards (Node, Y) ->
  am_lrule:select_guards (?MODULE, Node, Y).

%
% am voc module
%

create_vocabulary (Voc) ->
  am_voc:create_vocabulary (?MODULE, Voc).

select_vocabularies () ->
  am_voc:select_vocabularies (?MODULE).

create_stem (Voc, Stem, Guards) ->
  am_voc:create_stem (?MODULE, Voc, Stem, Guards).

find_stem (Voc, Stem) ->
  am_voc:find_stem (?MODULE, Voc, Stem).

select_stems (Voc, Word, Direction) ->
  am_voc:select_stems (?MODULE, Voc, Word, Direction).
