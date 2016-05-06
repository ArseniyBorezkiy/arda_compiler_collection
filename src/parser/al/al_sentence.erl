%% @doc Sentence compiler.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_sentence).

%
% api
%

-export ([
          compile/1
        ]).

%
% headers
%

-include ("general.hrl").
-include ("l-model.hrl").
-include ("l-token.hrl").
-include ("l-output.hrl").

% =============================================================================
% API
% =============================================================================

compile (Options) ->
  % store flags
  Store = fun ({ K, V }) -> erlang:put (K, V) end,
  lists:foreach (Store, Options),
  % setting up lexer
  acc_lexer:load_token (" ",  ?TT_SEPARATOR),
  acc_lexer:load_token ("\r", ?TT_SEPARATOR),
  acc_lexer:load_token ("\n", ?TT_SEPARATOR),
  acc_lexer:load_token (",",  ?TT_BREAK),
  acc_lexer:load_token (".",  ?TT_BREAK),
  acc_lexer:load_token ("!",  ?TT_BREAK),
  acc_lexer:load_token (";",  ?TT_BREAK),
  acc_lexer:load_token ("?",  ?TT_BREAK),
  acc_lexer:load_token ("/*", ?TT_COMMENT_BEGIN),
  acc_lexer:load_token ("*/", ?TT_COMMENT_END),
  % start parsing
  Words   = loop ([], 0),
  Output  =
    case erlang:get (short) of
      true  -> format_short (Words, []);
      false -> format_long (Words, [])
    end,
  acc_lexer:save (Output),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

loop (Words, Level) ->
  case acc_lexer:next_token () of
    { ?TT_EOT, "" } ->
      case Level of
        0 -> lists:reverse (Words);
        _ ->
          ?d_result (?str_lsentence_ueotbcend),
          throw (error)
      end;
    { ?TT_DEFAULT, Token } when Level == 0 ->
      Word = al_word:parse (Token),
      loop ([ { Token, Word } | Words ], Level);
    { ?TT_BREAK, Token } when Level == 0 ->
      Word = al_word:parse (Token),
      loop ([ { Token, Word } | Words ], Level);
    { ?TT_COMMENT_BEGIN, _ } ->
      loop (Words, Level + 1);
    { ?TT_COMMENT_END, _ } ->
      case Level of
        0 ->
          ?d_result (?str_lsentence_ucend),
          throw (error);
        _ ->
          loop (Words, Level - 1)
      end;
    _ when Level > 0 ->
      loop (Words, Level)
  end.

%
% verbose output format
%

format_long ([], Acc) -> Acc;
format_long ([ { Target, Words } | Tail ], Text) ->
  Lucky = erlang:get (lucky),
  Subwords =
    case Lucky of
      false -> Words;
      true  ->
        Length = length (Words),
        Random = random:uniform (Length),
        [ lists:nth (Random, Words) ]
    end,
  Subtext = do_format_long (Subwords, ""),
  NewText = acc_debug:sprintf ("~s~s {~n~s}~n", [ Text, Target, Subtext ]),
  format_long (Tail, NewText).

