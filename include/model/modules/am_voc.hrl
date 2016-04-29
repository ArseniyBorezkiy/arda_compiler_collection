%% @doc Dynamically described model's vocabulary module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__AM_VOC_HRL__).
-define (__AM_VOC_HRL__, ok).

%
% headers
%

-include ("am_lrule.hrl").

% =============================================================================
% TYPES DEFINITION
% =============================================================================

%
% basic types
%

-record (stem_k, { voc  :: string (),
                   stem :: string () }).

-type stem_k_t () :: # stem_k { } .

-record (stem_v, { guards :: list (guard_v_t ()) }).

-type stem_v_t () :: # stem_v { } .

% =============================================================================
% END
% =============================================================================

-endif. % __AM_VOC_HRL__