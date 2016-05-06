%% @doc Multilanguage strings.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (acc_resource).

%
% api
%

-export ([
          encode/1
        ]).

%
% internal callbacks
%

-export ([
          encode_ad_en/1,
          encode_gas_en/1,
          encode_ame_en/1,
          encode_gal_en/1,
          encode_al_en/1,
          encode_llang_en/1,
          encode_lrule_en/1,
          encode_lsentence_en/1,
          encode_lword_en/1,
          encode_ament_en/1,
          encode_amlr_en/1,
          encode_amvoc_en/1
        ]).

%
% headers
%

-include ("general.hrl").

% =============================================================================
% API
% =============================================================================

encode (Resource) ->
  ?str_info (Module, _, _) = Resource,
  Language = acc_debug:get_language (),
  Name = "encode_" ++ atom_to_list (Module) ++ "_" ++ atom_to_list (Language),
  Fun  = list_to_existing_atom (Name),
  erlang:apply (?MODULE, Fun, [ Resource ]).

% =============================================================================
% ENGLISH STRINGS
% =============================================================================

%
% acc dispatcher
%

encode_ad_en (?str_ad_fatal) ->
  acc_debug:sprintf ("fatal error", []);

encode_ad_en (?str_ad_compile_error (File, Pid)) ->
  acc_debug:sprintf ("~p error in '~p'", [ File, Pid ]);

encode_ad_en (?str_ad_runtime_error (File, Pid, Error)) ->
  acc_debug:sprintf ("~p error in '~p': ~p", [ File, Pid, Error ]);

encode_ad_en (?str_ad_dispatched (File, Pid)) ->
  acc_debug:sprintf ("~p dispatched in '~p'", [ File, Pid ]);

encode_ad_en (?str_ad_compiling (File)) ->
  acc_debug:sprintf ("compiling ~p", [ File ]);

encode_ad_en (?str_ad_compiled (File)) ->
  acc_debug:sprintf ("compilation finished for ~p", [ File ]);

encode_ad_en (?str_ad_not_compiled (File, Status)) ->
  acc_debug:sprintf ("compilation failed for ~p~n~s", [ File, Status ]);

encode_ad_en (?str_ad_loading (File)) ->
  acc_debug:sprintf ("loading grammar reference: ~p", [ File ]);

encode_ad_en (?str_ad_loaded (File)) ->
  acc_debug:sprintf ("grammar reference loaded: ~p", [ File ]);

encode_ad_en (?str_ad_not_loaded (File, Status)) ->
  acc_debug:sprintf ("error in grammar reference: ~p~n~s", [ File, Status ]);

encode_ad_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% gen acc storage
%

encode_gas_en (?str_gas_module_exists (Module)) ->
  acc_debug:sprintf ("module '~p' already exists", [ Module ]);

encode_gas_en (?str_gas_module_not_exists (Module)) ->
  acc_debug:sprintf ("module '~p' not exists", [ Module ]);

encode_gas_en (?str_gas_command_not_exists (Command)) ->
  acc_debug:sprintf ("command '~p' not exists", [ Command ]);

encode_gas_en (?str_gas_key_exists (Key)) ->
  acc_debug:sprintf ("key '~p' already exists", [ Key ]);

encode_gas_en (?str_gas_key_not_exists (Key)) ->
  acc_debug:sprintf ("key '~p' not exists", [ Key ]);

encode_gas_en (?str_gas_many_object_exists (Key)) ->
  acc_debug:sprintf ("key '~p' matches multiple values", [ Key ]);

encode_gas_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% am ensure
%

encode_ame_en (?str_ame_avoid (Key)) ->
  acc_debug:sprintf ("ensurance of '~p' failed cause of avoiding", [ Key ]);

encode_ame_en (?str_ame_incompatible (Key, Value, Values)) ->
  acc_debug:sprintf ("ensurance of '~p' failed cause of '~p' incompatible with '~p'", [ Key, Value, Values ]);

encode_ame_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% am entity
%

encode_ament_en (?str_ament_eredefine (Name, Type)) ->
  acc_debug:sprintf ("entity redefinition: ~p of type '~p'", [ Name, Type ]);

encode_ament_en (?str_ament_eorphan (Name, Type)) ->
  acc_debug:sprintf ("entity orphan: ~p of type '~p'", [ Name, Type ]);

encode_ament_en (?str_ament_pundefined (Name, Type, Prop)) ->
  acc_debug:sprintf ("entity ~p of type '~p' has not property '~p'", [ Name, Type, Prop ]);

encode_ament_en (?str_ament_pnlist (Name, Type, Prop)) ->
  acc_debug:sprintf ("entity ~p of type '~p' has non-enumerable property '~p'", [ Name, Type, Prop ]);

encode_ament_en (?str_ament_uentity (PropName1, PropName2)) ->
  acc_debug:sprintf ("undefined entity with property '~p' and subproperty ~p", [ PropName1, PropName2 ]);

encode_ament_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% am lrule
%

