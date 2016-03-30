%% @doc Token types.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__TOKEN_HRL__).
-define (__TOKEN_HRL__, ok).

% =============================================================================
% CONSTANTS
% =============================================================================

%
% general token types
%

-define (TT_SEPARATOR, separator).
-define (TT_DEFAULT,   default).
-define (TT_STRING,    string).
-define (TT_EOT,       eot).
-define (TT_BREAK,     break).

%
% user token types
%

-define (TT_COMMENT_BEGIN, comment_begin).
-define (TT_COMMENT_END,   comment_end).

-define (TT_SECTION,       section).
-define (TT_CONTENT_BEGIN, content_begin).
-define (TT_CONTENT_END,   content_end).
-define (TT_ATTRIBUTE,     attribute).
-define (TT_PROPERTY,      property).
-define (TT_CLASS,         class).
-define (TT_MATCH,         match).

-define (TT_ASSIGNMENT,    assignment).
-define (TT_GUARG,         guard).
-define (TT_WILDCARD,      wildcard).

-endif. % __TOKEN_HRL__