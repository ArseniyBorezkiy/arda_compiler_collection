%% Grammar reference parser.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (language).

% API
-export ([
          parse/0,
          % states
          main/2,
          attribute/2,
          class/2,
          alphabet/2,
          mutation/2,
          match_rule/2,
          match_guard/2,
          comment/2,
          vocabular_entry/2,
          vocabular_specification/2,
          default/3
        ]).

% HEADERS
-include ("model.hrl").
-include ("token.hrl").

% =============================================================================
% API
% =============================================================================

parse () ->
  % setting up lexer
  lexer:load_token ("\r", ?TT_SEPARATOR),  
  lexer:load_token ("\t", ?TT_SEPARATOR),
  lexer:load_token (" ",  ?TT_SEPARATOR),
  lexer:load_token ("\n", ?TT_BREAK),
  lexer:load_token (".language",   ?TT_SECTION),
  lexer:load_token (".class",      ?TT_SECTION),
  lexer:load_token (".attribute",  ?TT_SECTION),
  lexer:load_token (".match",      ?TT_SECTION),
  lexer:load_token (".alphabet",   ?TT_SECTION),
  lexer:load_token (".vocabulary", ?TT_SECTION),
  lexer:load_token (".target",     ?TT_SECTION),
  lexer:load_token (".vocabular",  ?TT_SECTION),
  lexer:load_token (".include",    ?TT_SECTION),
  lexer:load_token (".mutation",   ?TT_SECTION),
  lexer:load_token (".base",       ?TT_SECTION),
  lexer:load_token (".forward",    ?TT_DIRECTION),
  lexer:load_token (".backward",   ?TT_DIRECTION),
  lexer:load_token ("{",  ?TT_CONTENT_BEGIN),
  lexer:load_token ("}",  ?TT_CONTENT_END),
  lexer:load_token ("=",  ?TT_ASSIGNMENT),
  lexer:load_token ("|",  ?TT_GUARD),
  lexer:load_token ("/*", ?TT_COMMENT_BEGIN),
  lexer:load_token ("*/", ?TT_COMMENT_END),
  % setting up process dictionary
  erlang:put (comment, 0),
  erlang:put (state, main),
  % start parsing
  loop (main).

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

loop (State) ->
  { Type, Token } = lexer:next_token (),
  Format = "parsing state '~p' before token '~s' of type '~p'",
  debug:detail (?MODULE, Format, [ State, Token, Type ]),
  case erlang:apply (?MODULE, State, [ Type, Token ]) of
    exit -> ok;
    NewState -> loop (NewState)
  end.

%
% main
%

main (?TT_SECTION, ".attribute") ->
  % '.attribute' name '{'
  Name = lexer:next_token (?TT_DEFAULT),
  model:create_entity (Name, ?ET_ATTRIBUTE),  
  lexer:load_token (Name, ?TT_ATTRIBUTE),
  lexer:next_token (?TT_CONTENT_BEGIN),
  erlang:put (base, Name),
  attribute;

main (?TT_SECTION, ".class") ->
  % '.class' name '{'
  Name = lexer:next_token (?TT_DEFAULT),
  model:create_entity (Name, ?ET_CLASS),
  lexer:load_token (Name, ?TT_CLASS),
  lexer:next_token (?TT_CONTENT_BEGIN),
  erlang:put (base, Name),
  class;

main (?TT_SECTION, ".match") ->
  % '.match' ( '.forward' | '.backward' ) name [ '.vocabular' dictionary ] '{'
  Direction =
    case lexer:next_token (?TT_DIRECTION) of
      ".forward"  -> forward;
      ".backward" -> backward
    end,
  erlang:put (rule_direction, Direction),
  Name = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Name, ?TT_MATCH),
  case lexer:next_token () of
    { ?TT_SECTION, ".vocabular" } ->
      Dictionary = lexer:next_token (?TT_VOCABULARY),
      Tag = [ proplists:property (direction, Direction),
              proplists:property (vocabular, Dictionary) ],
      model:create_entity (Name, ?ET_MATCH, Tag),
      lexer:next_token (?TT_CONTENT_BEGIN);
    { ?TT_CONTENT_BEGIN, _ } ->
      Tag = [ proplists:property (direction, Direction) ],
      model:create_entity (Name, ?ET_MATCH, Tag)
  end,
  erlang:put (base, Name),
  erlang:put (rule_x, 1),
  erlang:put (rule_y, 1),
  match_rule;

