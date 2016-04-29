%% @doc Dynamically described model's entity module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__AM_ENTITY_HRL__).
-define (__AM_ENTITY_HRL__, ok).

% =============================================================================
% TYPES DEFINITION
% =============================================================================

-record (entity_k, { name :: string (),
                     type :: atom () }).

-type entity_k_t () :: # entity_k { } .

-record (entity_v, { properties :: list (term ()) }).

-type entity_v_t () :: # entity_v { } .

%
% end
%

-endif. % __AM_ENTITY_HRL__