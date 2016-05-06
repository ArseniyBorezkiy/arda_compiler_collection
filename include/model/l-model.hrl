%% @doc Dynamically described lexical grammatical model.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__L_MODEL_HRL__).
-define (__L_MODEL_HRL__, ok).

%
% headers
%

-include ("gen_acc_storage.hrl").
-include ("am_entity.hrl").
-include ("am_lrule.hrl").
-include ("am_voc.hrl").

% =============================================================================
% DEFINITIONS
% =============================================================================

%
% entities' types
%

-define (ET_CLASS, class).
-define (ET_ATTRIBUTE, attribute).
-define (ET_ALPHABET, alphabet).
-define (ET_WILDCARD, wildcard).
-define (ET_VOCABULARY, vocabulary).
-define (ET_MATCH, match).
-define (ET_MUTATION, mutation).
-define (ET_REFLECTION, reflection).
-define (ET_STATE, state).
-define (ET_EOW, eow).

%
% end
%

-endif. % __L_MODEL_HRL__