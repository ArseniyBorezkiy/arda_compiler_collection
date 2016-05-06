%% @doc Word matcher.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_word).

%
% api
%

-export ([
          parse/1,
          format_oid/1
        ]).

%
% headers
%

-include ("general.hrl").
-include ("l-model.hrl").
-include ("l-output.hrl").

%
% basic types
%

-record (variant_k, { oid :: list (unsigned_t ()) }).

-record (evariant_v, { node     :: string (),
                       expr     :: string (),
                       word_in  :: string (),
                       word_out :: string (),
                       value    :: string (),
                       guards   :: list (guard_v_t ()) }).

-record (cvariant_v, { node     :: string (),
                       is_cap   :: boolean (),
                       value    :: string (),
                       equ      :: string (),
                       guards   :: list (guard_v_t ()) }).

-record (vvvariant_v, { node     :: string (),
                        value    :: string (),
                        voc      :: string (),
                        voc_type :: voc_type_t (),
                        is_cap   :: boolean (),
                        guards   :: list (guard_v_t ()) }).

-record (vwvariant_v, { node     :: string (),
                        word_in  :: string (),
                        word_out :: string (),
                        voc      :: string (),
                        value    :: string (),
                        is_cap   :: boolean (),
                        guards   :: list (guard_v_t ()) }).

% =============================================================================
% API
% =============================================================================

parse (Word) ->
  Table = gen_acc_storage:create_table (?MODULE, set),
  erlang:put (table, Table),
  try
    [ Node ]  = al_model:ensure (target),
    Main      = construct_rule (Node, Node),
    horizontal ([ Main ], [], Word, [], [], []),
    dump_detail (Word, Table),
    dump_words (Word, Table)
  after
    gen_acc_storage:delete_table (Table)
  end.

% =============================================================================
% RULE MATCHING
% =============================================================================

horizontal ([], Guards, _Word, Oid, _Cur, _Dst) ->
  % matched succesfully
  Table = erlang:get (table),
  Route = get_route (Oid, Table),
  Class = which_class (Guards),  
  Fun =
    fun
      ({ voc, _, _, _ }) -> true;
      ({ aux, _, _ }) -> false
    end,
  { Vocabulars, Auxiliary } = lists:partition (Fun, Route),
  Key   = #word_k { oid        = Oid },
  Value = #word_v { guards     = sets:to_list (sets:from_list (Guards)),
                    auxiliary  = Auxiliary,
                    vocabulars = Vocabulars,
                    class      = Class },
  gen_acc_storage:insert (Table, Key, Value),
  ok;
  
horizontal ([ Entry | Tail ], Guards, Word1, Oid1, Cur1, Dst)
  when is_record (Entry#gas_entry.v#match_v.rule, erule_v) ->
  % regular expression
  Node    = Entry#gas_entry.k#match_k.node,
  X       = Entry#gas_entry.k#match_k.x,
  Y       = Entry#gas_entry.k#match_k.y,
  D       = Entry#gas_entry.v#match_v.dir,
  Filters = Entry#gas_entry.v#match_v.rule#erule_v.filters,
  Regexp  = Entry#gas_entry.v#match_v.rule#erule_v.regexp,
  Count   = length (Guards),
  Oid2    = [ X | Oid1 ],
  Oid     = format_oid (Oid2),
  case al_rule:match (Word1, Filters) of
    false ->
      ?d_detail (?str_lword_nomatch (Oid, Word1, Node, X, Y, Regexp, Count));
    { true, Word2, Acc } ->
      ?d_detail (?str_lword_match (Oid, Word1, Word2, Node, X, Y, Regexp, Acc, Count)),
      Key   = #variant_k { oid       = Oid2 },
      Value = #evariant_v { node     = Node,
                            expr     = Regexp,
                            word_in  = Word1,
                            word_out = Word2,
                            value    = Acc,
                            guards   = Guards },
      Table = erlang:get (table),
      gen_acc_storage:insert (Table, Key, Value),
      [ { LV0, RV0, IV0 } | Tail0 ] = Cur1,
      Cur2 =
        case D of
          forward  -> [ { [ Acc | LV0 ], RV0, IV0 } | Tail0 ];
          backward -> [ { LV0, [ Acc | RV0 ], IV0 } | Tail0 ];
          inward   -> [ { LV0, RV0, [ Acc | IV0 ] } | Tail0 ]
        end,
      horizontal (Tail, Guards, Word2, Oid2, Cur2, Dst)
  end;

