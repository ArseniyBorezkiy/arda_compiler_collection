%% Sentence compiler.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (sentence).

% API
-export ([
          compile/0
        ]).

% WORD DESCRIPTION
-record (attribute, { name  :: string (),
                      value :: string () }).

-type attribute_t () :: # attribute { }.

-record (word, { class      :: string (),
                 attributes :: list (attribute_t ()) }).

% =============================================================================
% API
% =============================================================================

compile () ->
  % setting up lexer
  lexer:load_token (" ",    separator),
  lexer:load_token ("\r\n", separator),
  lexer:load_token (",",    separator),
  lexer:load_token (".",    separator),
  lexer:load_token ("!",    separator),
  % start parsing
  Tokens = lexer:get_all_tokens (),
  Words  = loop (Tokens, []),
  Output = format (Words, []),
  lexer:save (Output),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

loop ([], Acc) -> Acc;
loop ([ { default, Token } | Tail ], Acc) ->
  % simple word
  Word = # word { },
  loop (Tail, [ Word, Acc ]).

format ([], Acc) -> Acc;
format ([ # word { class = Class, attributes = AttrList } | Tail ], Acc) ->
  Fun =
    fun (# attribute { name = Name, value = Value }, Acc0) ->
      Acc0 ++ lists:flatten (io_lib:format ("~s = ~s~n", [ Name, Value ]))
    end,
  Attributes = lists:foldl (Fun, "", AttrList),
  Result = lists:flatten (io_lib:format ("~s {~n~s}", [ Class, Attributes ])),
  format (Tail, Acc ++ Result).
