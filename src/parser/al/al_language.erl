%% @doc Grammar reference parser.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_language).

%
% api
%

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

%
% headers
%

-include ("general.hrl").
-include ("l-model.hrl").
-include ("l-token.hrl").

% =============================================================================
% API
% =============================================================================

parse () ->
  % setting up lexer
  acc_lexer:load_token ("\r", ?TT_SEPARATOR),
  acc_lexer:load_token ("\t", ?TT_SEPARATOR),
  acc_lexer:load_token (" ",  ?TT_SEPARATOR),
  acc_lexer:load_token ("\n", ?TT_BREAK),
  acc_lexer:load_token (".language",   ?TT_SECTION),
  acc_lexer:load_token (".compiler",   ?TT_SECTION),
  acc_lexer:load_token (".class",      ?TT_SECTION),
  acc_lexer:load_token (".attribute",  ?TT_SECTION),
  acc_lexer:load_token (".verbose",    ?TT_SECTION),
  acc_lexer:load_token (".match",      ?TT_SECTION),
  acc_lexer:load_token (".alphabet",   ?TT_SECTION),
  acc_lexer:load_token (".wildcard",   ?TT_SECTION),
  acc_lexer:load_token (".vocabulary", ?TT_SECTION),
  acc_lexer:load_token (".target",     ?TT_SECTION),
  acc_lexer:load_token (".vocabular",  ?TT_SECTION),
  acc_lexer:load_token (".include",    ?TT_SECTION),
  acc_lexer:load_token (".mutation",   ?TT_SECTION),
  acc_lexer:load_token (".base",       ?TT_SECTION),
  acc_lexer:load_token (".global",     ?TT_SECTION),
  acc_lexer:load_token (".module",     ?TT_SECTION),
  acc_lexer:load_token (".prefix",     ?TT_DIRECTION),
  acc_lexer:load_token (".suffix",     ?TT_DIRECTION),
  acc_lexer:load_token (".postfix",    ?TT_DIRECTION),
  acc_lexer:load_token ("{",  ?TT_CONTENT_BEGIN),
  acc_lexer:load_token ("}",  ?TT_CONTENT_END),
  acc_lexer:load_token ("=",  ?TT_ASSIGNMENT),
  acc_lexer:load_token ("|",  ?TT_GUARD),
  acc_lexer:load_token ("~",  ?TT_GUARD),
  acc_lexer:load_token ("/*", ?TT_COMMENT_BEGIN),
  acc_lexer:load_token ("*/", ?TT_COMMENT_END),
  % setting up process dictionary
  erlang:put (comment, 0),
  erlang:put (state, main),
  erlang:put (global, true),
  al_model:ensure (version, { ?BC_VERSION, ?FC_VERSION }),
  % start parsing
  loop (main).

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

loop (State) ->
  { Type, Token } = acc_lexer:next_token (),
  case State =/= comment of
    true  -> ?d_detail (?str_llang_pstate (State, Token, Type));
    false -> ok
  end,
  case erlang:apply (?MODULE, State, [ Type, Token ]) of
    exit -> ok;
    NewState -> loop (NewState)
  end.

%
% main
%

main (?TT_SECTION, ".attribute") ->
  % '.attribute' name ordinal [ '.verbose' ] '{'
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_ATTRIBUTE),
  Position = acc_lexer:next_token (?TT_DEFAULT),
  Ordinal  = acc_debug:parse_int (Position),
  Verbose  =
    case acc_lexer:next_token () of
      { ?TT_SECTION, ".verbose" } ->
        acc_lexer:next_token (?TT_CONTENT_BEGIN),
        true;
      { ?TT_CONTENT_BEGIN, _ } ->
        false
    end,
  Props =
    [ { verbose, Verbose },
      { ordinal, Ordinal },
      { members, [] } ],
  al_model:create_entity (Name, ?ET_ATTRIBUTE, Props),
  erlang:put (base, Name),
  attribute;

main (?TT_SECTION, ".class") ->
  % '.class' name '{'
  Name  = acc_lexer:next_token (?TT_DEFAULT),
  Props = [ { members, [ Name ] } ],
  al_model:create_entity (Name, ?ET_CLASS, Props),
  acc_lexer:load_token (Name, ?TT_CLASS),
  acc_lexer:next_token (?TT_CONTENT_BEGIN),
  erlang:put (base, Name),
  class;