horizontal ([ Entry | Tail ], Guards1, Word, Oid1, Cur1, Dst)
  when is_record (Entry#gas_entry.v#match_v.rule, crule_v) ->
  % complex rule
  X       = Entry#gas_entry.k#match_k.x,
  D       = Entry#gas_entry.v#match_v.dir,
  C       = Entry#gas_entry.v#match_v.rule#crule_v.capacity,
  Name    = Entry#gas_entry.v#match_v.rule#crule_v.name,
  Equ     = Entry#gas_entry.v#match_v.rule#crule_v.equivalent,
  Oid2    = [ X | Oid1 ],
  Oid     = format_oid (Oid2),
  case al_model:select_subrules (Name) of
    [] ->
      % error - empty rule
      ?d_warning (?str_lword_nsubrules (Name)),
      throw (?e_error);
    Subrules ->
      % match subrules
      ?d_detail (?str_lword_state (Oid, Name, Word, format_guards (Guards1))),
      Vertical =
        fun (Horizontal, Y1) ->
          Guards2 = al_model:select_guards (Name, Y1),
          Y2      = Y1 + 1,
          case is_conflict (Guards1, Guards2) of
            true  -> Y2;
            false ->
              Oid3    = [ Y1 | Oid2 ],
              Guards3 = Guards1 ++ Guards2,
              Key   = #variant_k { oid   = Oid3 },
              Value =
                fun (Value0) ->
                  #cvariant_v { node     = Name,
                                equ      = Equ,
                                is_cap   = C,
                                guards   = Guards3,
                                value    = Value0 }
                end,              
              Cur2 = [ { [], [], [] } | Cur1 ],
              Stop1 = construct_stop_rule (Name, D, Key, Value, C),
              case Equ of
                "" ->
                  horizontal (Horizontal ++ [ Stop1 ] ++ Tail, Guards3, Word, Oid3, Cur2, Dst);
                _  ->
                  Stop2 = construct_assignment_rule (Name, D, Name, Equ),
                  horizontal (Horizontal ++ [ Stop1 ] ++ Tail ++ [ Stop2 ], Guards3, Word, Oid3, Cur2, Dst)
              end,
              Y2
          end
        end,
      lists:foldl (Vertical, 1, Subrules)
  end;

horizontal ([ Entry | Tail ], Guards1, Word1, Oid1, Cur, Dst)
  when is_record (Entry#gas_entry.v#match_v.rule, vrule_v),
       Entry#gas_entry.v#match_v.rule#vrule_v.match_type =:= word ->
  % complex vocabular rule
  X       = Entry#gas_entry.k#match_k.x,
  Name    = Entry#gas_entry.v#match_v.rule#vrule_v.name,
  Type    = Entry#gas_entry.v#match_v.rule#vrule_v.voc_type,
  Voc     = Entry#gas_entry.v#match_v.rule#vrule_v.voc,
  C       = Entry#gas_entry.v#match_v.rule#vrule_v.capacity,
  Oid2    = [ X | Oid1 ],
  % vocabular
  Vertical =
    fun (Entry, Y1) ->
      Guards2 = Entry#gas_entry.v#stem_v.guards,
      Y2      = Y1 + 1,
      case is_conflict (Guards1, Guards2) of
        true  -> Y2;
        false ->
          Oid3    = [ Y1 | Oid2 ],
          Guards3 = Guards1 ++ Guards2,
          Stem    = Entry#gas_entry.k#stem_k.stem,
          Word2   =
            case Type of
              exact -> "";
              left  -> lists:nthtail (length (Stem), Word1);
              right -> lists:sublist (Word1, length (Word1) - length (Stem))
            end,
          Count = length (Guards3),
          Oid   = format_oid (Oid3),
          ?d_detail (?str_lword_vocabular (Oid, Stem, Voc, Count)),
          Key   = #variant_k { oid        = Oid3 },
          Value = #vwvariant_v { node     = Name,
                                 word_in  = Word1,
                                 word_out = Word2,
                                 voc      = Voc,
                                 value    = Stem,
                                 is_cap   = C,
                                 guards   = Guards3 },
          Table = erlang:get (table),
          gen_acc_storage:insert (Table, Key, Value),
          horizontal (Tail, Guards3, Word2, Oid3, Cur, Dst),
          Y2
      end
    end,
  lists:foldl (Vertical, 100, al_model:select_stems (Voc, Word1, Type));

