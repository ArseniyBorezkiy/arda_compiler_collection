%% @doc Application general types.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__GENERAL_HRL__).
-define (__GENERAL_HRL__, ok).

% =============================================================================
% TYPES DEFINITION
% =============================================================================

-define (VERSION, "1.0").

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
-define (DL_DETAIL, 3).
-define (DL_SECTION, 4).
-define (DL_SUCCESS, 5).

-endif. % __GENERAL_HRL__