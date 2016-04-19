%% Match expression analyzer.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (rule).

% API
-export ([
          parse_forward/1,
          parse_backward/1,
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

parse_backward (Rule) ->
  case do_parse_backward (Rule, none, []) of
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

do_parse_forward ([ $= | Tail ], _Mode, Acc) ->
  % { X, Y } -> { X, Y }
  Fun = fun (Word, Value) -> { Word, Value } end,
  do_parse_forward (Tail, skip, [ Fun | Acc ]);

do_parse_forward ([ $+ ], none = Mode, Acc) ->
  % { X, [] } -> { X, [] }
  Fun =
    fun
      (Word, []) -> { Word, [] };
      (_, Value) ->
        debug:warning (?MODULE, "non empty accumulator: ~p", [ Value ]),
        error
    end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

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

do_parse_forward ([ Char0 | Tail ], skip = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { cX, Y } -> { cX, Y }
  Fun =
    fun
      ([ Char | Word ], Value) when Char == Char0 ->
        { [ Char | Word ], Value };
      (_, _) -> false
    end,
  do_parse_forward (Tail, Mode, [ Fun | Acc ]);

do_parse_forward (Rule, Mode, Acc) when Mode == hold; Mode == rift; Mode == skip ->
  % { ?X, Y } -> { ?X, Y? }
  % { ?X, Y } -> { X, Y? }
  AlphabetFilter =
    fun
      (#entity { name = Name, type = Type, tag = Tag })
        when Type == ?ET_ALPHABET orelse Type == ?ET_MUTATION ->
        Wildcard = proplists:get_value (wildcard, Tag),
        case string:str (Rule, Wildcard) of
          1 when Type == ?ET_ALPHABET -> { true, { alphabet, Name, length (Wildcard) } };
          1 when Type == ?ET_MUTATION -> { true, { mutation, Name, length (Wildcard) } };
          _ -> false
        end;
       (_) -> false
    end,
  Genealogist =
    fun (#entity { tag = Tag }) ->
      case proplists:get_value (base, Tag) of
        undefined -> false;
        NextNames -> { true, NextNames }
      end
    end,
  case lists:filtermap (AlphabetFilter, model:get_entities ()) of
    [] ->
      debug:warning (?MODULE, "unknown mask ~p", [ Rule ]),
      error;
    [ { alphabet, Alphabet, WildcardLen } ] ->
      Phonemes = model:get_recursive_properties ([ Alphabet ], Genealogist), 
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
            Unsorted = lists:filtermap (PhonemesFilter, Phonemes),
            Sort = fun (PS1, PS2) -> length (PS1) > length (PS2) end,
            case lists:sort (Sort, Unsorted) of
              [] -> false;
              [ Phoneme ] ->
                case Mode of
                  skip -> { Word, Value };
                  hold -> { Word, Value ++ Phoneme };
                  rift -> { lists:nthtail (length (Phoneme), Word), Value ++ Phoneme }
                end
            end
        end,
      do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    [ { mutation, Mutation, WildcardLen } ] ->
      Maps = model:get_recursive_properties ([ Mutation ], Genealogist), 
      Fun =
        fun
          (Word, Value) ->
            MapFilter =
              fun (#property { name = ?UP_MUTATION (PhonemeSrc), value = PhonemeDst }) ->
                case string:str (Word, PhonemeSrc) of
                  1 -> { true, { PhonemeSrc, PhonemeDst } };
                  _ -> false
                end
              end,
            Unsorted = lists:filtermap (MapFilter, Maps),
            Sort = fun ({ PS1, _ }, { PS2, _ }) -> length (PS1) > length (PS2) end,
            case lists:sort (Sort, Unsorted) of
              [] -> false;
              [ { PhonemeSrc, PhonemeDst } | _ ] ->
                case Mode of
                  skip -> { Word, Value };
                  hold -> { PhonemeDst ++ lists:nthtail (length (PhonemeSrc), Word), Value ++ PhonemeDst };
                  rift -> { lists:nthtail (length (PhonemeSrc), Word), Value ++ PhonemeDst }
                end
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

do_parse_backward ([], _Mode, Acc) ->
  Acc;

do_parse_backward ([ $= | Tail ], _Mode, Acc) ->
  % { X, Y } -> { X, Y }
  Fun = fun (Word, Value) -> { Word, Value } end,
  do_parse_backward (Tail, skip, [ Fun | Acc ]);

do_parse_backward ([ $+ ], none = Mode, Acc) ->
  % { X, [] } -> { X, [] }
  Fun =
    fun
      (Word, []) -> { Word, [] };
      (_, Value) ->
        debug:warning (?MODULE, "non empty accumulator: ~p", [ Value ]),
        error
    end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $+ | Tail ], _Mode, Acc) ->
  do_parse_backward (Tail, rift, Acc);

do_parse_backward ([ $- ], none = Mode, Acc) ->
  % { X, [] } -> { X, X }
  Fun =
    fun
      (Word, []) -> { Word, Word };
      (_, Value) ->
        debug:warning (?MODULE, "non empty accumulator: ~p", [ Value ]),
        error
    end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $- ], hold = Mode, Acc) ->
  % { X, Y } -> { X, XY }
  Fun = fun (Word, Value) -> { Word, Word ++ Value } end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $- ], rift = Mode, Acc) ->
  % { X, Y } -> { [], XY }
  Fun = fun (Word, Value) -> { [], Word ++ Value } end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $- | Tail ], _Mode, Acc) ->
  do_parse_backward (Tail, hold, Acc);

