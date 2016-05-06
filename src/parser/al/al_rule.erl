%% @doc Match expression analyzer.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_rule).

%
% api
%

-export ([
          parse_forward/1,
          parse_backward/1,
          match/2,
          get_starts_with/1
        ]).

%
% headers
%

-include ("general.hrl").
-include ("l-model.hrl").

% =============================================================================
% API
% =============================================================================

parse_forward (Rule) ->
  do_parse_forward (Rule, none, []).

parse_backward (Rule) ->
  do_parse_backward (Rule, none, []).

match (Word, Filters) ->
  PosBeg = 1,
  do_match (Filters, Word, PosBeg, []).

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

do_match ([], Word, _Pos, Acc) -> { true, Word, Acc };
do_match ([ { ?ET_EOW, Filter } | Tail ], Word1, Pos1, Acc1) ->
  case Filter (Word1, Acc1, Pos1) of
    error -> throw (?e_error);
    false -> false;
    { Word2, Acc2, Pos2 } ->
      do_match (Tail, Word2, Pos2, Acc2)
  end;
do_match ([ Filter | Tail ], Word1, Pos1, Acc1) ->
  case Pos1 > length (Word1) of
    true  -> false;
    false -> do_match ([ { ?ET_EOW, Filter } | Tail ], Word1, Pos1, Acc1)
  end.

%
% forward rule parser
%

do_parse_forward ([], _Mode, Acc) ->
  lists:reverse (Acc);

do_parse_forward ([ $= ], Mode, Acc) ->
  % { W, V, P } -> { W, V, End }
  Fun = fun (W, V, _P) -> { W, V, 1 + length (W) } end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

do_parse_forward ([ $= | Tail ], _Mode, Acc) ->
  do_parse_forward (Tail, skip, Acc);

do_parse_forward ([ $+ ], Mode, Acc) ->
  % { W, V, P } -> { W\Wp, VWp, End }
  Fun =
    fun (W, V, P) ->
      Wb = string:substr (W, 1, P - 1),
      Wp = string:substr (W, P),
      { Wb, V ++ Wp, 1 + length (Wb) }
    end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

do_parse_forward ([ $+ | Tail ], _Mode, Acc) ->
  do_parse_forward (Tail, rift, Acc);

do_parse_forward ([ $- ], Mode, Acc) ->
  % { W, V, P } -> { W, VWp, P + length (Wp) }
  Fun =
    fun (W, V, P) ->
      Wp = string:substr (W, P),
      { W, V ++ Wp, P + length (Wp) }
    end,
  do_parse_forward ([], Mode, [ Fun | Acc ]);

do_parse_forward ([ $- | Tail ], _Mode, Acc) ->
  do_parse_forward (Tail, hold, Acc);

do_parse_forward ([ $~, Ch | Tail ], Mode, Acc) ->
  Nequ = fun (Ch1, Ch2) -> Ch1 =/= Ch2 end,
  do_parse_forward ([ { Nequ }, Ch | Tail ], Mode, Acc);
  
do_parse_forward ([ { Cmp }, Ch | Tail ], rift = Mode, Acc)
  when Ch >= $a, Ch =< $z ->
  % { cW, V, P } -> { W, Vc, P }
  Fun =
    fun (W, V, P) ->
      Wb = string:substr (W, 1, P - 1),
      Wp = string:substr (W, P),
      case Wp of
        [ Ch0 | We ] ->
          case Cmp (Ch, Ch0) of
            true  -> { Wb ++ We, V ++ [ Ch0 ], P };
            false -> false
          end;
        _ -> false
      end
    end,
  do_parse_forward (Tail, Mode, [ Fun | Acc ]);

do_parse_forward ([ { Cmp }, Ch | Tail ], hold = Mode, Acc)
  when Ch >= $a, Ch =< $z ->
  % { cW, V, P } -> { cW, Vc, P + 1 }
  Fun =
    fun (W, V, P) ->
      Wp = string:substr (W, P),
      case Wp of
        [ Ch0 | _ ] ->
          case Cmp (Ch, Ch0) of
            true  -> { W, V ++ [ Ch0 ], P + 1 };
            false -> false
          end;
        _ -> false
      end
    end,
  do_parse_forward (Tail, Mode, [ Fun | Acc ]);

