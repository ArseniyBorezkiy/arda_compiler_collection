%% Word matcher.
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (word).

% API
-export ([
          parse/1,
          format_oid/1
        ]).

% HEADERS
-include ("general.hrl").
-include ("model.hrl").
-include ("output.hrl").

% DEFINITIONS
-record (variant, { oid      :: list (unsigned_t ()), 
                    match    :: string (),
                    word_in  :: string (),
                    word_out :: string (),
                    value    :: string (),
                    guards   :: list (string ()) }).

% =============================================================================
% API
% =============================================================================

parse (Word) ->
  Table = ets:new ('case storage', [ set, private, { keypos, 2 } ]),
  try
    [ Match ] = model:ensure (target),
    Rule = #rule { instance = { Match, 1, 1 }, name = Match, direction = forward },
    horizontal ([ Rule ], [], Word, Table, []),
    dump_detail (Word, Table),
    Words = dump_words (Word, Table),
    Words
  after
    ets:delete (Table)
  end.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

horizontal ([], Guards, Word, Table, OID1) ->
  % estimated stem
  Stems  = model:get_stems (),
  Search =
    fun (Stem, Acc1) ->
      case Stem == Word of
        true ->
          Vocabularies = model:get_vocabularies (Stem),                  
          Subsearch    =
            fun (Vocabulary, Acc2) ->
              Subguards = model:get_characteristics (Vocabulary, Stem),
              case is_conflict (Guards, Subguards) of
                true  -> Acc2;
                false ->
                  OID2 = [ Acc2, Acc1 | OID1 ],
                  FinalGuards = sets:to_list (sets:from_list (Guards ++ Subguards)),                  
                  % determine word class
                  case which_class (FinalGuards) of
                    undefined -> Acc2 + 1;
                    Class ->
                      Args = [ Word, Class, length (FinalGuards) ],
                      detail (OID2, " : vocabular '~s' ('~s') | ~p", Args),
                      Entry = #word { oid    = OID2,
                                      guards = FinalGuards,
                                      route  = get_route (OID1, Table),
                                      stem   = Stem,
                                      class  = Class },
                      ets:insert (Table, Entry),
                      Acc2 + 1
                  end
              end
            end,
          lists:foldl (Subsearch, 1000, Vocabularies),
          Acc1 + 1;
        false -> Acc1
      end
    end,
  lists:foldl (Search, 1000, Stems),
  ok;
  
horizontal ([ Expression | Tail ], Guards, Word, Table, OID1)
  when is_record (Expression, regexp) ->
  % single regular expression
  { Match, X, Y } = Expression#regexp.instance,
  Filters = Expression#regexp.filters,
  Text    = Expression#regexp.expression,
  OID2    = [ X | OID1 ],
  case rule:match (Word, Filters) of
    false ->
      Args = [ Word, Match, X, Y, Text, length (Guards) ],
      detail (OID2, " : no match '~s' for ~s (~p,~p): ~s | ~p", Args);
    { true, Subword, Value } ->
      Args = [ Word, Subword, Match, X, Y, Text, Value, length (Guards) ],
      detail (OID2, " : match '~s' -> '~s' for ~s (~p,~p): ~s = ~s | ~p", Args),
      Variant = #variant { oid      = OID2,
                           match    = Match,
                           word_in  = Word,
                           word_out = Subword,
                           value    = Value,
                           guards   = Guards },
      ets:insert (Table, Variant),
      horizontal (Tail, Guards, Subword, Table, OID2)
  end;

horizontal ([ Rule | Tail ], Guards, Word, Table, OID1)
  when is_record (Rule, rule) ->
  % single complex rule
  { _, X, _ } = Rule#rule.instance,
  Match = Rule#rule.name,
  OID2  = [ X | OID1 ],
  case model:get_subrules (Match) of
    [] ->
      [ Voc ] = model:ensure (vocabular),
      case Voc of
        Match -> horizontal (Tail, Guards, Word, Table, OID2);
        _ ->
          % bad grammar reference
          debug:warning (?MODULE, "the rule '~s' have not subrules", [ Match ]),
          throw (error)
      end;
    Subrules ->
      % match subrules
      detail (OID2, " : rule: '~s', word: '~s' | ~s", [ Match, Word, format_guards (Guards) ]),
      Vertical =
        fun (Horizontal, Ordinal) ->
          Subguards  = model:get_guards (Match, Ordinal),
          NewOrdinal = Ordinal + 1,
          case is_conflict (Guards, Subguards) of
            true  -> NewOrdinal;
            false ->
              NextOID    = [ Ordinal | OID2 ],
              NextGuards = Guards ++ Subguards,
              horizontal (Horizontal ++ Tail, NextGuards, Word, Table, NextOID),
              NewOrdinal
          end
        end,
      lists:foldl (Vertical, 1, Subrules)
  end.

is_conflict (Guards1, Guards2) ->
  Fun2 =
    fun
      ({ _Guard2, undefined }) -> false;
      ({ Guard2, Negotiated2 }) ->
        Fun1 =
          fun
            ({ _Guard1, undefined }) -> false;
            ({ Guard1, Negotiated1 }) when Guard1 =/= Guard2 ->
              Entity1 = model:get_entity_name (Guard1),
              Entity2 = model:get_entity_name (Guard2),
              case Entity1 =/= Entity2 of
                true  -> false;
                false -> Negotiated1 =:= Negotiated2
              end;
            ({ _Guard2, Negotiated1 }) when Negotiated1 =/= Negotiated2 -> true;
            ({ _Guard2, _Negotiated2 }) -> false
          end,
        lists:any (Fun1, Guards1)
    end,
  lists:any (Fun2, Guards2).

