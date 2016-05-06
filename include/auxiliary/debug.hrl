%% @doc Debug macroses.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__DEBUG_HRL__).
-define (__DEBUG_HRL__, ok).

% =============================================================================
% DEFINITIONS
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

%
% macroses
%

-define (d_error (Resource), (acc_debug:log (?MODULE, ?DL_ERROR, Resource))).
-define (d_warning (Resource), (acc_debug:log (?MODULE, ?DL_WARNING, Resource))).
-define (d_result (Resource), (acc_debug:log (?MODULE, ?DL_RESULT, Resource))).
-define (d_section (Resource), (acc_debug:log (?MODULE, ?DL_SECTION, Resource))).
-define (d_detail (Resource), (acc_debug:log (?MODULE, ?DL_DETAIL, Resource))).
-define (d_success (Resource), (acc_debug:log (?MODULE, ?DL_SUCCESS, Resource))).

%
% end
%

-endif. % __DEBUG_HRL__