main (?TT_SECTION, ".alphabet") ->
  % '.alphabet' wildcard name [ '.base' { name } ] '{'
  Wildcard = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Wildcard, ?TT_WILDCARD),
  Name = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Name, ?TT_ALPHABET),
  { Parents, State } =
    case lexer:next_token () of
      { ?TT_CONTENT_BEGIN, _ } ->
        { [], alphabet };
      { ?TT_SECTION, ".base" } ->
        get_parents (?TT_ALPHABET, alphabet)
    end,
  Tag = [ proplists:property (wildcard, Wildcard),
          proplists:property (base, Parents) ],
  model:create_entity (Name, ?ET_ALPHABET, Tag),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".mutation") ->
  % '.mutation' wildcard name [ '.base' { name } ] '{'
  Wildcard = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Wildcard, ?TT_WILDCARD),
  Name = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Name, ?TT_MUTATION),
  { Parents, State } =
    case lexer:next_token () of
      { ?TT_CONTENT_BEGIN, _ } ->
        { [], mutation };
      { ?TT_SECTION, ".base" } ->
        get_parents (?TT_MUTATION, mutation)
    end,
  Tag = [ proplists:property (wildcard, Wildcard),
          proplists:property (base, Parents) ],
  model:create_entity (Name, ?ET_MUTATION, Tag),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".vocabulary") ->
  % '.vocabulary' name '{'
  Name = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Name, ?TT_VOCABULARY),
  model:create_entity (Name, ?ET_VOCABULARY),
  lexer:next_token (?TT_CONTENT_BEGIN),
  erlang:put (base, Name),
  vocabular_entry;

main (?TT_SECTION, ".language") ->
  % '.language' name min_version max_version
  Name       = lexer:next_token (?TT_DEFAULT),
  MinVersion = lexer:next_token (?TT_DEFAULT),
  MaxVersion = lexer:next_token (?TT_DEFAULT),
  Min        = string:to_integer (MinVersion),
  Max        = string:to_integer (MaxVersion),
  model:ensure (language, Name),
  model:ensure ({ version, min }, Min, fun (V) -> V >= Min end),
  model:ensure ({ version, max }, Max, fun (V) -> V =< Max end),
  main;

main (?TT_SECTION, ".target") ->
  % '.target' name
  Name = lexer:next_token (?TT_MATCH),
  model:ensure (target, Name),
  main;

main (?TT_SECTION, ".vocabular") ->
  % '.vocabular' name
  Name = lexer:next_token (?TT_DEFAULT),
  lexer:load_token (Name, ?TT_MATCH),
  Tag = [ proplists:property (direction, forward) ],
  model:create_entity (Name, ?ET_MATCH, Tag),
  model:ensure (vocabular, Name),
  main;

main (?TT_SECTION, ".include") ->
  % '.include' file
  Name = lexer:next_token (?TT_STRING),
  lexer:include_file (lang, Name),
  main;

main (?TT_EOT, "") ->
  exit;

main (Type, Token) ->
  default (Type, Token, main).

%
% attribute
%

attribute (?TT_DEFAULT, Key) ->
  % key '=' value
  lexer:load_token (Key, ?TT_PROPERTY),
  lexer:next_token (?TT_ASSIGNMENT),
  Value  = lexer:next_token (?TT_STRING),
  Entity = erlang:get (base),
  model:create_property (Entity, Key, Value),
  attribute;

attribute (Type, Token) -> default (Type, Token, attribute).

%
% class
%