which_class (Guards) ->
  case do_which_class (Guards, undefined) of
    [] -> undefined;
    [ Class ] -> Class;
    Classes ->
      debug:warning (?MODULE, "class ambiguity: ~p", [ Classes ]),
      undefined
  end.

do_which_class ([], undefined) -> [];
do_which_class ([], Classes) -> sets:to_list (Classes);
do_which_class ([ { Class, undefined } | _Tail ], _Classes1) ->
  [ Class ];
do_which_class ([ { Guard, _Negotiated } | Tail ], Classes1) ->
  Attribute = model:get_entity_name (Guard),
  Filtermap =
    fun
      (#property { name = #member { class = Class, member = Attribute0 } })
        when Attribute == Attribute0 ->
        { true, Class };
      (_) -> false
    end,
  Classes2 = sets:from_list (model:select_properties (Filtermap)),
  Classes  =
    case Classes1 of
      undefined -> Classes2;
      _ -> sets:intersection (Classes1, Classes2)
    end,
  do_which_class (Tail, Classes).

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

dump_detail (Word, Table) ->
  debug:detail (?MODULE, "-- ~s: dump begin", [ Word ]),
  Unsorted = ets:match_object (Table, #variant { oid      = '_',
                                                 match    = '_',
                                                 word_in  = '_',
                                                 word_out = '_',
                                                 value    = '_',
                                                 guards   = '_' }),
  Comparator =
    fun (#variant { oid = OID1 }, #variant { oid = OID2 }) ->
        string:to_integer (OID1) < string:to_integer (OID2)
    end,
  Entries = lists:sort (Comparator, Unsorted),  
  case Entries of
    [] -> ok;
    _  ->
      Fun =
        fun (#variant { oid      = OID,
                        match    = M,
                        word_in  = WI,
                        word_out = WO,
                        value    = V,
                        guards   = GS }) ->
            Format = "~s : ~s = ~s; ~s -> ~s | ~s",
            Args   = [ format_oid (OID), M, V, WI, WO, format_guards (GS) ],
            debug:detail (?MODULE, Format, Args)
        end,
      lists:foreach (Fun, Entries)
  end,
  debug:detail (?MODULE, "-- ~s: dump end", [ Word ]).

dump_words (Word, Table) ->
  debug:detail (?MODULE, "-- ~s: word list begin", [ Word ]),
  Unsorted = ets:match_object (Table, #word { oid    = '_',
                                              guards = '_',
                                              route  = '_',
                                              stem   = '_',
                                              class  = '_' }),
  Comparator =
    fun (#word { oid = OID1 }, #word { oid = OID2 }) ->
        string:to_integer (OID1) < string:to_integer (OID2)
    end,
  Entries = lists:sort (Comparator, Unsorted),  
  case Entries of
    [] -> ok;
    _  ->
      Fun =
        fun (#word { oid = OID, guards = Guards, route = Route, stem = Stem, class = Class }) ->
            Format = "~s (~s) : ~s | ~s",
            Args   = [ format_oid (OID), Class, Stem, format_guards (Guards) ],
            debug:detail (?MODULE, Format, Args),
            PrintRoute =
              fun ({ Match, Value }) ->
                debug:detail (?MODULE, "  ~s = ~s", [ Match, Value ])
              end,
            lists:foreach (PrintRoute, Route)
        end,
      lists:foreach (Fun, Entries)
  end,
  debug:detail (?MODULE, "-- ~s: word list end", [ Word ]),
  Entries.

detail (OID, Format, Args) ->
  debug:detail (?MODULE, format_oid (OID) ++ Format, Args).

format_oid (OID) ->
  do_format_oid (OID, "").

do_format_oid ([], Acc) -> Acc;
do_format_oid ([ Ordinal | OID ], Acc) ->
  do_format_oid (OID, integer_to_list (Ordinal) ++ "." ++ Acc).

format_guards (Guards) ->
  do_format_guards (Guards, "").

do_format_guards ([], Acc) -> Acc;
do_format_guards ([ { Guard, Negotiate } | Tail ], Acc) ->
  case Negotiate of
    false     -> do_format_guards (Tail, " " ++ Guard ++ Acc);
    undefined -> do_format_guards (Tail, " " ++ Guard ++ Acc);
    true      -> do_format_guards (Tail, " ~" ++ Guard ++ Acc)
  end.

get_route (OID, Table) ->
  do_get_route (OID, Table, []).

do_get_route ([], _Table, Acc) -> Acc;
do_get_route ([ _ | Tail ] = OID, Table, Acc) ->
  Mask = #variant { oid      = OID,
                    match    = '_',
                    word_in  = '_',
                    word_out = '_',
                    value    = '_',
                    guards   = '_' },
  NewAcc =
    case ets:select (Table, [ { Mask, [], ['$_'] } ]) of
      [] -> Acc;
      [ #variant { match = Match, value = Value } ] -> [ { Match, Value } | Acc ]
    end,
  do_get_route (Tail, Table, NewAcc).
