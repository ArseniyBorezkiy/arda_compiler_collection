%% @doc Dynamically described model's ensurance module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (am_ensure).
-behaviour (gen_acc_storage).

%
% api
%

-export ([
          ensure/2,
          ensure/3,
          ensure/4
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

%
% basic types
%

-record (s, { dict :: dict_t (term (), term ()) }).

% =============================================================================
% API
% =============================================================================

-spec ensure
(
  Server :: atom (),
  Name   :: term ()
) -> term ().

ensure (Server, Name) ->
  gen_acc_storage:call (Server, ensure, { Name }).

-spec ensure
(
  Server :: atom (),
  Name   :: term (),
  Value  :: term ()
) -> term ().

ensure (Server, Name, Value) ->
  gen_acc_storage:cast (Server, ensure, { Name, Value }).

-spec ensure
(
  Server    :: atom (),
  Name      :: term (),
  Value     :: term (),
  Condition :: fun ((Value :: term ()) -> boolean ())
) -> term ().

ensure (Server, Name, Value, Condition) ->
  gen_acc_storage:cast (Server, ensure, { Name, Value, Condition }).

% =============================================================================
% GEN ACC STORAGE CALLBACKS
% =============================================================================

%
% prologue and epilogue
%

init () ->
  State = #s { dict = dict:new () },
  Handlers = [ { ensure, fun handle_ensure/2 } ],
  { ok, State, Handlers }.

terminate (_State) ->
  ok.

%
% dispatchers - ensure
%

handle_ensure ({ Name }, State) ->
  Dict  = State#s.dict,
  Value =
    case dict:is_key (Name, Dict) of
      true  -> dict:fetch (Name, Dict);
      false ->
        Resource = ?str_ame_avoid (Name),
        throw (?e_module_runtime (Resource))
    end,
  { reply, Value, State };

handle_ensure ({ Name, Value }, State) ->
  Condition = fun (Value0) -> Value0 =:= Value end,
  handle_ensure ({ Name, Value, Condition }, State);

handle_ensure ({ Name, Value, Condition }, State) ->
  Dict1 = State#s.dict,
  Dict2 =
    case dict:is_key (Name, Dict1) of
      false -> dict:store (Name, [ Value ], Dict1);
      true  ->        
        Values = dict:fetch (Name, Dict1),
        case lists:all (Condition, [ Value | Values ]) of
          true  -> dict:store (Name, [ Value | Values ], Dict1);
          false ->
            Resource = ?str_ame_incompatible (Name, Value, Values),
            throw (?e_module_runtime (Resource))
        end
    end,
  { noreply, State#s { dict = Dict2 } }.
