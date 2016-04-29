%% @doc Multilanguage strings.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__RESOURCES_HRL__).
-define (__RESOURCES_HRL__, ok).

% =============================================================================
% DEFINITIONS
% =============================================================================

%
% language
%

-define (languages, [ { "en", en }, { "ru", ru } ]).

%
% macroses
%

-define (text (Resource), (acc_resource:encode (Resource))).

%
% exceptions
%

-define (e_undefined_resource (RC), { { resource, undefined }, RC }).

% =============================================================================
% MULTILANGUAGE STRINGS ORDINALS
% =============================================================================

-define (str_info (M, O, A), { { M, O }, A }).

%
% acc dispatcher
%

-define (str_ad_fatal, ?str_info (ad, 1, [])).
-define (str_ad_compile_error (F, P), ?str_info (ad, 2, [ F, P ])).
-define (str_ad_runtime_error (F, P, E), ?str_info (ad, 3, [ F, P, E ])).
-define (str_ad_dispatched (F, P), ?str_info (ad, 4, [ F, P ])).
-define (str_ad_compiling (F), ?str_info (ad, 5, [ F ])).
-define (str_ad_compiled (F), ?str_info (ad, 6, [ F ])).
-define (str_ad_not_compiled (F, S), ?str_info (ad, 7, [ F, S ])).
-define (str_ad_loading (F), ?str_info (ad, 8, [ F ])).
-define (str_ad_loaded (F), ?str_info (ad, 9, [ F ])).
-define (str_ad_not_loaded (F, S), ?str_info (ad, 10, [ F, S ])).

%
% gen acc storage
%

-define (str_gas_module_exists (M), ?str_info (gas, 1, [ M ])).
-define (str_gas_module_not_exists (M), ?str_info (gas, 2, [ M ])).
-define (str_gas_command_not_exists (C), ?str_info (gas, 3, [ C ])).
-define (str_gas_key_exists (K), ?str_info (gas, 4, [ K ])).
-define (str_gas_key_not_exists (K), ?str_info (gas, 5, [ K ])).
-define (str_gas_many_object_exists (K), ?str_info (gas, 6, [ K ])).

%
% am ensure
%

-define (str_ame_avoid (K), ?str_info (ame, 1, [ K ])).
-define (str_ame_incompatible (K, V, VS), ?str_info (ame, 2, [ K, V, VS ])).

%
% am entity
%

-define (str_ament_eredefine (N, T), ?str_info (ament, 1, [ N, T ])).
-define (str_ament_eorphan (N, T), ?str_info (ament, 2, [ N, T ])).
-define (str_ament_pundefined (N, T, P), ?str_info (ament, 3, [ N, T, P ])).
-define (str_ament_pnlist (N, T, P), ?str_info (ament, 4, [ N, T, P ])).
-define (str_ament_uentity (P1, P2), ?str_info (ament, 5, [ P1, P2 ])).

%
% am lrule
%

-define (str_amlr_redefine (N), ?str_info (amlr, 1, [ N ])).

%
% am voc
%

-define (str_amvoc_sredefine (V, S), ?str_info (amvoc, 1, [ V, S ])).
-define (str_amvoc_vredefine (V), ?str_info (amvoc, 2, [ V ])).

%
% gen acc lexer
%

-define (str_gal_eot, ?str_info (gal, 1, [])).
-define (str_gal_error, ?str_info (gal, 2, [])).
-define (str_gal_location (S, N, L, C), ?str_info (gal, 3, [ S, N, L, C ])).
-define (str_gal_dir (D), ?str_info (gal, 4, [ D ])).
-define (str_gal_sambiguity (S), ?str_info (gal, 5, [ S ])).
-define (str_gal_notreadable, ?str_info (gal, 6, [])).
-define (str_gal_tredefine (T, T1, T2), ?str_info (gal, 7, [ T, T1, T2 ])).
-define (str_gal_uresetable (T, T1), ?str_info (gal, 8, [ T, T1 ])).
-define (str_gal_uresetable_ex (T, T1, T2), ?str_info (gal, 9, [ T, T1, T2 ])).
-define (str_gal_nofile (F), ?str_info (gal, 10, [ F ])).

