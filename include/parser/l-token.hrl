%% @doc Lexical token types.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__L_TOKEN_HRL__).
-define (__L_TOKEN_HRL__, ok).

%
% headers
%

-include ("token.hrl").

% =============================================================================
% DEFINITIONS
% =============================================================================

-define (TT_SECTION,       section).
-define (TT_CONTENT_BEGIN, content_begin).
-define (TT_CONTENT_END,   content_end).
-define (TT_CONTENT_STOP,  content_stop).
-define (TT_ATTRIBUTE,     attribute).
-define (TT_PROPERTY,      property).
-define (TT_CLASS,         class).
-define (TT_MATCH,         match).
-define (TT_DIRECTION,     direction).
-define (TT_VOCABULARY,    vocabulary).
-define (TT_ALPHABET,      alphabet).
-define (TT_MUTATION,      mutation).
-define (TT_REFLECTION,    reflection).

-define (TT_DMATCH,        defined_match).
-define (TT_DVOCABULARY,   defined_vocabulary).

-define (TT_BASE,          base).
-define (TT_SPECIFIER,     specifier).
-define (TT_VOCABULAR,     vocabular).

-define (TT_ASSIGNMENT,    assignment).
-define (TT_ILASSIGNMENT,  incremental_left_assignment).
-define (TT_IRASSIGNMENT,  incremental_right_assignment).
-define (TT_GUARD,         guard).
-define (TT_GROUP,         group).

-define (TT_WILDCARD,      wildcard).
-define (TT_PHONEME,       phoneme).
-define (TT_ACTION,        action).
-define (TT_STATE,         state).

%
% end
%

-endif. % __L_TOKEN_HRL__