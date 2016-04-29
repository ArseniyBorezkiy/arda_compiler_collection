%% @doc Application general types.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__GENERAL_HRL__).
-define (__GENERAL_HRL__, ok).

%
% headers
%

-include ("generic.hrl").
-include ("debug.hrl").

% =============================================================================
% DEFINITIONS
% =============================================================================

%
% versions:
%   - 'back compatibility version' must be increased when some features added
%     that makes compiler incompatible with old grammar reference specifications,
%     (e.g. deleting or modification of specification structures).
%   - 'forward compatibility version' must be changed when some features extends
%     existing functionality and keeps previous grammar reference specifications
%     acceptable up to 'back compatibility version'. Is is must be setted to zero
%     when 'back compatibility version' is increased.
%

-define (BC_VERSION, 1). % compatibility version
-define (FC_VERSION, 0). % features version

%
% exceptions
%

-define (e_error, error).

%
% end
%

-endif. % __GENERAL_HRL__