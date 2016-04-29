%% @doc Word matcher.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
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

-record (variant_v, { node     :: string (),
                      word_in  :: string (),
                      word_out :: string (),
                      value    :: string (),
                      guards   :: list (string ()) }).

% =============================================================================
% API
% =============================================================================

parse (Word) ->
  Table = gen_acc_storage:create_table (?MODULE, set),
  erlang:put (table, Table),
  try
    [ Node ]  = al_model:ensure (target),
    Main      = construct_rule (Node, Node),
    horizontal ([ Main ], [], Word, []),
    dump_detail (Word, Table),
    dump_words (Word, Table)
  after
    gen_acc_storage:delete_table (Table)
  end.

% =============================================================================
% RULE MATCHING
% =============================================================================

horizontal ([], _Guards, _Word, _Oid) ->
  ok;
  
horizontal ([ Entry | Tail ], Guards, Word1, Oid1)
  when is_record (Entry#gas_entry.v#match_v.rule, erule_v) ->
  % regular expression
  Node    = Entry#gas_entry.k#match_k.node,
  X       = Entry#gas_entry.k#match_k.x,
  Y       = Entry#gas_entry.k#match_k.y,
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
      Key   = #variant_k { oid      = Oid2 },
      Value = #variant_v { node     = Node,
                           word_in  = Word1,
                           word_out = Word2,
                           value    = Acc,
                           guards   = Guards },
      Table = erlang:get (table),
      gen_acc_storage:insert (Table, Key, Value),
      horizontal (Tail, Guards, Word2, Oid2)
  end;

horizontal ([ Entry | Tail ], Guards1, Word, Oid1)
  when is_record (Entry#gas_entry.v#match_v.rule, crule_v) ->
  % complex rule
  Node    = Entry#gas_entry.k#match_k.node,
  X       = Entry#gas_entry.k#match_k.x,
  Name    = Entry#gas_entry.v#match_v.rule#crule_v.name,
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
          Guards2 = al_model:select_guards (Node, Y1),
          Y2      = Y1 + 1,
          case is_conflict (Guards1, Guards2) of
            true  -> Y2;
            false ->
              Oid3    = [ Y1 | Oid2 ],
              Guards3 = Guards1 ++ Guards2,
              horizontal (Horizontal ++ Tail, Guards3, Word, Oid3),
              Y2
          end
        end,
      lists:foldl (Vertical, 1, Subrules)
  end;

horizontal ([ Entry | Tail ], Guards1, Word1, Oid1)
  when is_record (Entry#gas_entry.v#match_v.rule, vrule_v) ->
  % complex vocabular rule
  Node    = Entry#gas_entry.k#match_k.node,
  X       = Entry#gas_entry.k#match_k.x,
  Dir     = Entry#gas_entry.v#match_v.dir,
  Name    = Entry#gas_entry.v#match_v.rule#vrule_v.name,
  Voc     = Entry#gas_entry.v#match_v.rule#vrule_v.voc,
  Oid2    = [ X | Oid1 ],  
  case al_model:select_subrules (Name) of
    [] ->
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
                case Dir of
                  prefix ->
                    lists:nthtail (length (Stem), Word1);
                  postfix ->
                    lists:sublist (Word1, length (Word1) - length (Stem))
                end,
              Count = length (Guards3),
              Oid   = format_oid (Oid3),
              ?d_detail (?str_lword_vocabular (Oid, Stem, Voc, Count)),
              Table = erlang:get (table),
              Route = get_route (Oid3, Table),
              Key   = #word_k { oid      = Oid3 },
              Value = #word_v { guards   = Guards3,
                                route    = Route,
                                stem     = Stem,
                                class    = "" },
              gen_acc_storage:insert (Table, Key, Value),
              horizontal (Tail, Guards3, Word2, Oid3),
              Y2
          end
        end,
      lists:foldl (Vertical, 100, al_model:select_stems (Voc, Word1, Dir));
    Subrules ->
      % match subrules
      Oid = format_oid (Oid2),
      ?d_detail (?str_lword_state (Oid, Name, Word1, format_guards (Guards1))),
      Vertical =
        fun (Horizontal, Y1) ->
          Guards2 = al_model:select_guards (Node, Y1),
          Y2      = Y1 + 1,
          case is_conflict (Guards1, Guards2) of
            true  -> Y2;
            false ->
              Oid3    = [ Y1 | Oid2 ],
              Guards3 = Guards1 ++ Guards2,
              Key     = Entry#gas_entry.k#match_k { x = 0, y = 0 },
              Value   = Entry#gas_entry.v#match_v.rule#vrule_v { name = ".vocabular " ++ Name },
              Phony   = Entry#gas_entry { k = Key, v = Value },
              horizontal (Horizontal ++ [ Phony ] ++ Tail, Guards3, Word1, Oid3),
              Y2
          end
        end,
      lists:foldl (Vertical, 1, Subrules)
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
  case do_which_class (Guards, undefined) of
    [] -> undefined;
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
  Key   = #variant_k { oid      = '_' },
  Value = #variant_v { node     = '_',
                       word_in  = '_',
                       word_out = '_',
                       value    = '_',
                       guards   = '_' },
  Entries1 = gen_acc_storage:select (Table, Key, Value),
  Comparator =
    fun (#gas_entry { k = #variant_k { oid = Oid1 } },
         #gas_entry { k = #variant_k { oid = Oid2 } }) ->
        string:to_integer (Oid1) < string:to_integer (Oid2)
    end,
  Entries2 = lists:sort (Comparator, Entries1),
  Fun      =
    fun (#gas_entry { k = #variant_k { oid = Oid },
                      v = #variant_v { node     = N,
                                       word_in  = WI,
                                       word_out = WO,
                                       value    = V,
                                       guards   = Guards } }) ->
      OID = format_oid (Oid),
      GS  = format_guards (Guards),
      ?d_detail (?str_lword_dump (OID, N, V, WI, WO, GS))
    end,
  lists:foreach (Fun, Entries2),
  ?d_detail (?str_lword_edump (Word)).