class (?TT_ATTRIBUTE, Member) ->
  % member
  Entity = erlang:get (base),
  model:create_property (Entity, #member { class = Entity, member = Member }),
  class;

class (Type, Token) -> default (Type, Token, class).

%
% alphabet
%

alphabet (?TT_DEFAULT, Phoneme) ->
  % alpha '=' string
  lexer:load_token (Phoneme, ?TT_PHONEME),
  lexer:next_token (?TT_ASSIGNMENT),
  Value  = lexer:next_token (?TT_STRING),
  Entity = erlang:get (base),
  model:create_property (Entity, Phoneme, Value),
  alphabet;

alphabet (Type, Token) -> default (Type, Token, alphabet).

%
% mutation
%

mutation (?TT_PHONEME, PhonemeSrc) ->
  % phoneme '=' phoneme
  lexer:next_token (?TT_ASSIGNMENT),
  PhonemeDst = lexer:next_token (?TT_PHONEME),
  Entity = erlang:get (base),
  model:create_property (Entity, ?UP_MUTATION (PhonemeSrc), PhonemeDst),
  mutation;

mutation (?TT_WILDCARD, WildcardSrc) ->
  % wildcard '=' phoneme
  PhonemesSrc = model:get_phonemes (WildcardSrc),
  lexer:next_token (?TT_ASSIGNMENT),
  PhonemeDst = lexer:next_token (?TT_PHONEME),
  Entity = erlang:get (base),
  Fun =
    fun (PhonemeSrc) ->
      model:create_property (Entity, ?UP_MUTATION (PhonemeSrc), PhonemeDst)
    end,
  lists:foreach (Fun, PhonemesSrc),
  mutation;

mutation (Type, Token) -> default (Type, Token, mutation).

%
% match
%

match_rule (?TT_BREAK, "\n") ->
  case erlang:get (rule_x) of
    1 -> ok;
    _ ->
      OrdinalY = erlang:get (rule_y),
      erlang:put (rule_x, 1),
      erlang:put (rule_y, OrdinalY + 1)
  end,
  match_rule;

match_rule (?TT_MATCH, Rule) ->
  % separated rule
  Match     = erlang:get (base),
  OrdinalX  = erlang:get (rule_x),
  OrdinalY  = erlang:get (rule_y),
  Entity    = model:get_entity (Rule),
  Direction = proplists:get_value (direction, Entity#entity.tag),
  model:create_rule (Match, OrdinalX, OrdinalY, Rule, Direction),
  erlang:put (rule_x, OrdinalX + 1),
  match_rule;

match_rule (?TT_DEFAULT, Expression) ->
  % regular expression
  Direction = erlang:get (rule_direction),
  Filters =
    case Direction of
      forward  -> rule:parse_forward (Expression);
      backward -> rule:parse_backward (Expression)
    end,
  Match    = erlang:get (base),
  OrdinalX = erlang:get (rule_x),
  OrdinalY = erlang:get (rule_y),
  model:create_regexp (Match, OrdinalX, OrdinalY, Expression, Filters, Direction),
  erlang:put (rule_x, OrdinalX + 1),
  match_rule;

match_rule (?TT_GUARD, "|") ->
  % '|'
  erlang:put (rule_x, 1),
  match_guard;

match_rule (Type, Token) -> default (Type, Token, match_rule).

match_guard (?TT_BREAK, "\n") ->
  OrdinalY = erlang:get (rule_y),
  erlang:put (rule_x, 1),
  erlang:put (rule_y, OrdinalY + 1),
  match_rule;

match_guard (?TT_PROPERTY, Property) ->
  % condition
  Match    = erlang:get (base),
  OrdinalX = erlang:get (rule_x),
  OrdinalY = erlang:get (rule_y),
  Entity   = model:get_entity_name (Property),
  model:create_guard (Match, OrdinalX, OrdinalY, Entity, Property),
  erlang:put (rule_x, OrdinalX + 1),
  match_guard;

match_guard (Type, Token) -> default (Type, Token, match_guard).

%
% vocabulary
%

vocabular_entry (?TT_BREAK, "\n") ->
  vocabular_entry;

vocabular_entry (?TT_DEFAULT, Stem) ->
  % stem
  Vocabulary = erlang:get (base),
  model:create_stem (Vocabulary, Stem),
  erlang:put (stem, Stem),
  vocabular_specification;

vocabular_entry (Type, Token) -> default (Type, Token, vocabular_entry).

vocabular_specification (?TT_BREAK, "\n") ->
  vocabular_entry;

vocabular_specification (?TT_PROPERTY, Property) ->
  % e.g. 'vb.', 'B' ...
  Vocabulary = erlang:get (base),
  Stem       = erlang:get (stem),
  model:create_characteristic (Vocabulary, Stem, Property),
  vocabular_specification;

vocabular_specification (Type, Token) -> default (Type, Token, vocabular_specification).

%
% comment
%

comment (?TT_COMMENT_END, "*/") ->
  case erlang:get (comment) of
    0 -> fatal ("unexpected end of the comment");
    1 ->
      erlang:put (comment, 0),
      erlang:get (state);
    N ->
      erlang:put (comment, N - 1),
      comment
  end;

comment (?TT_EOT, "") ->
  fatal ("unexpected end of the text while comment not finished"),
  exit;

comment (_Type, _Token) ->
  comment.
      
%
% any state
%

default (?TT_BREAK, "\n", State) ->
  State;

default (?TT_COMMENT_BEGIN, "/*", State) ->
  % begin multiline comment
  N = erlang:get (comment),
  erlang:put (comment, N + 1),
  erlang:put (state, State),
  comment;

default (?TT_CONTENT_END, "}", State)
  when State == attribute; State == class; State == alphabet;
       State == match_rule; State == match_guard;
       State == vocabular_entry; State == vocabular_specification;
       State == mutation ->
  % end of the section
  main;

default (Type, Token, State) ->
  fatal ("unexpected '~s' of type '~p' when '~p'", [ Token, Type, State ]).

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

%
% parse
%

get_parents (TokenType, State) ->
  do_get_parents (TokenType, State, []).

do_get_parents (TokenType, State, Parents) ->
  case lexer:next_token () of
    { ?TT_CONTENT_BEGIN, _ } -> { Parents, State };
    { TokenType, Name } ->
      do_get_parents (TokenType, State, [ Name | Parents ]);
    { OtherType, Name } ->
      fatal ("expected parent '~s' of type '~p' instead of '~p'", [ Name, TokenType, OtherType ]),
      { Parents, exit }
  end.

%
% errors
%

fatal (Message) ->
  fatal (Message, []).

fatal (Message, Args) ->
  % raise the exception
  debug:result (?MODULE, Message, Args),
  throw (error).