encode_amlr_en (?str_amlr_redefine (Node)) ->
  acc_debug:sprintf ("rule redefinition in node: ~p", [ Node ]);

encode_amlr_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% am voc
%

encode_amvoc_en (?str_amvoc_sredefine (Voc, Stem)) ->
  acc_debug:sprintf ("redefinition in vocabulary ~p of stem ~p", [ Voc, Stem ]);

encode_amvoc_en (?str_amvoc_vredefine (Voc)) ->
  acc_debug:sprintf ("redefinition of the vocabulary ~p", [ Voc ]);

encode_amvoc_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% gen acc lexer
%

encode_gal_en (?str_gal_eot) ->
  acc_debug:sprintf ("end of text", []);

encode_gal_en (?str_gal_error) ->
  acc_debug:sprintf ("error ", []);

encode_gal_en (?str_gal_location (Status, Name, Line, Column)) ->
  acc_debug:sprintf ("~sin ~s (line: ~p, column: ~p)~n", [ Status, Name, Line, Column ]);

encode_gal_en (?str_gal_dir (Dir)) ->
  acc_debug:sprintf ("dir: ~s", [ Dir ]);

encode_gal_en (?str_gal_sambiguity (Splitters)) ->
  acc_debug:sprintf ("splitters ambiguity ~p", [ Splitters ]);

encode_gal_en (?str_gal_notreadable) ->
  acc_debug:sprintf ("can not read from stream", []);

encode_gal_en (?str_gal_tredefine (Token, Type1, Type2)) ->
  acc_debug:sprintf ("token redefinition ~p of type '~p' to type '~p'", [ Token, Type1, Type2 ]);

encode_gal_en (?str_gal_uresetable (Token, Type)) ->
  acc_debug:sprintf ("token ~p of type '~p' not found to be reseted", [ Token, Type ]);

encode_gal_en (?str_gal_uresetable_ex (Token, Type1, Type2)) ->
  acc_debug:sprintf ("token ~p of type '~p' could not to be reset cause has type '~p'", [ Token, Type1, Type2 ]);

encode_gal_en (?str_gal_nofile (File)) ->
  acc_debug:sprintf ("can not open file: ~p", [ File ]);

encode_gal_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% acc lexer
%

encode_al_en (?str_al_expected (Token, Type1, Type2)) ->
  acc_debug:sprintf ("expected token ~p of type '~p' instead of '~p'", [ Token, Type1, Type2 ]);

encode_al_en (?str_al_expected_any (Token, Types, Type2)) ->
  acc_debug:sprintf ("expected token ~p of any type from '~p' instead of '~p'", [ Token, Types, Type2 ]);

encode_al_en (?str_al_finished (Server)) ->
  acc_debug:sprintf ("lexical alasyzer sucessfully finished in '~p'", [ Server ]);

encode_al_en (?str_al_msg (Message, Server)) ->
  acc_debug:sprintf ("~s in '~p'", [ Message, Server ]);

encode_al_en (?str_al_uaccess (Pid)) ->
  acc_debug:sprintf ("unauthorized access of '~p'", [ Pid ]);

encode_al_en (?str_al_registered (Pid, Server, File)) ->
  acc_debug:sprintf ("registered '~p' as '~p' for ~p", [ Pid, Server, File ]);
  
encode_al_en (?str_al_reauth (Pid, File)) ->
  acc_debug:sprintf ("try to reauthorization of '~p' for ~p", [ Pid, File ]);

encode_al_en (?str_al_unregistered (Pid, Server, File)) ->
  acc_debug:sprintf ("unregistered '~p' that '~p' for ~p", [ Pid, Server, File ]);

encode_al_en (?str_al_uunregistration (Pid)) ->
  acc_debug:sprintf ("unauthorizated unregistration of '~p'", [ Pid ]);

encode_al_en (?str_al_notwritable (File, Pid, Reason)) ->
  acc_debug:sprintf ("can not write to file ~p from '~p' (reason: ~p)", [ File, Pid, Reason ]);

encode_al_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% al language
%

encode_llang_en (?str_llang_pstate (State, Token, Type)) ->
  acc_debug:sprintf ("parsing state '~p' before token ~p of type '~p'", [ State, Token, Type ]);

encode_llang_en (?str_llang_ewildcard (Wildcard)) ->
  acc_debug:sprintf ("expected alphabetical wildcard instead of ~p", [ Wildcard ]);

encode_llang_en (?str_llang_ucend) ->
  acc_debug:sprintf ("unexpected end of the comment", []);

encode_llang_en (?str_llang_ueotbcend) ->
  acc_debug:sprintf ("unexpected end of the text while comment not finished", []);

encode_llang_en (?str_llang_uewstate (State, Token, Type)) ->
  acc_debug:sprintf ("unexpected ~p of type '~p' when '~p'", [ Token, Type, State ]);

encode_llang_en (?str_llang_eparent (Token, Type, Types)) ->
  acc_debug:sprintf ("expected parent ~p of type '~p' instead of any from '~p'", [ Token, Type, Types ]);

