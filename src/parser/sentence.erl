%% Sentence compiler.
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (sentence).

% API
-export ([
          compile/1
        ]).

% HEADERS
-include ("general.hrl").
-include ("model.hrl").
-include ("token.hrl").
-include ("output.hrl").

% =============================================================================
% API
% =============================================================================

compile (Options) ->
  % store flags
  Store = fun ({ K, V }) -> erlang:put (K, V) end,
  lists:foreach (Store, Options),
  % setting up lexer
  lexer:load_token (" ",  ?TT_SEPARATOR),
  lexer:load_token ("\r", ?TT_SEPARATOR),
  lexer:load_token ("\n", ?TT_SEPARATOR),
  lexer:load_token (",",  ?TT_BREAK),
  lexer:load_token (".",  ?TT_BREAK),
  lexer:load_token ("!",  ?TT_BREAK),
  lexer:load_token (";",  ?TT_BREAK),
  lexer:load_token ("?",  ?TT_BREAK),
  lexer:load_token ("/*", ?TT_COMMENT_BEGIN),
  lexer:load_token ("*/", ?TT_COMMENT_END),
  % start parsing
  Words   = loop ([], 0),
  Output  =
    case erlang:get (short) of
      true  -> format_short (Words, []);
      false -> format_long (Words, [])
    end,
  lexer:save (Output),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

loop (Words, Level) ->
  case lexer:next_token () of
    { ?TT_EOT, "" } ->
      case Level of
        0 -> lists:reverse (Words);
        _ ->
          debug:result (?MODULE, "expected end of the comment instead of eot"),
          throw (error)
      end;
    { ?TT_DEFAULT, Token } when Level == 0 ->
      Word = word:parse (Token),
      loop ([ { Token, Word } | Words ], Level);
    { ?TT_BREAK, Token } when Level == 0 ->
      Word = word:parse (Token),
      loop ([ { Token, Word } | Words ], Level);
    { ?TT_COMMENT_BEGIN, _ } ->
      loop (Words, Level + 1);
    { ?TT_COMMENT_END, _ } ->
      case Level of
        0 ->
          debug:result (?MODULE, "unexpected end of the comment"),
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
  NewText = debug:sprintf ("~s~s {~n~s}~n", [ Text, Target, Subtext ]),
  format_long (Tail, NewText).

do_format_long ([], Acc) -> Acc;
do_format_long ([ #word { oid = OID, guards = Guards, route = Route, stem = Stem, class = Class } | Tail ], Acc) ->
  Verbose = erlang:get (verbose),
  Minimal = erlang:get (minimal),
  GetAttributes =
    fun
      ({ Name, false }, Acc0) ->
        Property = model:get_property (Name),
        # property { name = Name, value = Value, entity = Entity } = Property,
        Attribute = model:get_entity (Entity),
        case proplists:get_value (verbose, Attribute#entity.tag) of
          true when Verbose == false -> Acc0;
          _ -> Acc0 ++
            case Minimal of
              true  -> debug:sprintf ("    ~s /* ~s */~n", [ Name, Value ]);
              false -> debug:sprintf ("    ~s = ~s /* ~s */~n", [ Entity, Name, Value ])
            end
        end;
      ({ _Name, true }, Acc0) -> Acc0
    end,
  GetRoute =
    fun ({ Match, Value }, Acc0) ->
      Acc0 ++ debug:sprintf ("      ~s = ~s~n", [ Match, Value ])
    end,
  Attributes = lists:foldl (GetAttributes, "", Guards),
  Trace      = lists:foldl (GetRoute, "", Route),
  Comment    = word:format_oid (OID),
  Format     = "  ~s ~s { /* ~s */~n~s    /*~n~s    */~n  }~n",
  Result     = debug:sprintf (Format, [ Stem, Class, Comment, Attributes, Trace ]),
  do_format_long (Tail, Acc ++ Result).

%
% as oriented output format
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
  NewText = debug:sprintf ("~s~s {~n~s}~n", [ Text, Target, Subtext ]),
  format_short (Tail, NewText).

do_format_short ([], Acc) -> Acc;
do_format_short ([ #word { guards = Guards, stem = Stem, class = Class } | Tail ], Acc) ->
  Verbose = erlang:get (verbose),
  Minimal = erlang:get (minimal),
  GetAttributes =
    fun
      ({ Name, false }, Acc0) ->
        Property = model:get_property (Name),
        # property { name = Name, entity = Entity } = Property,
        Attribute = model:get_entity (Entity),
        case proplists:get_value (verbose, Attribute#entity.tag) of
          true when Verbose == false -> Acc0;
          _ -> Acc0 ++
            case Minimal of
              true  -> debug:sprintf (" ~s", [ Name ]);
              false -> debug:sprintf ("    ~s = ~s~n", [ Entity, Name ])
            end
        end;
      ({ _Name, true }, Acc0) -> Acc0
    end,
  Sort =
    fun ({ Name1, _ }, { Name2, _ }) ->
      Property1  = model:get_property (Name1),
      Property2  = model:get_property (Name2),
      Entity1    = Property1#property.entity,
      Entity2    = Property2#property.entity,
      Attribute1 = model:get_entity (Entity1),
      Attribute2 = model:get_entity (Entity2),
      Order1     = proplists:get_value (ordinal, Attribute1#entity.tag),
      Order2     = proplists:get_value (ordinal, Attribute2#entity.tag),
      Order1 =< Order2
    end,
  Attributes = lists:foldl (GetAttributes, "", lists:sort (Sort, Guards)),
  Format     =
    case Minimal of
      true  -> "  ~s ~s {~s }~n";
      false -> "  ~s ~s {~n~s  }~n"
    end,
  Result     = debug:sprintf (Format, [ Stem, Class, Attributes ]),
  do_format_short (Tail, Acc ++ Result).