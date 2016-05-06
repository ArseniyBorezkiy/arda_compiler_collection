%% @doc Lexical output format description.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__L_OUTPUT_HRL__).
-define (__L_OUTPUT_HRL__, ok).

%
% headers
%

-include ("general.hrl").

% =============================================================================
% TYPES DEFINITION
% =============================================================================

-record (word_k, { oid        :: list (unsigned_t ()) }).

-record (word_v, { guards     :: list (string ()),
                   auxiliary  :: list ({ aux, string (), string () }),
                   vocabulars :: list ({ voc, string (), string () }),
                   class      :: string () }).

-type word_k_t () :: # word_k { } .
-type word_v_t () :: # word_v { } .

%
% end
%

-endif. % __L_OUTPUT_HRL__