horizontal ([ Entry | Tail ], Guards1, Word1, Oid1, Cur1, Dst)
  when is_record (Entry#gas_entry.v#match_v.rule, vrule_v),
       Entry#gas_entry.v#match_v.rule#vrule_v.match_type =:= value ->
  % complex vocabular rule
  X       = Entry#gas_entry.k#match_k.x,
  D       = Entry#gas_entry.v#match_v.dir,
  Name    = Entry#gas_entry.v#match_v.rule#vrule_v.name,
  Type    = Entry#gas_entry.v#match_v.rule#vrule_v.voc_type,
  Voc     = Entry#gas_entry.v#match_v.rule#vrule_v.voc,
  C       = Entry#gas_entry.v#match_v.rule#vrule_v.capacity,
  Oid2    = [ X | Oid1 ],
  case al_model:select_subrules (Name) of
    [] ->
      % error - empty rule
      ?d_warning (?str_lword_nsubrules (Name)),
      throw (?e_error);
    Subrules ->
      % match subrules
      Oid = format_oid (Oid2),
      ?d_detail (?str_lword_state (Oid, Name, Word1, format_guards (Guards1))),
      Vertical =
        fun (Horizontal, Y1) ->
          Guards2 = al_model:select_guards (Name, Y1),
          Y2      = Y1 + 1,
          case is_conflict (Guards1, Guards2) of
            true  -> Y2;
            false ->
              Oid3    = [ Y1 | Oid2 ],
              Guards3 = Guards1 ++ Guards2,
              Key   = #variant_k { oid    = Oid3 },
              Value =
                fun (Value0) ->
                  #vvvariant_v { node     = Name,
                                 voc_type = Type,
                                 voc      = Voc,
                                 value    = Value0,
                                 is_cap   = C,
                                 guards   = Guards3 }
                end,
              Cur2 = [ { [], [], [] } | Cur1 ],
              Stop = construct_stop_rule (Name, D, Key, Value, C),
              horizontal (Horizontal ++ [ Stop ] ++ Tail, Guards3, Word1, Oid3, Cur2, Dst)
          end
        end,
      lists:foldl (Vertical, 1, Subrules)
  end;