do_parse_forward ([ { Cmp }, Ch | Tail ], skip = Mode, Acc)
  when Ch >= $a, Ch =< $z ->
  % { cW, V, P } -> { cW, V, P + 1 }
  Fun =
    fun (W, V, P) ->
      Wp = string:substr (W, P),
      case Wp of
        [ Ch0 | _ ] ->
          case Cmp (Ch, Ch0) of
            true  -> { W, V, P + 1 };
            false -> false
          end;
        _ -> false
      end
    end,
  do_parse_forward (Tail, Mode, [ Fun | Acc ]);

do_parse_forward ([ { Cmp } | Rule ], Mode, Acc)
  when Mode == skip; Mode == hold; Mode == rift ->
  % { ?X, Y, P } -> { ?X, Y, P + length (?) }
  % { ?X, Y, P } -> { ?X, Y?, P + length (?) }
  % { ?X, Y, P } -> { X, Y?, P }
  case get_starts_with (Rule) of
    { ?ET_ALPHABET = Type, Alphabet, WildcardLen } ->
      Phonemes = al_model:get_recursive_properties (Alphabet, Type, members),
      Fun =
        fun (W, V, P) ->
          Wp = string:substr (W, P),
          Filter =
            fun
              ({ Ph, _ }) when length (Ph) > 0 ->
                case Cmp (true, true) of
                  true ->
                    case string:str (Wp, Ph) of
                      1 -> { true, Ph };
                      _ -> false
                    end;
                  false ->
                    case string:str (Wp, Ph) of
                      1 -> false;
                      _ -> { true, Ph }
                    end
                end;
              ({ _, _ }) -> Cmp (true, true)
            end,
          Sort = fun (Ph1, Ph2) -> length (Ph1) > length (Ph2) end,
          case lists:sort (Sort, lists:filtermap (Filter, Phonemes)) of
            [] -> false;
            [ Ph | _ ] ->
              case Mode of
                skip ->
                  { W, V, P + length (Ph) };
                hold -> { W, V ++ Ph, P + length (Ph) };
                rift ->
                  Wb = string:substr (W, 1, P - 1),
                  We = lists:nthtail (length (Ph), Wp),
                  { Wb ++ We, V ++ Ph, P }
              end
          end
        end,
      do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    { ?ET_MUTATION = Type, Mutation, WildcardLen } ->
      case Cmp (true, true) of
        true ->
          Maps = al_model:get_recursive_properties (Mutation, Type, members),
          Fun  =
            fun (W, V, P) ->
              Filter =
                fun
                  ({ PhSrc, _ }) when length (PhSrc) > 0 ->
                    case string:str (W, PhSrc) of
                      1 -> true;
                      _ -> false
                    end;
                  ({ _, _ }) -> true
                end,
              Sort = fun ({ Ph1, _ }, { Ph2, _ }) -> length (Ph1) > length (Ph2) end,
              case lists:sort (Sort, lists:filter (Filter, Maps)) of
                [] -> false;
                [ { PhSrc, PhDst } | _ ] ->
                  PhSrcLen = length (PhSrc),
                  PhDstLen = length (PhDst),
                  Wt = lists:nthtail (PhSrcLen, W),
                  case Mode of
                    skip -> { PhDst ++ Wt, V, P - PhSrcLen + PhDstLen };
                    hold -> { PhDst ++ Wt, V ++ PhDst, P - PhSrcLen + PhDstLen };
                    rift -> { Wt, V ++ PhDst, P - PhSrcLen }
                  end
              end
            end,
          do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
        false ->
          ?d_warning (?str_lrule_umne (Rule)),
          throw (?e_error)
      end;
    { ?ET_REFLECTION = Type, Mutation, WildcardLen } ->
      case Cmp (true, true) of
        true ->
          Maps = al_model:get_recursive_properties (Mutation, Type, members),
          Fun  =
            fun (W, V, P) ->
              Wb = string:substr (W, 1, P - 1),
              Wp = string:substr (W, P),
              Filter =
                fun
                  ({ PhSrc, _ }) when length (PhSrc) > 0 ->
                    case string:str (Wp, PhSrc) of
                      1 -> true;
                      _ -> false
                    end;
                  ({ _, _ }) -> true
                end,
              Sort = fun ({ Ph1, _ }, { Ph2, _ }) -> length (Ph1) > length (Ph2) end,
              case lists:sort (Sort, lists:filter (Filter, Maps)) of
                [] -> false;
                [ { PhSrc, PhDst } | _ ] ->
                  PhSrcLen = length (PhSrc),
                  PhDstLen = length (PhDst),
                  Wt = lists:nthtail (PhSrcLen, Wp),
                  case Mode of
                    skip -> { Wb ++ PhDst ++ Wt, V, P - PhSrcLen + PhDstLen };
                    hold -> { Wb ++ PhDst ++ Wt, V ++ PhDst, P - PhSrcLen + PhDstLen };
                    rift -> { Wb ++ Wt, V ++ PhDst, P - PhSrcLen }
                  end
              end
            end,
          do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
        false ->
          ?d_warning (?str_lrule_umne (Rule)),
          throw (?e_error)
      end;
    { ?ET_EOW, _, WildcardLen } ->
      Fun =
        fun (W, V, P) ->
          case P > length (W) of
            true -> { W, V, P };
            false -> false
          end
        end,
      do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ { ?ET_EOW, Fun } | Acc ]);
    { ?ET_STATE, { Action, State }, WildcardLen } ->
      Fun =
        case Action of
          load ->
            fun (_W, V, _P) ->
              { W0, P0 } = erlang:get ({ state, State }),
              { W0, V, P0 }
            end;
          save ->
            fun (W, V, P) ->
              erlang:put ({ state, State }, { W, P }),
              { W, V, P }
            end
        end,
      do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    error ->
      ?d_warning (?str_lrule_uwildcard (Rule)),
      throw (?e_error)
  end;