main (?TT_SECTION, ".match") ->
  % '.match' ( '.prefix' | '.suffix' | '.postfix' ) name [ '.vocabular' dictionary ] '{'
  Direction =
    case acc_lexer:next_token (?TT_DIRECTION) of
      ".prefix"  -> prefix;
      ".postfix" -> postfix;
      ".suffix"  -> suffix
    end,
  erlang:put (rule_direction, Direction),
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_MATCH),
  case acc_lexer:next_token () of
    { ?TT_SECTION, ".vocabular" } ->
      Dictionary = acc_lexer:next_token (?TT_DEFAULT),
      acc_lexer:load_token (Dictionary, ?TT_VOCABULARY),
      Props =
        [ { direction, Direction },
          { vocabular, Dictionary } ],
      al_model:create_entity (Name, ?ET_MATCH, Props),
      acc_lexer:next_token (?TT_CONTENT_BEGIN);
    { ?TT_CONTENT_BEGIN, _ } ->
      Props = [ { direction, Direction } ],
      al_model:create_entity (Name, ?ET_MATCH, Props)
  end,
  erlang:put (base, Name),
  erlang:put (rule_x, 1),
  erlang:put (rule_y, 1),
  match_rule;

main (?TT_SECTION, ".alphabet") ->
  % '.alphabet' name [ '.base' { name } ] '{'
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_ALPHABET),
  { Parents, State } =
    case acc_lexer:next_token () of
      { ?TT_CONTENT_BEGIN, _ } ->
        { [], alphabet };
      { ?TT_SECTION, ".base" } ->
        get_parents (?TT_ALPHABET, alphabet)
    end,
  Props = [ { members, [] } ],
  Type  = ?ET_ALPHABET,
  al_model:create_child_entity (Parents, Type, Name, Type, Props),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".wildcard") ->
  % '.wildcard' wildcard name
  Wildcard = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Wildcard, ?TT_WILDCARD),
  { Type, Name } =
    case acc_lexer:next_token ([ ?TT_ALPHABET, ?TT_MUTATION ]) of
      { ?TT_ALPHABET, Name0 } -> { ?ET_ALPHABET, Name0 };
      { ?TT_MUTATION, Name0 } -> { ?ET_MUTATION, Name0 }
    end,
  Props =
    [ { global, erlang:get (global) },
      { target_type, Type },
      { target_name, Name } ],
  al_model:create_entity (Wildcard, ?ET_WILDCARD, Props),
  main;

main (?TT_SECTION, ".global") ->
  % '.global'
  erlang:put (global, true),
  main;

main (?TT_SECTION, ".module") ->
  % '.module'
  erlang:put (global, false),
  Wildcards = al_model:delete_entities (?ET_WILDCARD, global, false),
  Fun =
    fun (#gas_entry { k = #entity_k { name = Name } }) ->
      acc_lexer:reset_token (Name, ?TT_WILDCARD)
    end,
  lists:foreach (Fun, Wildcards),
  main;

main (?TT_SECTION, ".mutation") ->
  % '.mutation' name [ '.base' { name } ] '{'
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_MUTATION),
  { Parents, State } =
    case acc_lexer:next_token () of
      { ?TT_CONTENT_BEGIN, _ } ->
        { [], mutation };
      { ?TT_SECTION, ".base" } ->
        get_parents (?TT_MUTATION, mutation)
    end,
  Props = [ { members, [] } ],
  Type  = ?ET_MUTATION,
  al_model:create_child_entity (Parents, Type, Name, Type, Props),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".vocabulary") ->
  % '.vocabulary' name '{'
  Name = acc_lexer:next_token (?TT_VOCABULARY),  
  acc_lexer:next_token (?TT_CONTENT_BEGIN),
  al_model:create_vocabulary (Name),
  erlang:put (base, Name),
  vocabular_entry;

main (?TT_SECTION, ".language") ->
  % '.language' name min_version max_version
  Name       = acc_lexer:next_token (?TT_DEFAULT),
  MinVersion = acc_lexer:next_token (?TT_DEFAULT),
  MaxVersion = acc_lexer:next_token (?TT_DEFAULT),
  Min        = acc_debug:parse_int (MinVersion),
  Max        = acc_debug:parse_int (MaxVersion),
  al_model:ensure (language, Name, fun (N) -> N =:= Name andalso Min =< Max end),
  al_model:ensure ({ version, min }, Min, fun (V) -> V =< Max end),
  al_model:ensure ({ version, max }, Max, fun (V) -> V >= Min end),
  main;

