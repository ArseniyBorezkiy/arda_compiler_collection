%% @doc Application user interface.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al).

% API
-export ([
          % external interface
          start/2,
          % internal callback
          run/1
         ]).

% =============================================================================
% API
% =============================================================================

start (Node, Target) ->
  case rpc:call (Node, ?MODULE, fun run/1, [ Target ]) of
    { badrpc, _ } -> -1;
    ok -> 0
  end.

run (Target) ->
  dispatcher:compile (Target).