do_parse_forward ([ { _ } | Rule ], none, _Acc) ->
  ?d_warning (?str_lrule_efmode (Rule)),
  throw (?e_error);

do_parse_forward ([ Ch | Tail ], Mode, Acc) ->
  Equ = fun (Ch1, Ch2) -> Ch1 =:= Ch2 end,
  do_parse_forward ([ { Equ }, Ch | Tail ], Mode, Acc).

%
% backward rule parser
%

do_parse_backward ([], _Mode, Acc) ->
  Acc;

do_parse_backward ([ $= ], Mode, Acc) ->
  % { W, V, P } -> { W, V, End }
  Fun = fun (W, V, _P) -> { W, V, 1 + length (W) } end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $= | Tail ], _Mode, Acc) ->
  do_parse_backward (Tail, skip, Acc);

do_parse_backward ([ $+ ], Mode, Acc) ->
  % { W, V, P } -> { W\Wp, WpV, End }
  Fun =
    fun (W, V, P) ->
      Pn = length (W) - P + 1,
      Wb = string:substr (W, Pn + 1),
      Wp = string:substr (W, 1, Pn),
      { Wb, Wp ++ V, 1 + length (Wb) }
    end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $+ | Tail ], _Mode, Acc) ->
  do_parse_backward (Tail, rift, Acc);

do_parse_backward ([ $- ], Mode, Acc) ->
  % { W, V, P } -> { W, WpV, P + length (Wp) }
  Fun =
    fun (W, V, P) ->
      Pn = length (W) - P + 1,
      Wp = string:substr (W, 1, Pn),
      { W, Wp ++ V, P + length (Wp) }
    end,
  do_parse_backward ([], Mode, [ Fun | Acc ]);

do_parse_backward ([ $- | Tail ], _Mode, Acc) ->
  do_parse_backward (Tail, hold, Acc);

do_parse_backward ([ $~, Ch | Tail ], Mode, Acc) ->
  Nequ = fun (Ch1, Ch2) -> Ch1 =/= Ch2 end,
  do_parse_backward ([ { Nequ }, Ch | Tail ], Mode, Acc);

do_parse_backward ([ { Cmp }, Ch | Tail ], rift = Mode, Acc)
  when Ch >= $a, Ch =< $z ->
  % { Wc, V, P } -> { W, cV, P }
  Fun =
    fun (W, V, P) ->
      Pn = length (W) - P + 1,
      Wb = string:substr (W, Pn + 1),
      Wp = string:substr (W, 1, Pn),      
      case Cmp (lists:last (Wp), Ch) of
        true -> { lists:droplast (Wp) ++ Wb, [ Ch | V ], P };
        _ -> false
      end
    end,
  do_parse_backward (Tail, Mode, [ Fun | Acc ]);