%
% acc lexer
%

-define (str_al_expected (T, T1, T2), ?str_info (al, 1, [ T, T1, T2 ])).
-define (str_al_expected_any (T, TS, T2), ?str_info (al, 2, [ T, TS, T2 ])).
-define (str_al_finished (S), ?str_info (al, 3, [ S ])).
-define (str_al_msg (M, S), ?str_info (al, 4, [ M, S ])).
-define (str_al_uaccess (P), ?str_info (al, 5, [ P ])).
-define (str_al_registered (P, S, F), ?str_info (al, 6, [ P, S, F ])).
-define (str_al_reauth (P, F), ?str_info (al, 7, [ P, F ])).
-define (str_al_unregistered (P, S, F), ?str_info (al, 8, [ P, S, F ])).
-define (str_al_uunregistration (P), ?str_info (al, 9, [ P ])).
-define (str_al_notwritable (F, P, R), ?str_info (al, 10, [ F, P, R ])).

%
% al language
%

-define (str_llang_pstate (S, T, T0), ?str_info (llang, 1, [ S, T, T0 ])).
-define (str_llang_ewildcard (W), ?str_info (llang, 2, [ W ])).
-define (str_llang_ucend, ?str_info (llang, 3, [])).
-define (str_llang_ueotbcend, ?str_info (llang, 4, [])).
-define (str_llang_uewstate (S, T, T0), ?str_info (llang, 5, [ S, T, T0 ])).
-define (str_llang_eparent (T, T1, T2), ?str_info (llang, 6, [ T, T1, T2 ])).

%
% al rule
%

-define (str_lrule_umne (R), ?str_info (lrule, 1, [ R ])).
-define (str_lrule_uwildcard (R), ?str_info (lrule, 2, [ R ])).
-define (str_lrule_efmode (R), ?str_info (lrule, 3, [ R ])).
-define (str_lrule_ebmode (R), ?str_info (lrule, 4, [ R ])).
-define (str_lrule_umask (R), ?str_info (lrule, 5, [ R ])).
-define (str_lrule_amask (R), ?str_info (lrule, 6, [ R ])).

%
% al sentence
%

-define (str_lsentence_ueotbcend, ?str_info (lsentence, 1, [])).
-define (str_lsentence_ucend, ?str_info (lsentence, 2, [])).

%
% al word
%

-define (str_lword_vocabular (O, W, V, L), ?str_info (lword, 1, [ O, W, V, L ])).
-define (str_lword_nomatch (O, W, M, X, Y, T, L), ?str_info (lword, 2, [ O, W, M, X, Y, T, L ])).
-define (str_lword_match (O, W, S, M, X, Y, T, V, L), ?str_info (lword, 3, [ O, W, S, M, X, Y, T, V, L ])).
-define (str_lword_nsubrules (R), ?str_info (lword, 4, [ R ])).
-define (str_lword_state (O, R, W, G), ?str_info (lword, 5, [ O, R, W, G ])).
-define (str_lword_aclass (C), ?str_info (lword, 6, [ C ])).
-define (str_lword_bdump (W), ?str_info (lword, 7, [ W ])).
-define (str_lword_dump (O, M, V, WI, WO, G), ?str_info (lword, 8, [ O, M, V, WI, WO, G ])).
-define (str_lword_edump (W), ?str_info (lword, 9, [ W ])).
-define (str_lword_bwlist (W), ?str_info (lword, 10, [ W ])).
-define (str_lword_wlist1 (O, C, S, G), ?str_info (lword, 11, [ O, C, S, G ])).
-define (str_lword_wlist2 (M, V), ?str_info (lword, 12, [ M, V ])).
-define (str_lword_ewlist (W), ?str_info (lword, 13, [ W ])).

%
% end
%

-endif. % __RESOURCES_HRL__