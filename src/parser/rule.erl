%% Match expression analyzer.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (rule).

% API
-export ([
          parse_forward/1,
          parse_back/1,
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

parse_forward (Rule) ->
  case do_parse_forward (Rule, none, []) of
    error -> throw (error);
    Filters -> Filters
  end.

parse_back (Rule) ->
  case do_parse_back (Rule, none, []) of
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
% forward rule parser
%

do_parse_forward ([], _Mode, Acc) ->
  lists:reverse (Acc);

do_parse_forward ([ $+ | Tail ], _Mode, Acc) ->
  do_parse_forward (Tail, rift, Acc);

do_parse_forward ([ $- ], none = Mode, Acc) ->
  % { X, [] } -> { X, X }
  Fun =
    fun
      (Word, []) -> { Word, Word };
      (_, Value) ->
        debug:warning (?MODULE, "non empty accumulator: ~p", [ Value ]),
        error
    end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

do_parse_forward ([ $- ], hold = Mode, Acc) ->
  % { X, Y } -> { X, YX }
  Fun = fun (Word, Value) -> { Word, Value ++ Word } end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

do_parse_forward ([ $- ], rift = Mode, Acc) ->
  % { X, Y } -> { [], YX }
  Fun = fun (Word, Value) -> { [], Value ++ Word } end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

do_parse_forward ([ $- | Tail ], _Mode, Acc) ->
  do_parse_forward (Tail, hold, Acc);

do_parse_forward ([ Char0 | Tail ], rift = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { cX, Y } -> { X, Yc }
  Fun =
    fun
      ([ Char | Word ], Value) when Char == Char0 ->
        { Word, Value ++ [ Char ] };
      (_, _) -> false
    end,
  do_parse_forward (Tail, Mode, [ Fun | Acc ]);

do_parse_forward ([ Char0 | Tail ], hold = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { cX, Y } -> { cX, Yc }
  Fun =
    fun
      ([ Char | Word ], Value) when Char == Char0 ->
        { [ Char | Word ], Value ++ [ Char ] };
      (_, _) -> false
    end,
  do_parse_forward (Tail, Mode, [ Fun | Acc ]);

do_parse_forward (Rule, Mode, Acc) when Mode == hold orelse Mode == rift ->
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
      debug:warning (?MODULE, "unknown mask ~p", [ Rule ]),
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
                debug:warning (?MODULE, "property ambiguity for word ~p", [ Word ]),
                error
            end
        end,
      do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    _ ->
      debug:warning (?MODULE, "ambiguity mask for ~p", [ Rule ]),
      error
  end;

do_parse_forward (Rule, none, _Acc) ->
  debug:warning (?MODULE, "expected mode '+' or '-' for rule ~p", [ Rule ]),
  error.

%
% backward rule parser
%

do_parse_back ([], _Mode, Acc) ->
  lists:reverse (Acc);

do_parse_back ([ $+ | Tail ], _Mode, Acc) ->
  do_parse_back (Tail, rift, Acc);

do_parse_back ([ $- ], none = Mode, Acc) ->
  % { X, [] } -> { X, X }
  Fun =
    fun
      (Word, []) -> { Word, Word };
      (_, Value) ->
        debug:warning (?MODULE, "non empty accumulator: ~p", [ Value ]),
        error
    end,
  do_parse_back ([], Mode, [ Fun | Acc ]);

do_parse_back ([ $- ], hold = Mode, Acc) ->
  % { X, Y } -> { X, XY }
  Fun = fun (Word, Value) -> { Word, Word ++ Value } end,
  do_parse_back ([], Mode, [ Fun | Acc ]);

do_parse_back ([ $- ], rift = Mode, Acc) ->
  % { X, Y } -> { [], XY }
  Fun = fun (Word, Value) -> { [], Word ++ Value } end,
  do_parse_back ([], Mode, [ Fun | Acc ]);

do_parse_back ([ $- | Tail ], _Mode, Acc) ->
  do_parse_back (Tail, hold, Acc);

do_parse_back ([ Char0 | Tail ], rift = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { Xc, Y } -> { X, cY }
  Fun =
    fun
      ([], _Value) -> false;
      (Word, Value) ->
        case lists:last (Word) == Char0 of
          true  -> { lists:droplast (Word), [ Char0 | Value ] };
          false -> false
        end
    end,
  do_parse_back (Tail, Mode, [ Fun | Acc ]);

do_parse_back ([ Char0 | Tail ], hold = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { Xc, Y } -> { Xc, cY }
  Fun =
    fun
      ([], _Value) -> false;
      (Word, Value) ->
        case lists:last (Word) == Char0 of
          true  -> { Word, [ Char0 | Value ] };
          false -> false
        end
    end,
  do_parse_back (Tail, Mode, [ Fun | Acc ]);

do_parse_back (Rule, Mode, Acc) when Mode == hold orelse Mode == rift ->
  % { X?, Y } -> { X?, ?Y }
  % { X?, Y } -> { X, ?Y }
  AlphabetFilter =
    fun (#entity { name = Name, type = Type, tag = Tag }) ->
      Pos = length (Rule) - length (Tag) + 1,
      case string:rstr (Rule, Tag) of
        Pos when Type == ?ET_ALPHABET -> { true, { Name, length (Tag) } };
        _ -> false
      end
    end,
  case lists:filtermap (AlphabetFilter, model:get_entities ()) of
    [] ->
      debug:warning (?MODULE, "unknown mask ~p", [ Rule ]),
      error;
    [ { Alphabet, WildcardLen } ] ->
      Phonemes = model:get_properties (Alphabet), 
      Fun =
        fun
          (Word, Value) ->
            PhonemesFilter =
              fun (#property { name = Phoneme }) ->
                Pos = length (Word) - length (Phoneme) + 1,
                case string:rstr (Word, Phoneme) of
                  Pos -> { true, Phoneme };
                  _ -> false
                end
              end,
            case lists:filtermap (PhonemesFilter, Phonemes) of
              [] -> false;
              [ Phoneme ] ->
                case Mode of
                  hold -> { Word, Phoneme ++ Value };
                  rift ->
                    Length = length (Word) - length (Phoneme),
                    { string:substr (Word, 1, Length), Phoneme ++ Value }
                end;
              _ ->
                debug:warning (?MODULE, "property ambiguity for word ~p", [ Word ]),
                error
            end
        end,
      do_parse_back (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    _ ->
      debug:warning (?MODULE, "ambiguity mask for rule ~p", [ Rule ]),
      error
  end;

do_parse_back (Rule, none, _Acc) ->
  debug:warning (?MODULE, "expected mode '+' or '-' for rule ~p", [ Rule ]),
  error.