do_parse_backward ([ Char0 | Tail ], rift = Mode, Acc)
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
  do_parse_backward (Tail, Mode, [ Fun | Acc ]);

do_parse_backward ([ Char0 | Tail ], hold = Mode, Acc)
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
  do_parse_backward (Tail, Mode, [ Fun | Acc ]);

do_parse_backward ([ Char0 | Tail ], skip = Mode, Acc)
  when Char0 >= $a, Char0 =< $z ->
  % { Xc, Y } -> { Xc, Y }
  Fun =
    fun
      ([], _Value) -> false;
      (Word, Value) ->
        case lists:last (Word) == Char0 of
          true  -> { Word, Value };
          false -> false
        end
    end,
  do_parse_backward (Tail, Mode, [ Fun | Acc ]);

do_parse_backward (Rule, Mode, Acc) when Mode == hold; Mode == rift; Mode == skip ->
  % { X?, Y } -> { X?, ?Y }
  % { X?, Y } -> { X, ?Y }
  AlphabetFilter =
    fun
      (#entity { name = Name, type = Type, tag = Tag })
        when Type == ?ET_ALPHABET orelse Type == ?ET_MUTATION ->
        Wildcard = proplists:get_value (wildcard, Tag),
        case string:rstr (Rule, Wildcard) of
          1 when Type == ?ET_ALPHABET -> { true, { alphabet, Name, length (Wildcard) } };
          1 when Type == ?ET_MUTATION -> { true, { mutation, Name, length (Wildcard) } };
          _ -> false
        end;
      (_) -> false
    end,
  Genealogist =
    fun (#entity { tag = Tag }) ->
      case proplists:get_value (base, Tag) of
        undefined -> false;
        NextNames -> { true, NextNames }
      end
    end,
  case lists:filtermap (AlphabetFilter, model:get_entities ()) of
    [] ->
      debug:warning (?MODULE, "unknown mask ~p", [ Rule ]),
      error;
    [ { alphabet, Alphabet, WildcardLen } ] ->
      Phonemes = model:get_recursive_properties ([ Alphabet ], Genealogist), 
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
            Unsorted = lists:filtermap (PhonemesFilter, Phonemes),
            Sort = fun (PS1, PS2) -> length (PS1) > length (PS2) end,
            case lists:sort (Sort, Unsorted) of
              [] -> false;
              [ Phoneme | _ ] ->
                case Mode of
                  skip -> { Word, Value };
                  hold -> { Word, Phoneme ++ Value };
                  rift ->
                    Length = length (Word) - length (Phoneme),
                    { string:substr (Word, 1, Length), Phoneme ++ Value }
                end
            end
        end,
      do_parse_backward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    [ { mutation, Mutation, WildcardLen } ] ->
      Maps = model:get_recursive_properties ([ Mutation ], Genealogist),
      Fun =
        fun
          (Word, Value) ->
            MapFilter =
              fun (#property { name = ?UP_MUTATION (PhonemeSrc), value = PhonemeDst }) ->
                Pos = length (Word) - length (PhonemeSrc) + 1,
                case string:rstr (Word, PhonemeSrc) of
                  Pos -> { true, { PhonemeSrc, PhonemeDst } };
                  _ -> false
                end
              end,
            Unsorted = lists:filtermap (MapFilter, Maps),
            Sort = fun ({ PS1, _ }, { PS2, _ }) -> length (PS1) > length (PS2) end,
            case lists:sort (Sort, Unsorted) of
              [] -> false;
              [ { PhonemeSrc, PhonemeDst } | _ ] ->
                case Mode of
                  skip -> { Word, Value };
                  hold ->
                    Length = length (Word) - length (PhonemeSrc),
                    { string:substr (Word, 1, Length) ++ PhonemeDst, PhonemeDst ++ Value };
                  rift ->
                    Length = length (Word) - length (PhonemeSrc),
                    { string:substr (Word, 1, Length), PhonemeDst ++ Value }
                end
            end
        end,
      do_parse_backward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    _ ->
      debug:warning (?MODULE, "ambiguity mask for rule ~p", [ Rule ]),
      error
  end;

do_parse_backward (Rule, none, _Acc) ->
  debug:warning (?MODULE, "expected mode '+' or '-' for rule ~p", [ Rule ]),
  error.
