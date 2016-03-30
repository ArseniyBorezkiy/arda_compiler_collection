%% @doc Generic dynamically described grammatical model.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__MODEL_HRL__).
-define (__MODEL_HRL__, ok).

% HEADERS
-include ("general.hrl").

% =============================================================================
% TYPES DEFINITION
% =============================================================================

%
% model storage
%

-record (entity, { name :: string (),
                   type :: atom () }).

-record (property, { name   :: string (),
                     value  :: string (),
                     entity :: string () }).

%
% rule storage
%

-type filter_result_t () :: { string (), string () } | false | error .
-type filter_t () :: fun ((string (), string ()) -> filter_result_t ()).

-record (match,  { name :: string () }).

-type match_instance_t () :: { Match   :: string (),
                               Ordinal :: unsigned_t () } .

-record (rule,   { instance :: match_instance_t (),
                   name     :: string () }).

-record (regexp, { instance   :: match_instance_t (),
                   expression :: string (),
                   filters    :: list (filter_t ()) }).

-record (guard, { instance :: match_instance_t (),
                  entity   :: string (),
                  property :: string () }).

% =============================================================================
% CONSTANTS
% =============================================================================

%
% entities
%

-define (ET_CLASS, class).
-define (ET_ATTRIBUTE, attribute).
-define (ET_ALPHABET, alphabet).

-endif. % __MODEL_HRL__