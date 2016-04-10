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
                   type :: atom (),
                   tag  :: string () }).

-type entity_t () :: # entity { } .

-record (property, { name   :: string (),
                     value  :: string (),
                     entity :: string () }).

-type property_t () :: # property { } .

-record (member, { class  :: string (),
                   member :: string () }).

%
% rule storage
%

-type filter_result_t () :: { string (), string () } | false | error .
-type filter_t () :: fun ((string (), string ()) -> filter_result_t ()).

-record (match,  { name :: string () }).

-type match_instance_t () :: { Match    :: string (),
                               OrdinalX :: unsigned_t (),
                               OrdinalY :: unsigned_t () } .

-record (rule,   { instance :: match_instance_t (),
                   name     :: string () }).

-record (regexp, { instance   :: match_instance_t (),
                   expression :: string (),
                   filters    :: list (filter_t ()) }).

-record (guard, { instance :: match_instance_t (),
                  entity   :: string (),
                  property :: string () }).

%
% vocabular storage
%

-record (stem, { stem       :: string (),
                 vocabulary :: string () }).

-type characteristic_instance_t () :: { Stem     :: string (),
                                        Property :: string () } .

-record (characteristic, { instance   :: characteristic_instance_t (),
                           vocabulary :: string () }).

% =============================================================================
% CONSTANTS
% =============================================================================

%
% entities
%

-define (ET_CLASS, class).
-define (ET_ATTRIBUTE, attribute).
-define (ET_ALPHABET, alphabet).
-define (ET_VOCABULARY, vocabulary).
-define (ET_MATCH, match).

-endif. % __MODEL_HRL__