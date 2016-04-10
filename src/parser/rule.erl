%% Match expression analyzer.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (rule).

% API
-export ([
          parse/1,
          match/2
        ]).

% HEADERS
-include ("model.hrl").
-include ("general.hrl").

% DEFINITIONS
-define (ET_MASK, mask).

% =============================================================================
% API
% =============================================================================

parse (Rule) ->
  case do_parse (Rule, none, []) of
    error -> throw (error);
    Filters -> Filters
  end.

match (Word, Filters) ->
  do_match (Filters, Word, []).

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

do_match ([], Word, Acc) -> { true, Word, Acc };
do_match ([ Filter | Tail ], Word1, Acc1) ->
  case Filter (Word1, Acc1) of
    error -> throw (error);
    false -> false;
    { Word2, Acc2 } ->
      do_match (Tail, Word2, Acc2)
  end.

%
% rule parser
%

do_parse ([], _Mode, Acc) ->
  lists:reverse (Acc);

do_parse ([ $+ | Tail ], _Mode, Acc) ->
  do_parse (Tail, rift, Acc);

do_parse ([ $- ], none = Mode, Acc) ->
  % { X, [] } -> { X, X }
  Fun =
    fun
      (Word, []) -> { Word, Word };
      (_, _) ->
        debug:log (?DL_WARNING, "non empty accumulator in ~p", [ ?MODULE ]),
        error
    end,
  do_parse ([], Mode, [ Fun | Acc ]);

do_parse ([ $- ], hold = Mode, Acc) ->
  % { X, Y } -> { X, YX }
  Fun = fun (Word, Value) -> { Word, Value ++ Word } end,
  do_parse ([], Mode, [ Fun | Acc ]);

do_parse ([ $- ], rift = Mode, Acc) ->
  % { X, Y } -> { [], XY }
  Fun = fun (Word, Value) -> { [], Value ++ Word } end,
  do_parse ([], Mode, [ Fun | Acc ]);

do_parse ([ $- | Tail ], _Mode, Acc) ->
  do_parse (Tail, hold, Acc);

do_parse ([ Char0 | Tail ], rift = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { cX , Y } -> { X, Yc }
  Fun =
    fun
      ([ Char | Word ], Value) when Char == Char0 ->
        { Word, Value ++ [ Char ] };
      (_, _) -> false
    end,
  do_parse (Tail, Mode, [ Fun | Acc ]);

do_parse ([ Char0 | Tail ], hold = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { cX , Y } -> { cX, Yc }
  Fun =
    fun
      ([ Char | Word ], Value) when Char == Char0 ->
        { [ Char | Word ], Value ++ [ Char ] };
      (_, _) -> false
    end,
  do_parse (Tail, Mode, [ Fun | Acc ]);

do_parse (Rule, Mode, Acc) when Mode == hold orelse Mode == rift ->
  % { ?X, Y } -> { ?X, Y? }
  % { ?X, Y } -> { X, Y? }
  AlphabetFilter =
    fun (#entity { name = Name, type = Type, tag = Tag }) ->
      case string:str (Rule, Tag) of
        1 when Type == ?ET_ALPHABET -> { true, { Name, length (Tag) } };
        _ -> false
      end
    end,
  case lists:filtermap (AlphabetFilter, model:get_entities ()) of
    [] ->
      debug:log (?DL_WARNING, "unknown mask ~p in ~p", [ Rule, ?MODULE ]),
      error;
    [ { Alphabet, WildcardLen } ] ->
      Phonemes = model:get_properties (Alphabet), 
      Fun =
        fun
          (Word, Value) ->
            PhonemesFilter =
              fun (#property { name = Phoneme }) ->
                case string:str (Word, Phoneme) of
                  1 -> { true, Phoneme };
                  _ -> false
                end
              end,
            case lists:filtermap (PhonemesFilter, Phonemes) of
              [] -> false;
              [ Phoneme ] ->
                case Mode of
                  hold -> { Word, Value ++ Phoneme };
                  rift -> { lists:nthtail (length (Phoneme), Word), Value ++ Phoneme }
                end;
              _ ->
                debug:log (?DL_WARNING, "property ambiguity ~p in ~p", [ Word, ?MODULE ]),
                error
            end
        end,
      do_parse (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    _ ->
      debug:log (?DL_WARNING, "ambiguity mask ~p in ~p", [ Rule, ?MODULE ]),
      error
  end.
