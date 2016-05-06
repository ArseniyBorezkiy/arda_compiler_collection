%% @doc Dynamically described model's lexical rules module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__AM_LRULE_HRL__).
-define (__AM_LRULE_HRL__, ok).

%
% headers
%

-include ("general.hrl").

% =============================================================================
% TYPES DEFINITION
% =============================================================================

%
% auxiliary types
%

-type filter_in_t ()  :: { string (), string (), unsigned_t () } .
-type filter_out_t () :: filter_in_t () | false | error .
-type filter_t ()     :: fun ((filter_in_t ()) -> filter_out_t ()).

-type direction_t ()  :: forward | backward | inward .
-type voc_type_t ()   :: exact | left | right .
-type match_type_t () :: word | value .
-type guard_type_t () :: class | property .
-type sign_t ()       :: positive | negative .

%
% basic types
%

-record (crule_v, { name       :: string (),
                    capacity   :: boolean (),
                    equivalent :: string () }).
-record (erule_v, { regexp     :: string (),
                    filters    :: list (filter_t ()) }).
-record (vrule_v, { name       :: string (),
                    capacity   :: boolean (),
                    voc        :: string (),
                    voc_type   :: voc_type_t (),
                    match_type :: match_type_t () }).
-record (srule_v, { key        :: term (),
                    value      :: fun ((string ()) -> term ()),
                    capacity   :: boolean () }).
-record (arule_v, { rule_src   :: string (),
                    rule_dst   :: string () }).

-type crule_v_t () :: # crule_v { } .
-type erule_v_t () :: # erule_v { } .
-type vrule_v_t () :: # vrule_v { } .
-type srule_v_t () :: # srule_v { } .
-type arule_v_t () :: # arule_v { } .

-type rule_v_t ()  :: crule_v_t () | erule_v_t () | vrule_v_t () | srule_v_t () | arule_v_t () .

-record (match_k, { node    :: string (),
                    x       :: position_t (),
                    y       :: position_t () }).

-record (match_v, { dir     :: direction_t (),
                    rule    :: rule_v_t () }).

-record (guard_v, { sign    :: sign_t (),
                    type    :: guard_type_t (),
                    base    :: string (),
                    name    :: string () }).

-type match_k_t () :: # match_k { } .
-type match_v_t () :: # match_v { } .
-type guard_v_t () :: # guard_v { } .

%
% end
%

-endif. % __AM_LRULE_HRL__