do_format_long ([], Acc) -> Acc;
do_format_long ([ #gas_entry { k = #word_k { oid        = Oid },
                               v = #word_v { guards     = Guards,
                                             auxiliary  = Auxiliary,
                                             vocabulars = Vocabulars,
                                             class      = Class } } | Tail ], Acc) ->
  Verbose  = erlang:get (verbose),
  Minimal  = erlang:get (minimal),
  GetAttrs =
    fun
      (#guard_v { name = Name, sign = Sign, base = Base }, Acc0)
        when Name =/= Base, Sign =:= positive ->
        Attribute = al_model:get_entity_value (Base, ?ET_ATTRIBUTE),
        Props     = Attribute#entity_v.properties,
        case proplists:get_value (verbose, Props) of
          true when Verbose == false -> Acc0;
          _ ->
            Members = proplists:get_value (members, Props),
            Desc    = proplists:get_value (Name, Members),
            Acc0 ++
              case Minimal of
                true  ->
                  acc_debug:sprintf ("    ~s /* ~s */~n", [ Name, Desc ]);
                false ->
                  acc_debug:sprintf ("    ~s = ~s /* ~s */~n", [ Base, Name, Desc ])
              end
        end;
      (_, Acc0) -> Acc0
    end,
  GetRoute =
    fun
      ({ aux, Node, Value }, Acc0) ->
        Acc0 ++
          case Value of
            "" -> acc_debug:sprintf ("      /* ~s */~n", [ Node ]);
            _  -> acc_debug:sprintf ("      /* ~s = ~s */~n", [ Node, Value ])
          end;
      ({ voc, Node, Value, Voc }, Acc0) ->
        Acc0 ++ acc_debug:sprintf ("      ~s = ~s /* ~s */~n", [ Node, Value, Voc ])
    end,
  Attrs   = lists:foldl (GetAttrs, "", Guards),
  Trace   = lists:foldl (GetRoute, "", Vocabulars ++ Auxiliary),
  Comment = al_word:format_oid (Oid),
  Format  = "  ~s { /* ~s */~n~s    {~n~s    }~n  }~n",
  Result  = acc_debug:sprintf (Format, [ Class, Comment, Attrs, Trace ]),
  do_format_long (Tail, Acc ++ Result).

%
% acc oriented output format
%

format_short ([], Acc) -> Acc;
format_short ([ { Target, Words } | Tail ], Text) ->
  Lucky = erlang:get (lucky),
  Subwords =
    case Lucky of
      false -> Words;
      true  ->
        Length = length (Words),
        Random = random:uniform (Length),
        [ lists:nth (Random, Words) ]
    end,
  Subtext = do_format_short (Subwords, ""),
  NewText = acc_debug:sprintf ("~s~s {~n~s}~n", [ Text, Target, Subtext ]),
  format_short (Tail, NewText).

do_format_short ([], Acc) -> Acc;
do_format_short ([ #gas_entry { k = #word_k { oid       = Oid },
                               v = #word_v { guards     = Guards,
                                             vocabulars = Vocabulars,
                                             class      = Class } } | Tail ], Acc) ->
  Verbose  = erlang:get (verbose),
  Minimal  = erlang:get (minimal),
  GetAttrs =
    fun
      (#guard_v { name = Name, sign = Sign, base = Base }, Acc0)
        when Name =/= Base, Sign =:= positive ->
        Attribute = al_model:get_entity_value (Base, ?ET_ATTRIBUTE),
        Props     = Attribute#entity_v.properties,
        case proplists:get_value (verbose, Props) of
          true when Verbose == false -> Acc0;
          _ ->
            Acc0 ++
              case Minimal of
                true  ->
                  acc_debug:sprintf (" ~s", [ Name ]);
                false ->
                  acc_debug:sprintf ("    ~s = ~s~n", [ Base, Name ])
              end
        end;
      (_, Acc0) -> Acc0
    end,
  Comparator =
    fun
      (#guard_v { name = Name1, base = Base1 },
       #guard_v { name = Name2, base = Base2 })
        when Name1 =:= Base1 orelse Name2 =:= Base2 ->
        false;
      (#guard_v { base = Base1 },
       #guard_v { base = Base2 }) ->
        Attr1 = al_model:get_entity_value (Base1, ?ET_ATTRIBUTE),
        Attr2 = al_model:get_entity_value (Base2, ?ET_ATTRIBUTE),
        Pos1  = proplists:get_value (ordinal, Attr1#entity_v.properties),
        Pos2  = proplists:get_value (ordinal, Attr2#entity_v.properties),
        Pos1 =< Pos2
    end,
  Attrs    = lists:foldl (GetAttrs, "", lists:sort (Comparator, Guards)),
  GetRoute =
    fun
      ({ voc, Node, Value, _Voc }, Acc0) ->
        Acc0 ++
          case Minimal of
            true  -> acc_debug:sprintf (" ~s = ~s", [ Node, Value ]);
            false -> acc_debug:sprintf ("      ~s = ~s~n", [ Node, Value ])
          end
    end,
  Trace  = lists:foldl (GetRoute, "", Vocabulars),
  Format =
    case Minimal of
      true  -> "  ~s {~s {~s } }~n";
      false -> "  ~s {~n~s    {~n~s    }~n  }~n"
    end,
  Result = acc_debug:sprintf (Format, [ Class, Attrs, Trace ]),
  do_format_short (Tail, Acc ++ Result).
