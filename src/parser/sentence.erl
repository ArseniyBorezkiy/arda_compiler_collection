%% Sentence compiler.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (sentence).

% API
-export ([
          compile/0
        ]).

% HEADERS
-include ("general.hrl").
-include ("model.hrl").
-include ("token.hrl").

% =============================================================================
% API
% =============================================================================

compile () ->
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
  Words  = loop ([], 0),
  Output = format (Words, []),
  % lexer:save (Output),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

loop (Words, Level) ->
  case lexer:next_token () of
    { ?TT_EOT, "" } ->
      case Level of
        0 -> Words;
        _ ->
          debug:result (?MODULE, "expected end of the comment instead of eot"),
          throw (error)
      end;
    { ?TT_DEFAULT, Token } when Level == 0 ->
      Word = word:parse (Token),
      loop ([ Word | Words ], Level);
    { ?TT_BREAK, Token } when Level == 0 ->
      Word = word:parse (Token),
      loop ([ Word | Words ], Level);
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

format ([], Acc) -> Acc;
format ([ Properties = _Word | Tail ], Acc) ->
  Fun =
    fun (# property { name = Name, value = Value, entity = Entity }, Acc0) ->
      Acc0 ++ lists:flatten (io_lib:format ("~s = ~s (~s)~n", [ Name, Value, Entity ]))
    end,
  Attributes = lists:foldl (Fun, "", Properties),
  Result = lists:flatten (io_lib:format ("{~n~s}~n", [ Attributes ])),
  format (Tail, Acc ++ Result).