horizontal ([ Entry | Tail ], Guards1, Word, Oid1, Cur1, Dst)
  when is_record (Entry#gas_entry.v#match_v.rule, srule_v) ->
  Dir      = Entry#gas_entry.v#match_v.dir,
  Key      = Entry#gas_entry.v#match_v.rule#srule_v.key,
  Valuer   = Entry#gas_entry.v#match_v.rule#srule_v.value,
  Capacity = Entry#gas_entry.v#match_v.rule#srule_v.capacity,
  [ { LV0, RV0, IV0 } | Tail0 ] = Cur1,
  LV = lists:flatten (lists:reverse (LV0)),
  RV = lists:flatten (RV0),
  IV = lists:flatten (lists:reverse (IV0)),
  Value0 = LV ++ IV ++ RV,
  Table  = erlang:get (table),
  Value  = Valuer (Value0),
  Cur2 =
    case Tail0 of
      [] -> [];
      [ { LV01, RV01, IV01 } | Tail01 ] when Capacity =:= false ->
        [ { LV01, RV01, IV01 } | Tail01 ];
      [ { LV01, RV01, IV01 } | Tail01 ] when Capacity =:= true ->
        case Dir of
          forward  -> [ { [ Value0 | LV01 ], RV01, IV01 } | Tail01 ];
          backward -> [ { LV01, [ Value0 | RV01 ], IV01 } | Tail01 ];
          inward   -> [ { LV01, RV01, [ Value0 | IV01 ] } | Tail01 ]
        end
    end,
  case Value of
    #cvariant_v { node = N, value = V } ->
      gen_acc_storage:insert (Table, Key, Value),
      horizontal (Tail, Guards1, Word, Oid1, Cur2, [ { N, V } | Dst ]);
    #vvvariant_v { voc = Voc, voc_type = Type, node = N, value = V } ->
      % vocabular
      Vertical =
        fun (Entry, Y1) ->
          Guards2 = Entry#gas_entry.v#stem_v.guards,
          Y2      = Y1 + 1,
          case is_conflict (Guards1, Guards2) of
            true  -> Y2;
            false ->
              Oid2    = [ Y1 | Oid1 ],
              Guards3 = Guards1 ++ Guards2,
              Stem    = Entry#gas_entry.k#stem_k.stem,
              Count   = length (Guards3),
              Oid     = format_oid (Oid2),
              KeyY    = Key#variant_k { oid = Oid2 },
              ValueY  = Value#vvvariant_v { value = Stem },
              ?d_detail (?str_lword_vocabular (Oid, Stem, Voc, Count)),
              gen_acc_storage:insert (Table, KeyY, ValueY),
              horizontal (Tail, Guards3, Word, Oid2, Cur2, [ { N, V } | Dst ]),
              Y2
          end
        end,
      lists:foldl (Vertical, 100, al_model:select_stems (Voc, Value0, Type))
  end;

horizontal ([ Entry | Tail ], Guards, Word, Oid, Cur, Dst0)
  when is_record (Entry#gas_entry.v#match_v.rule, arule_v) ->
  Src = Entry#gas_entry.v#match_v.rule#arule_v.rule_src,
  Dst = Entry#gas_entry.v#match_v.rule#arule_v.rule_dst,
  V1  = proplists:get_value (Src, Dst0),
  V2  = proplists:get_value (Dst, Dst0),
  case V1 =:= V2 of
    true  -> horizontal (Tail, Guards, Word, Oid, Cur, Dst0);
    false -> ok
  end.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

%
% guards checker
%

is_conflict (Guards1, Guards2) ->
  Fun1 =
    fun
      (#guard_v { name = Name1, sign = Sign1, base = Base1 }) ->
        Fun2 =
          fun
            (#guard_v { name = Name2, sign = Sign2, base = Base2 })
              when Name1 =/= Name2 ->
              case Base1 =/= Base2 of
                true  -> false;
                false -> Sign1 =:= Sign2
              end;
            (#guard_v { name = Name2, sign = Sign2 })
              when Name1 =:= Name2 ->
                Sign1 =/= Sign2
          end,
        lists:any (Fun2, Guards2)
    end,
  lists:any (Fun1, Guards1).

%
% class searcher
%

which_class (Guards) ->
  case do_which_class (Guards, []) of
    [] ->
      ?d_warning (?str_lword_uclass),
      throw (?e_error);
    [ Class ] -> Class;
    Classes ->
      ?d_warning (?str_lword_aclass (Classes)),
      throw (?e_error)
  end.

do_which_class ([], Classes) ->
  sets:to_list (sets:from_list (Classes));

do_which_class ([ Guard | _Tail ], _Classes)
  when Guard#guard_v.name =:= Guard#guard_v.base ->
  [ Guard#guard_v.name ];

do_which_class ([ Guard | Tail ], Classes1)
  when Guard#guard_v.name =/= Guard#guard_v.base ->
  Fun =
    fun (#gas_entry { k = #entity_k { name = Class },
                      v = #entity_v { properties = Props } }) ->
      Members = proplists:get_value (members, Props),
      case lists:member (Guard#guard_v.base, Members) of
        false -> false;
        true  -> { true, Class }
      end
    end,
  Classes2 = lists:filtermap (Fun, al_model:select_entities ('_', ?ET_CLASS)),
  do_which_class (Tail, Classes2 ++ Classes1).

%
% dump tools
%

dump_detail (Word, Table) ->
  ?d_detail (?str_lword_bdump (Word)),
  Key = #variant_k { oid = '_' },
  Entries1 = gen_acc_storage:select (Table, Key, '_'),
  Comparator =
    fun (#gas_entry { k = #variant_k { oid = Oid1 } },
         #gas_entry { k = #variant_k { oid = Oid2 } }) ->
        string:to_integer (Oid1) < string:to_integer (Oid2)
    end,
  Entries2 = lists:sort (Comparator, Entries1),
  Fun      =
    fun
      (#gas_entry { k = #variant_k { oid       = Oid },
                    v = #evariant_v { node     = N,
                                      expr     = E,
                                      word_in  = WI,
                                      word_out = WO,
                                      value    = V,
                                      guards   = Guards } }) ->
        OID = format_oid (Oid),
        GS  = format_guards (Guards),
        ?d_detail (?str_lword_iedump (OID, N, E, V, WI, WO, GS));
      (#gas_entry { k = #variant_k { oid       = Oid },
                    v = #cvariant_v { node     = N,
                                      guards   = Guards } }) ->
        OID = format_oid (Oid),
        GS  = format_guards (Guards),
        ?d_detail (?str_lword_icdump (OID, N, GS));
      (#gas_entry { k = #variant_k { oid        = Oid },
                    v = #vvvariant_v { node     = N,
                                       value    = V,
                                       guards   = Guards } }) ->
        OID = format_oid (Oid),
        GS  = format_guards (Guards),
        ?d_detail (?str_lword_ivdump (OID, N, V, GS));
      (#gas_entry { k = #variant_k { oid        = Oid },
                    v = #vwvariant_v { node     = N,
                                       word_in  = WI,
                                       word_out = WO,
                                       value    = V,
                                       guards   = Guards } }) ->
        OID = format_oid (Oid),
        GS  = format_guards (Guards),
        ?d_detail (?str_lword_iwdump (OID, N, V, WI, WO, GS))
    end,
  lists:foreach (Fun, Entries2),
  ?d_detail (?str_lword_edump (Word)).

dump_words (Word, Table) ->
  ?d_detail (?str_lword_bwlist (Word)),
  Key = #word_k { oid = '_' },
  Entries1 = gen_acc_storage:select (Table, Key, '_'),
  Comparator =
    fun (#gas_entry { k = #word_k { oid = Oid1 } },
         #gas_entry { k = #word_k { oid = Oid2 } }) ->
        string:to_integer (Oid1) < string:to_integer (Oid2)
    end,
  Entries2 = lists:sort (Comparator, Entries1),
  Fun1     =
    fun (#gas_entry { k = #word_k { oid        = Oid },
                      v = #word_v { guards     = Guards,
                                    auxiliary  = AU,
                                    vocabulars = VS,
                                    class      = C } }) ->
      OID = format_oid (Oid),
      GS  = format_guards (Guards),
      ?d_detail (?str_lword_wlist1 (OID, C, GS)),
      Fun2 =
        fun
          ({ aux, Node, Value }) ->
            ?d_detail (?str_lword_wlist2 (Node, Value));
          ({ voc, Node, Value, Voc }) ->
            ?d_detail (?str_lword_wlist2 (Node, Value ++ " (" ++ Voc ++ ")"))
        end,
      lists:foreach (Fun2, VS ++ AU)
    end,
  lists:foreach (Fun1, Entries2),
  ?d_detail (?str_lword_ewlist (Word)),
  Entries2.

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