dump_words (Word, Table) ->
  ?d_detail (?str_lword_bwlist (Word)),
  Key   = #word_k { oid    = '_' },
  Value = #word_v { guards = '_',
                    route  = '_',
                    stem   = '_',
                    class  = '_' },
  Entries1 = gen_acc_storage:select (Table, Key, Value),
  Comparator =
    fun (#gas_entry { k = #word_k { oid = Oid1 } },
         #gas_entry { k = #word_k { oid = Oid2 } }) ->
        string:to_integer (Oid1) < string:to_integer (Oid2)
    end,
  Entries2 = lists:sort (Comparator, Entries1),
  Fun1     =
    fun (#gas_entry { k = #word_k { oid    = Oid },
                      v = #word_v { guards = Guards,
                                    route  = Route,
                                    stem   = S,
                                    class  = C } }) ->
      OID = format_oid (Oid),
      GS  = format_guards (Guards),
      ?d_detail (?str_lword_wlist1 (OID, C, S, GS)),
      Fun2 =
        fun ({ Node, Value }) ->
          ?d_detail (?str_lword_wlist2 (Node, Value))
        end,
      lists:foreach (Fun2, Route)
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
  Rule       =
    case proplists:get_value (vocabulary, Entity#entity_v.properties) of
      undefined  -> #crule_v { name = Name };
      Vocabulary -> #vrule_v { name = Name, voc = Vocabulary }
    end,
  #gas_entry { k = #match_k { node = Node, x = 1, y = 1 },
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
  Key   = #variant_k { oid      = Oid },
  Value = #variant_v { node     = '_',
                       word_in  = '_',
                       word_out = '_',
                       value    = '_',
                       guards   = '_' },
  Acc2 =
    case gen_acc_storage:select (Table, Key, Value) of
      [] -> Acc1;
      [ #gas_entry { v = #variant_v { node = Node0, value = Value0 } } ] ->
        [ { Node0, Value0 } | Acc1 ]
    end,
  do_get_route (Tail, Table, Acc2).