main (?TT_SECTION, ".compiler") ->
  % '.compiler' bc_version fc_version
  BcVersion = acc_lexer:next_token (?TT_DEFAULT),
  FcVersion = acc_lexer:next_token (?TT_DEFAULT),
  Bc        = acc_debug:parse_int (BcVersion),
  Fc        = acc_debug:parse_int (FcVersion),
  Fun       = fun ({ Bc_, Fc_ }) -> Bc_ == ?BC_VERSION andalso Fc_ =< ?FC_VERSION end,
  al_model:ensure (version, { Bc, Fc }, Fun),
  main;

main (?TT_SECTION, ".target") ->
  % '.target' name
  Name = acc_lexer:next_token (?TT_MATCH),
  al_model:ensure (target, Name),
  main;

main (?TT_SECTION, ".include") ->
  % '.include' file
  Name = acc_lexer:next_token (?TT_STRING),
  acc_lexer:include_file (lang, Name),
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
  acc_lexer:load_token (Key, ?TT_PROPERTY),
  acc_lexer:next_token (?TT_ASSIGNMENT),
  Value = acc_lexer:next_token (?TT_STRING),
  Base  = erlang:get (base),
  al_model:add_property_value (Base, ?ET_ATTRIBUTE, members, { Key, Value }),
  attribute;

attribute (Type, Token) -> default (Type, Token, attribute).

%
% class
%

class (?TT_ATTRIBUTE, Member) ->
  % member
  Base = erlang:get (base),
  al_model:add_property_value (Base, ?ET_CLASS, members, Member),
  class;

class (Type, Token) -> default (Type, Token, class).

%
% alphabet
%

alphabet (?TT_DEFAULT, Phoneme) ->
  % alpha '=' string
  acc_lexer:load_token (Phoneme, ?TT_PHONEME),
  acc_lexer:next_token (?TT_ASSIGNMENT),
  Value  = acc_lexer:next_token (?TT_STRING),
  Entity = erlang:get (base),
  Member = { Phoneme, Value },
  al_model:add_property_value (Entity, ?ET_ALPHABET, members, Member),
  alphabet;

alphabet (Type, Token) -> default (Type, Token, alphabet).

%
% mutation
%

mutation (?TT_PHONEME, PhonemeSrc) ->
  % phoneme '=' phoneme
  acc_lexer:next_token (?TT_ASSIGNMENT),
  PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
  Entity     = erlang:get (base),
  Member     = { PhonemeSrc, PhonemeDst },
  al_model:add_property_value (Entity, ?ET_MUTATION, members, Member),
  mutation;