encode_llang_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% al rule
%

encode_lrule_en (?str_lrule_umne (Rule)) ->
  acc_debug:sprintf ("mutation and reflection negotiations unsupported in subrule ~p", [ Rule ]);

encode_lrule_en (?str_lrule_uwildcard (Rule)) ->
  acc_debug:sprintf ("unknown wildcard in rule ~p", [ Rule ]);

encode_lrule_en (?str_lrule_efmode (Rule)) ->
  acc_debug:sprintf ("expected mode for forward subrule ~p", [ Rule ]);

encode_lrule_en (?str_lrule_ebmode (Rule)) ->
  acc_debug:sprintf ("expected mode for backward subrule ~p", [ Rule ]);

encode_lrule_en (?str_lrule_umask (Rule)) ->
  acc_debug:sprintf ("unknown mask ~p", [ Rule ]);

encode_lrule_en (?str_lrule_amask (Rule)) ->
  acc_debug:sprintf ("ambiguity mask for ~p", [ Rule ]);

encode_lrule_en (Resource) ->
  throw (?e_undefined_resource (Resource)).

%
% al sentence
%

encode_lsentence_en (?str_lsentence_ueotbcend) ->
  acc_debug:sprintf ("expected end of the comment instead of eot", []);

encode_lsentence_en (?str_lsentence_ucend) ->
  acc_debug:sprintf ("unexpected end of the comment", []);

encode_lsentence_en (Resource) ->
  acc_debug:sprintf (?e_undefined_resource (Resource)).

%
% al word
%

encode_lword_en (?str_lword_vocabular (Oid, Word, Voc, Length)) ->
  acc_debug:sprintf ("~s : vocabular '~s' ('~s') | ~p", [ Oid, Word, Voc, Length ]);

encode_lword_en (?str_lword_nomatch (Oid, Word, Match, X, Y, Text, Length)) ->
  acc_debug:sprintf ("~s : no match '~s' for ~s (~p,~p): ~s | ~p", [ Oid, Word, Match, X, Y, Text, Length ]);

encode_lword_en (?str_lword_match (Oid, Word, Subword, Match, X, Y, Text, Value, Length)) ->
  acc_debug:sprintf ("~s : match '~s' -> '~s' for ~s (~p,~p): ~s = ~s | ~p", [ Oid, Word, Subword, Match, X, Y, Text, Value, Length ]);

encode_lword_en (?str_lword_nsubrules (Rule)) ->
  acc_debug:sprintf ("the rule '~s' have not subrules", [ Rule ]);

encode_lword_en (?str_lword_state (Oid, Rule, Word, Guards)) ->
  acc_debug:sprintf ("~s : rule: '~s', word: '~s' | ~s", [ Oid, Rule, Word, Guards ]);

encode_lword_en (?str_lword_uclass) ->
  acc_debug:sprintf ("class not specified", []);

encode_lword_en (?str_lword_aclass (Classes)) ->
  acc_debug:sprintf ("class ambiguity: ~p", [ Classes ]);

encode_lword_en (?str_lword_bdump (Word)) ->
  acc_debug:sprintf ("-- ~s: dump begin", [ Word ]);

encode_lword_en (?str_lword_iedump (Oid, Node, Expr, Value, WordIn, WordOut, Guards)) ->
  acc_debug:sprintf ("~s : (~s) ~s = ~s; ~s -> ~s | ~s", [ Oid, Node, Expr, Value, WordIn, WordOut, Guards ]);

encode_lword_en (?str_lword_icdump (Oid, Node, Guards)) ->
  acc_debug:sprintf ("~s : ~s | ~s", [ Oid, Node, Guards ]);

encode_lword_en (?str_lword_ivdump (Oid, Node, Value, Guards)) ->
  acc_debug:sprintf ("~s : ~s = ~s | ~s", [ Oid, Node, Value, Guards ]);

encode_lword_en (?str_lword_iwdump (Oid, Node, Value, WordIn, WordOut, Guards)) ->
  acc_debug:sprintf ("~s : ~s = ~s; ~s -> ~s | ~s", [ Oid, Node, Value, WordIn, WordOut, Guards ]);

encode_lword_en (?str_lword_edump (Word)) ->
  acc_debug:sprintf ("-- ~s: dump end", [ Word ]);

encode_lword_en (?str_lword_bwlist (Word)) ->
  acc_debug:sprintf ("-- ~s: word list begin", [ Word ]);

encode_lword_en (?str_lword_wlist1 (Oid, Class, Guards)) ->
  acc_debug:sprintf ("~s : ~s | ~s", [ Oid, Class, Guards ]);

encode_lword_en (?str_lword_wlist2 (Match, Value)) ->
  acc_debug:sprintf ("  ~s = ~s", [ Match, Value ]);

encode_lword_en (?str_lword_ewlist (Word)) ->
  acc_debug:sprintf ("-- ~s: word list end", [ Word ]);

encode_lword_en (Resource) ->
  throw (?e_undefined_resource (Resource)).
