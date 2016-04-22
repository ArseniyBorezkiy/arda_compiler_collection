%% @doc Application general types.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__GENERAL_HRL__).
-define (__GENERAL_HRL__, ok).

% =============================================================================
% TYPES DEFINITION
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
% general
%

-type unsigned_t  () :: non_neg_integer ().

%
% io
%

-type io_device_t () :: file:io_device  ().
-type position_t ()  :: pos_integer ().

% =============================================================================
% CONSTANTS
% =============================================================================

%
% debug levels
%

-define (DL_ERROR, 0).
-define (DL_WARNING, 1).
-define (DL_RESULT, 2).
-define (DL_SECTION, 3).
-define (DL_DETAIL, 4).
-define (DL_SUCCESS, 5).

-endif. % __GENERAL_HRL__