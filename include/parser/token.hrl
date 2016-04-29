%% @doc Generic token types.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__TOKEN_HRL__).
-define (__TOKEN_HRL__, ok).

% =============================================================================
% DEFINITIONS
% =============================================================================

-define (TT_SEPARATOR, separator).
-define (TT_DEFAULT,   default).
-define (TT_STRING,    string).
-define (TT_EOT,       eot).
-define (TT_BREAK,     break).

-define (TT_COMMENT_BEGIN, comment_begin).
-define (TT_COMMENT_END,   comment_end).

%
% end
%

-endif. % __TOKEN_HRL__