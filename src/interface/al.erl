%% @doc Application user interface.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al).

% API
-export ([
          % external interface
          start/5,
          % internal callback
          run/4
         ]).

% =============================================================================
% API
% =============================================================================

start (Server, Target, Rule, SrcPrefix, DstPrefix) ->
  case rpc:call (Server, al, run, [ Target, Rule, SrcPrefix, DstPrefix ]) of
    { badrpc, _ } -> -1;
    ok -> 0
  end.

run (Target, Rule, SrcPrefix, DstPrefix) ->
  Dir = file:get_cwd (),
  debug:log (0, "aaaaaaa").