mutation (?TT_WILDCARD, WildcardSrc) ->
  % wildcard '=' phoneme
  acc_lexer:next_token (?TT_ASSIGNMENT),
  PhonemeDst  = acc_lexer:next_token (?TT_PHONEME),
  Entity0     = al_model:get_entity_value (WildcardSrc, ?ET_WILDCARD),
  Name        = proplists:get_value (target_name, Entity0#entity_v.properties),
  Type        = proplists:get_value (target_type, Entity0#entity_v.properties),
  Phonemes    = al_model:get_recursive_properties (Name, Type, members),
  Entity      = erlang:get (base),
  Fun         =
    fun ({ Phoneme, _ }) ->
      Member  = { Phoneme, PhonemeDst },
      al_model:add_property_value (Entity, ?ET_MUTATION, members, Member)
    end,
  lists:foreach (Fun, Phonemes),
  mutation;

mutation (Type, Token) -> default (Type, Token, mutation).

%
% match
%

match_rule (?TT_BREAK, "\n") ->
  case erlang:get (rule_x) of
    1 -> ok;
    _ ->
      Y = erlang:get (rule_y),
      erlang:put (rule_x, 1),
      erlang:put (rule_y, Y + 1)
  end,
  match_rule;

match_rule (?TT_MATCH, Rule) ->
  % separated rule
  Match     = erlang:get (base),
  X         = erlang:get (rule_x),
  Y         = erlang:get (rule_y),
  Entity    = al_model:get_entity_value (Rule, ?ET_MATCH),
  Direction = proplists:get_value (direction, Entity#entity_v.properties),
  case proplists:get_value (vocabular, Entity#entity_v.properties) of
    undefined ->
      al_model:create_composite (Match, Rule, X, Y, Direction);
    Vocabulary ->
      al_model:create_vocabular (Match, Rule, Vocabulary, X, Y, Direction)
  end,
  erlang:put (rule_x, X + 1),
  match_rule;

match_rule (?TT_DEFAULT, Expression) ->
  % regular expression
  Match     = erlang:get (base),
  X         = erlang:get (rule_x),
  Y         = erlang:get (rule_y),
  Direction = erlang:get (rule_direction),
  al_model:create_expression (Match, Expression, X, Y, Direction),
  erlang:put (rule_x, X + 1),
  match_rule;

match_rule (?TT_GUARD, "|") ->
  % '|'
  erlang:put (rule_x, 1),
  erlang:put (sign, positive),
  match_guard;

match_rule (Type, Token) -> default (Type, Token, match_rule).

match_guard (?TT_BREAK, "\n") ->
  Y = erlang:get (rule_y),
  erlang:put (rule_x, 1),
  erlang:put (rule_y, Y + 1),
  match_rule;

match_guard (?TT_GUARD, "~") ->
  erlang:put (sign, negative),
  match_guard;

match_guard (?TT_PROPERTY, Property) ->
  % condition
  Match      = erlang:get (base),
  X          = erlang:get (rule_x),
  Y          = erlang:get (rule_y),
  Sign       = erlang:get (sign),
  Entity     = al_model:find_entity (?ET_ATTRIBUTE, members, Property),
  Base       = Entity#gas_entry.k#entity_k.name,
  al_model:create_guard (Match, Property, Base, property, X, Y, Sign),
  erlang:put (rule_x, X + 1),
  erlang:put (sign, positive),
  match_guard;

match_guard (?TT_CLASS, Entity) ->
  % condition
  Match      = erlang:get (base),
  X          = erlang:get (rule_x),
  Y          = erlang:get (rule_y),
  al_model:create_guard (Match, Entity, Entity, class, X, Y, positive),
  erlang:put (rule_x, X + 1),
  erlang:put (sign, positive),
  match_guard;

match_guard (Type, Token) -> default (Type, Token, match_guard).

%
% vocabulary
%

vocabular_entry (?TT_BREAK, "\n") ->
  vocabular_entry;

vocabular_entry (?TT_DEFAULT, Stem) ->
  % stem
  erlang:put (stem, Stem),
  erlang:put (guards, []),
  vocabular_specification;

vocabular_entry (Type, Token) -> default (Type, Token, vocabular_entry).

vocabular_specification (?TT_BREAK, "\n") ->
  Vocabulary = erlang:get (base),
  Stem       = erlang:get (stem),
  Guards     = erlang:get (guards),
  al_model:create_stem (Vocabulary, Stem, Guards),
  vocabular_entry;

vocabular_specification (?TT_PROPERTY, Property) ->
  % e.g. 'vb.', 'B' ...
  Entity     = al_model:find_entity (?ET_ATTRIBUTE, members, Property),
  Base       = Entity#gas_entry.k#entity_k.name,
  Guards     = erlang:get (guards),
  Guard      = #guard_v { sign = positive,
                          base = Base,
                          type = property,
                          name = Property },
  erlang:put (guards, [ Guard | Guards ]),
  vocabular_specification;

vocabular_specification (Type, Token) ->
  default (Type, Token, vocabular_specification).

%
% comment
%

comment (?TT_COMMENT_END, "*/") ->
  case erlang:get (comment) of
    0 -> fatal (?str_llang_ucend);
    1 ->
      erlang:put (comment, 0),
      erlang:get (state);
    N ->      
      erlang:put (comment, N - 1),
      comment
  end;

comment (?TT_COMMENT_BEGIN, "/*") ->
  % begin multiline comment
  N = erlang:get (comment),
  erlang:put (comment, N + 1),
  comment;

comment (?TT_EOT, "") ->
  fatal (?str_llang_ueotbcend),
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
  fatal (?str_llang_uewstate (State, Token, Type)).

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

%
% parse
%

get_parents (TokenType, State) ->
  do_get_parents (TokenType, State, []).

do_get_parents (TokenType1, State, Parents) ->
  case acc_lexer:next_token () of
    { ?TT_CONTENT_BEGIN, _ } -> { Parents, State };
    { TokenType1, Token } ->
      do_get_parents (TokenType1, State, [ Token | Parents ]);
    { TokenType2, Token } ->
      fatal (?str_llang_eparent (Token, TokenType1, TokenType2)),
      { Parents, exit }
  end.

%
% errors
%

fatal (Resource) ->
  ?d_result (Resource),
  throw (error).