%
% constructors
%

construct_rule (Node, Name) ->
  Entity     = al_model:get_entity_value (Name, ?ET_MATCH),
  Direction  = proplists:get_value (direction, Entity#entity_v.properties),
  Capacity   = proplists:get_value (capacity, Entity#entity_v.properties),
  Rule       =
    case proplists:get_value (vocabulary, Entity#entity_v.properties) of
      undefined ->
        #crule_v { name = Name, capacity = Capacity, equivalent = "" };
      { Voc, VocType, MatchType } ->
        #vrule_v { name       = Name,
                   voc        = Voc,
                   voc_type   = VocType,
                   match_type = MatchType,
                   capacity   = Capacity }
    end,
  #gas_entry { k = #match_k { node = Node, x = 1, y = 1 },
               v = #match_v { dir = Direction, rule = Rule } }.

construct_stop_rule (Node, Direction, Key, Evaluator, Capability) ->
  Rule = #srule_v { key = Key, value = Evaluator, capacity = Capability },
  #gas_entry { k = #match_k { node = Node, x = 0, y = 0 },
               v = #match_v { dir = Direction, rule = Rule } }.

construct_assignment_rule (Node, Direction, Src, Dst) ->
  Rule = #arule_v { rule_src = Src, rule_dst = Dst },
  #gas_entry { k = #match_k { node = Node, x = 0, y = 0 },
               v = #match_v { dir = Direction, rule = Rule } }.

%
% formatters
%

format_oid (Oid) ->
  do_format_oid (Oid, "").

do_format_oid ([], Acc) -> Acc;
do_format_oid ([ N | Oid ], Acc) ->
  do_format_oid (Oid, integer_to_list (N) ++ "." ++ Acc).

format_guards (Guards) ->
  do_format_guards (Guards, "").

do_format_guards ([], Acc) -> Acc;
do_format_guards ([ Guard | Tail ], Acc) ->
  Name = Guard#guard_v.name,
  case Guard#guard_v.sign of
    positive -> do_format_guards (Tail, " " ++ Name ++ Acc);
    negative -> do_format_guards (Tail, " ~" ++ Name ++ Acc)
  end.

%
% routers
%

get_route (Oid, Table) ->
  do_get_route (Oid, Table, []).

do_get_route ([], _Table, Acc) -> Acc;
do_get_route ([ _ | Tail ] = Oid, Table, Acc1) ->
  Key = #variant_k { oid = Oid },
  Acc2 =
    case gen_acc_storage:select (Table, Key, '_') of
      [] -> Acc1;
      [ #gas_entry { v = #evariant_v { expr = _Expr0, value = _Value0 } } ] ->
        Acc1;
      [ #gas_entry { v = #cvariant_v { is_cap = false } } ] ->
        Acc1;
      [ #gas_entry { v = #cvariant_v { node = Node0, value = Value0 } } ] ->
        [ { aux, Node0, Value0 } | Acc1 ];
      [ #gas_entry { v = #vwvariant_v { is_cap = false } } ] ->
        Acc1;
      [ #gas_entry { v = #vwvariant_v { node = Node0, value = Value0, voc = Voc0 } } ] ->
        [ { voc, Node0, Value0, Voc0 } | Acc1 ];
      [ #gas_entry { v = #vvvariant_v { is_cap = false } } ] ->
        Acc1;
      [ #gas_entry { v = #vvvariant_v { node = Node0, value = Value0, voc = Voc0 } } ] ->
        [ { voc, Node0, Value0, Voc0 } | Acc1 ]
    end,
  do_get_route (Tail, Table, Acc2).