do_parse_backward ([ { Cmp }, Ch | Tail ], hold = Mode, Acc)
  when Ch >= $a, Ch =< $z ->
  % { Wc, V, P } -> { Wc, cV, P + 1 }
  Fun =
    fun (W, V, P) ->
      Pn = length (W) - P + 1,
      Wp = string:substr (W, 1, Pn),      
      case Cmp (lists:last (Wp), Ch) of
        true -> { W, [ Ch | V ], P + 1 };
        _ -> false
      end
    end,
  do_parse_backward (Tail, Mode, [ Fun | Acc ]);

do_parse_backward ([ { Cmp }, Ch | Tail ], skip = Mode, Acc)
  when Ch >= $a, Ch =< $z ->
  % { Wc, V, P } -> { Wc, V, P + 1 }
  Fun =
    fun (W, V, P) ->
      Pn = length (W) - P + 1,
      Wp = string:substr (W, 1, Pn),
      case Cmp (lists:last (Wp), Ch) of
        true -> { W, V, P + 1 };
        _ -> false
      end
    end,
  do_parse_backward (Tail, Mode, [ Fun | Acc ]);

do_parse_backward ([ { Cmp } | Rule ], Mode, Acc)
  when Mode == skip; Mode == hold; Mode == rift ->
  % { X?, Y, P } -> { X?, Y, P + length (?) }
  % { X?, Y, P } -> { X?, ?Y, P + length (?) }
  % { X?, Y, P } -> { X, ?Y, P }
  case get_starts_with (Rule) of
    { ?ET_ALPHABET = Type, Alphabet, WildcardLen } ->            
      Phonemes = al_model:get_recursive_properties (Alphabet, Type, members),
      Fun =
        fun (W, V, P) ->
          Pn = length (W) - P + 1,
          Wp = string:substr (W, 1, Pn),
          Filter =
            fun
              ({ Ph, _ }) when length (Ph) > 0 ->
                Pos = length (Wp) - length (Ph) + 1,
                case Cmp (true, true) of
                  true ->
                    case string:rstr (Wp, Ph) of
                      Pos when Pos > 0 -> { true, Ph };
                      _ -> false
                    end;
                  false ->
                    case string:rstr (Wp, Ph) of
                      Pos when Pos > 0 -> false;
                      _ -> { true, Ph }
                    end
                end;
              ({ _, _ }) -> Cmp (true, true)
            end,
          Sort = fun (Ph1, Ph2) -> length (Ph1) > length (Ph2) end,
          case lists:sort (Sort, lists:filtermap (Filter, Phonemes)) of
            [] -> false;
            [ Ph | _ ] ->
              case Mode of
                skip -> { W, V, P + length (Ph) };
                hold -> { W, Ph ++ V, P + length (Ph) };
                rift ->
                  Wb = string:substr (W, Pn + 1),
                  We = lists:sublist (Wp, length (Wp) - length (Ph)),
                  { We ++ Wb, Ph ++ V, P }
              end
          end
        end,
      do_parse_backward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    { ?ET_MUTATION = Type, Mutation, WildcardLen } ->
      case Cmp (true, true) of
        true ->
          Maps = al_model:get_recursive_properties (Mutation, Type, members),
          Fun  =
            fun (W, V, P) ->
              Filter =
                fun
                  ({ PhSrc, _ }) when length (PhSrc) > 0 ->                   
                    Pos = length (W) - length (PhSrc) + 1,
                    case string:rstr (W, PhSrc) of
                      Pos when Pos > 0 -> true;
                      _ -> false
                    end;
                  ({ _, _ }) -> true
                end,
              Sort = fun ({ Ph1, _ }, { Ph2, _ }) -> length (Ph1) > length (Ph2) end,
              case lists:sort (Sort, lists:filter (Filter, Maps)) of
                [] -> false;
                [ { PhSrc, PhDst } | _ ] ->              
                  PhSrcLen = length (PhSrc),
                  PhDstLen = length (PhDst),
                  Wt = lists:sublist (W, length (W) - PhSrcLen),
                  case Mode of
                    skip -> { Wt ++ PhDst, V, P - PhSrcLen + PhDstLen };
                    hold -> { Wt ++ PhDst, PhDst ++ V, P - PhSrcLen + PhDstLen };
                    rift -> { Wt, PhDst ++ V, P - PhSrcLen }
                  end
              end
            end,
          do_parse_backward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
        false ->
          ?d_warning (?str_lrule_umne (Rule)),
          throw (?e_error)
      end;
    { ?ET_REFLECTION = Type, Mutation, WildcardLen } ->
      case Cmp (true, true) of
        true ->
          Maps = al_model:get_recursive_properties (Mutation, Type, members),
          Fun  =
            fun (W, V, P) ->
              Pn = length (W) - P + 1,
              Wp = string:substr (W, 1, Pn),
              Wb = string:substr (W, Pn + 1),
              Filter =
                fun
                  ({ PhSrc, _ }) when length (PhSrc) > 0 ->                   
                    Pos = length (Wp) - length (PhSrc) + 1,
                    case string:rstr (Wp, PhSrc) of
                      Pos when Pos > 0 -> true;
                      _ -> false
                    end;
                  ({ _, _ }) -> true
                end,
              Sort = fun ({ Ph1, _ }, { Ph2, _ }) -> length (Ph1) > length (Ph2) end,
              case lists:sort (Sort, lists:filter (Filter, Maps)) of
                [] -> false;
                [ { PhSrc, PhDst } | _ ] ->              
                  PhSrcLen = length (PhSrc),
                  PhDstLen = length (PhDst),
                  Wt = lists:sublist (Wp, length (W) - PhSrcLen),
                  case Mode of
                    skip -> { Wt ++ PhDst ++ Wb, V, P - PhSrcLen + PhDstLen };
                    hold -> { Wt ++ PhDst ++ Wb, PhDst ++ V, P - PhSrcLen + PhDstLen };
                    rift -> { Wt ++ Wb, PhDst ++ V, P - PhSrcLen }
                  end
              end
            end,
          do_parse_backward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
        false ->
          ?d_warning (?str_lrule_umne (Rule)),
          throw (?e_error)
      end;
    { ?ET_EOW, _, WildcardLen } ->
      Fun =
        fun (W, V, P) ->
          case P > length (W) of
            true -> { W, V, P };
            false -> false
          end
        end,
      do_parse_forward (lists:nthtail (WildcardLen, Rule), Mode, [ { ?ET_EOW, Fun } | Acc ]);
    { ?ET_STATE, { Action, State }, WildcardLen } ->
      Fun =
        case Action of
          load ->
            fun (_W, V, _P) ->
              { W0, P0 } = erlang:get ({ state, State }),
              { W0, V, P0 }
            end;
          save ->
            fun (W, V, P) ->
              erlang:put ({ state, State }, { W, P }),
              { W, V, P }
            end
        end,
      do_parse_backward (lists:nthtail (WildcardLen, Rule), Mode, [ Fun | Acc ]);
    error ->
      ?d_warning (?str_lrule_uwildcard (Rule)),
      throw (?e_error)
  end;

do_parse_backward ([ { _ } | Rule ], none, _Acc) ->
  ?d_warning (?str_lrule_ebmode (Rule)),
  throw (?e_error);

do_parse_backward ([ Ch | Tail ], Mode, Acc) ->
  Equ = fun (Ch1, Ch2) -> Ch1 =:= Ch2 end,
  do_parse_backward ([ { Equ }, Ch | Tail ], Mode, Acc).

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

get_starts_with (Rule) ->
  Filter =
    fun (#gas_entry { k = #entity_k { name = Wildcard },
                      v = #entity_v { properties = Props }}) ->
      Name = proplists:get_value (target_name, Props),
      Type = proplists:get_value (target_type, Props),
      case string:str (Rule, Wildcard) of
        1 -> { true, { Type, Name, length (Wildcard) } };
        _ -> false
      end
    end,
  Entries = al_model:select_entities ('_', ?ET_WILDCARD),
  case lists:filtermap (Filter, Entries) of
    [ Result ] -> Result;
    [] ->
      ?d_warning (?str_lrule_umask (Rule)),
      error;
    _ ->
      ?d_warning (?str_lrule_amask (Rule)),
      error
  end.
