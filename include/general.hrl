%% @doc Application general types.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

% =============================================================================
% GENERAL TYPES
% =============================================================================

-type io_device_t () :: file:io_device  ().
-type unsigned_t  () :: non_neg_integer ().
-type position_t ()  :: pos_integer ().

% =============================================================================
% DEBUG LEVES
% =============================================================================

-define (DL_WARNING, 0).
-define (DL_SUCCESS, 10).