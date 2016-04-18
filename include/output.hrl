%% @doc Output format description.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__OUTPUT_HRL__).
-define (__OUTPUT_HRL__, ok).

% HEADERS
-include ("general.hrl").

% =============================================================================
% TYPES DEFINITION
% =============================================================================

-record (word, { oid    :: list (unsigned_t ()),
                 guards :: list (string ()),
                 route  :: list ({ string (), string () }),
                 stem   :: string () }).

-type word_t () :: # word { } .

% =============================================================================
% CONSTANTS
% =============================================================================

-endif. % __OUTPUT_HRL__
