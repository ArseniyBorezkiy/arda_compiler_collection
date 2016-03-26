%% @doc Vocabulary parser.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (voc_parser).

% API
-export ([
          load/1
         ]).

% =============================================================================
% API
% =============================================================================

load (Name) ->
  % open file
  File   = al_db:get_rule (Name),
  Handle =
    case file:open (File, [ read ]) of
      { ok, IoDevice } -> IoDevice;
      Error -> throw ({ path, File, Error })
    end,
  % read vocabulary
  % close
  file:close (Handle),
  ok.