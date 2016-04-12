%% Word matcher.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (word).

% API
-export ([
          parse/1
        ]).

% HEADERS
-include ("general.hrl").
-include ("model.hrl").

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
    Rule = #rule { instance = { Match, 1, 1 }, name = Match },
    horizontal ([ Rule ], [], Word, Table, []),
    dump (Table),
    []
  after
    ets:delete (Table)
  end.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

horizontal ([], _Guards, _Word, _Table, _OID) -> ok;
  
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
  { _, X, Y } = Rule#rule.instance,
  Match = Rule#rule.name,
  OID2  = [ X | OID1 ],
  case model:get_subrules (Match) of
    [] ->
      [ Voc ] = model:ensure (vocabular),
      case Voc of
        Match ->
          % vocabular entry
          Stems  = model:get_stems (),
          Search =
            fun (Stem, Acc1) ->
              case string:str (Word, Stem) of
                1 ->
                  Subword      = lists:nthtail (length (Stem), Word),
                  Vocabularies = model:get_vocabularies (Stem),                  
                  Subsearch    =
                    fun (Vocabulary, Acc2) ->
                      Subguards = model:get_characteristics (Vocabulary, Stem),
                      case is_conflict (Guards, Subguards) of
                        true  -> Acc2;
                        false ->
                          OID3 = [ Acc2, Acc1 | OID2 ],
                          NextGuards = Guards ++ Subguards,
                          Args = [ Word, Subword, X, Y, Match, Stem, length (NextGuards) ],
                          detail (OID2, " : vocabular '~s' -> '~s' (~p,~p): ~s = ~s | ~p", Args),
                          Variant = #variant { oid      = OID3,
                                               match    = Match,
                                               word_in  = Word,
                                               word_out = Subword,
                                               value    = Stem,
                                               guards   = NextGuards },
                          ets:insert (Table, Variant),
                          horizontal (Tail, NextGuards, Subword, Table, OID3),
                          Acc2 + 1
                      end
                    end,
                  lists:foldl (Subsearch, 200, Vocabularies),
                  Acc1 + 1;
                _ -> Acc1
              end
            end,
          lists:foldl (Search, 100, Stems);
        _ ->
          % bad grammar reference
          debug:warning (?MODULE, "the rule '~s' have not subrules", [ Match ]),
          throw (error)
      end;
    Subrules ->
      % match subrules
      detail (OID2, " : rule: '~s', word: '~s' | ~p", [ Match, Word, length (Guards) ]),
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
    fun (Guard2) ->
      Fun1 =
        fun
          (Guard1) when Guard1 =/= Guard2 ->
            Entity1 = model:get_entity_name (Guard1),
            Entity2 = model:get_entity_name (Guard2),
            Entity1 =:= Entity2;
          (_) -> false
        end,
      lists:any (Fun1, Guards1)
    end,
  lists:any (Fun2, Guards2).

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

dump (Table) ->
  debug:detail (?MODULE, "-- dump begin"),
  Unsorted = ets:match_object (Table, #variant { oid      = '_',
                                                 match    = '_',
                                                 word_in  = '_',
                                                 word_out = '_',
                                                 value    = '_',
                                                 guards   = '_' }),
  Comparator =
    fun
      (#variant { oid = OID1 }, #variant { oid = OID2 }) ->
        string:to_integer (OID1) < string:to_integer (OID2)
    end,
  Entries = lists:sort (Comparator, Unsorted),  
  case Entries of
    [] -> ok;
    _  ->
      Fun =
        fun
          (#variant { oid      = OID,
                      match    = M,
                      word_in  = WI,
                      word_out = WO,
                      value    = V,
                      guards   = GS }) ->
            Format = "~s : ~s = ~s; ~s -> ~s | ~p",
            Args   = [ format_oid (OID), M, V, WI, WO, GS ],
            debug:detail (?MODULE, Format, Args)
        end,
      lists:foreach (Fun, Entries)
  end,
  debug:detail (?MODULE, "-- dump end").

detail (OID, Format, Args) ->
  debug:detail (?MODULE, format_oid (OID) ++ Format, Args).

format_oid (OID) ->
  do_format_oid (OID, "").

do_format_oid ([], Acc) -> Acc;
do_format_oid ([ Ordinal | OID ], Acc) ->
  do_format_oid (OID, integer_to_list (Ordinal) ++ "." ++ Acc).