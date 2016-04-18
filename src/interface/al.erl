%% @doc Application user interface.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al).

% API
-export ([
          % external interface
          start/3,
          % internal callback
          run/2
         ]).

% =============================================================================
% API
% =============================================================================

start (Node, TargetIn, TargetOut) ->
  case rpc:call (Node, ?MODULE, run, [ TargetIn, TargetOut ]) of
    ok -> 0;
    error -> -1;
    { badrpc, _ } -> -1
  end.

run (TargetIn, TargetOut) ->
  dispatcher:compile (TargetIn, TargetOut).