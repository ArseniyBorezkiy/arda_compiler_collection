%% @doc Generic types and common resources.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__GENERIC_HRL__).
-define (__GENERIC_HRL__, ok).

%
% headers
%

-include ("validate.hrl").
-include ("resources.hrl").

% =============================================================================
% GENERIC TYPES
% =============================================================================

%
% general
%

-type integer_t ()  :: integer ().
-type unsigned_t () :: non_neg_integer ().

-type dict_t (K, V) :: dict:dict (K, V).
-type tid_t ()      :: ets:tid ().

%
% io
%

-type format_t ()      :: string ().
-type format_args_t () :: list ().

-type io_device_t ()   :: file:io_device  ().
-type position_t ()    :: pos_integer ().

%
% end
%

-endif. % __GENERIC_HRL__