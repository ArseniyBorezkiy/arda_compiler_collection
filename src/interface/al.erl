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
  case rpc:call (Node, ?MODULE, run, [ Target ]) of
    ok -> 0;
    error -> -1;
    { badrpc, _ } -> -1
  end.

run (Target) ->
  dispatcher:compile (Target).