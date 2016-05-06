%% @doc Grammar reference parser.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
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
          reflection/2,
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
  acc_lexer:load_token (".language",          ?TT_SECTION),
  acc_lexer:load_token (".compiler",          ?TT_SECTION),
  acc_lexer:load_token (".class",             ?TT_SECTION),
  acc_lexer:load_token (".attribute",         ?TT_SECTION),  
  acc_lexer:load_token (".match",             ?TT_SECTION),
  acc_lexer:load_token (".alphabet",          ?TT_SECTION),
  acc_lexer:load_token (".wildcard",          ?TT_SECTION),
  acc_lexer:load_token (".vocabulary",        ?TT_SECTION),
  acc_lexer:load_token (".target",            ?TT_SECTION),
  acc_lexer:load_token (".include",           ?TT_SECTION),
  acc_lexer:load_token (".mutation",          ?TT_SECTION),
  acc_lexer:load_token (".reflection",        ?TT_SECTION),
  acc_lexer:load_token (".global",            ?TT_SECTION),
  acc_lexer:load_token (".module",            ?TT_SECTION),
  acc_lexer:load_token (".state",             ?TT_SECTION),
  acc_lexer:load_token (".forward",           ?TT_DIRECTION),
  acc_lexer:load_token (".backward",          ?TT_DIRECTION),
  acc_lexer:load_token (".inward",            ?TT_DIRECTION),
  acc_lexer:load_token (".forward-void",      ?TT_DIRECTION),
  acc_lexer:load_token (".backward-void",     ?TT_DIRECTION),
  acc_lexer:load_token (".inward-void",       ?TT_DIRECTION),
  acc_lexer:load_token (".base",              ?TT_BASE),
  acc_lexer:load_token (".vocabular",         ?TT_VOCABULAR),
  acc_lexer:load_token (".vocabular-l",       ?TT_VOCABULAR),
  acc_lexer:load_token (".vocabular-r",       ?TT_VOCABULAR),
  acc_lexer:load_token (".verbose",           ?TT_SPECIFIER),
  acc_lexer:load_token (".save-state",        ?TT_ACTION),
  acc_lexer:load_token (".load-state",        ?TT_ACTION),
  acc_lexer:load_token (".eow",               ?TT_ACTION),
  acc_lexer:load_token (".empty",             ?TT_ACTION),
  acc_lexer:load_token ("{",  ?TT_CONTENT_BEGIN),
  acc_lexer:load_token ("}",  ?TT_CONTENT_END),
  acc_lexer:load_token ("(",  ?TT_GROUP),
  acc_lexer:load_token (")",  ?TT_GROUP),
  acc_lexer:load_token (";",  ?TT_CONTENT_STOP),
  acc_lexer:load_token ("=",  ?TT_ASSIGNMENT),
  acc_lexer:load_token ("+=", ?TT_ILASSIGNMENT),
  acc_lexer:load_token ("=+", ?TT_IRASSIGNMENT),
  acc_lexer:load_token ("|",  ?TT_GUARD),
  acc_lexer:load_token ("&",  ?TT_GUARD),
  acc_lexer:load_token ("~",  ?TT_GUARD),
  acc_lexer:load_token ("/*", ?TT_COMMENT_BEGIN),
  acc_lexer:load_token ("*/", ?TT_COMMENT_END),
  % setting up process dictionary
  erlang:put (comment, 0),
  erlang:put (state, main),
  erlang:put (global, true),
  al_model:ensure (version, { ?BC_VERSION, ?FC_VERSION }),
  % create empty alphabet
  Props = [ { members, [] } ],
  Type  = ?ET_ALPHABET,
  al_model:create_child_entity ([], Type, ".empty", Type, Props),
  al_model:add_property_value (".empty", Type, members, { "", "empty" }),
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
    case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_SPECIFIER ]) of
      { ?TT_SPECIFIER, ".verbose" } ->
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
  % '.match' direction name [ specificator ] ( ';' | '{' )
  % specificator = ( vocabular dictionary ) | ( '=' rule )
  % direction = ( '.forward' | '.backward' | '.inward' ) [ '-void' ]
  % vocabular = ( '.vocabular' | '.vocabular-l' | '.vocabular-r' )
  { Direction, Capacity } =
    case acc_lexer:next_token (?TT_DIRECTION) of
      ".forward"       -> { forward, true };
      ".backward"      -> { backward, true };
      ".inward"        -> { inward, true };
      ".forward-void"  -> { forward, false };
      ".backward-void" -> { backward, false };
      ".inward-void"   -> { inward, false }
    end,
  erlang:put (rule_direction, Direction),  
  { State, Name } =
    case acc_lexer:next_token ([ ?TT_DEFAULT, ?TT_DMATCH ]) of
      { ?TT_DMATCH, Name0 } ->
        acc_lexer:next_token (?TT_CONTENT_BEGIN),
        acc_lexer:reset_token (Name0, ?TT_DMATCH),
        acc_lexer:load_token (Name0, ?TT_MATCH),
        { match_rule, Name0 };
      { ?TT_DEFAULT, Name0 } ->
        case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_CONTENT_STOP, ?TT_VOCABULAR, ?TT_ASSIGNMENT ]) of
          { ?TT_VOCABULAR, Vocabular } ->
            VocType =
              case Vocabular of
                ".vocabular"   -> exact;
                ".vocabular-l" -> left;
                ".vocabular-r" -> right
              end,
            Dictionary = acc_lexer:next_token (?TT_DVOCABULARY),
            Props =
              [ { direction, Direction },
                { capacity, Capacity },
                { equivalent, "" },
                { vocabular, { Dictionary, VocType, value } } ],
            al_model:create_entity (Name0, ?ET_MATCH, Props),
            case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_CONTENT_STOP ]) of
              { ?TT_CONTENT_BEGIN, "{" } ->
                acc_lexer:load_token (Name0, ?TT_MATCH),
                { match_rule, Name0 };
              { ?TT_CONTENT_STOP, ";" } ->
                acc_lexer:load_token (Name0, ?TT_DMATCH),
                { main, Name0 }
            end;
          { ?TT_ASSIGNMENT, "=" } ->
             { _, Name1 } = acc_lexer:next_token ([ ?TT_MATCH, ?TT_DMATCH ]),
             Props =
              [ { direction, Direction },
                { capacity, Capacity },
                { equivalent, Name1 } ],
             al_model:create_entity (Name0, ?ET_MATCH, Props),
             case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_CONTENT_STOP ]) of
              { ?TT_CONTENT_BEGIN, "{" } ->
                acc_lexer:load_token (Name0, ?TT_MATCH),
                { match_rule, Name0 };
              { ?TT_CONTENT_STOP, ";" } ->
                acc_lexer:load_token (Name0, ?TT_DMATCH),
                { main, Name0 }
            end;
          { ?TT_CONTENT_BEGIN, "{" } ->
            Props = [ { direction, Direction },
                      { capacity, Capacity },
                      { equivalent, "" } ],
            al_model:create_entity (Name0, ?ET_MATCH, Props),
            acc_lexer:load_token (Name0, ?TT_MATCH),
            { match_rule, Name0 };
          { ?TT_CONTENT_STOP, ";" } ->
            Props = [ { direction, Direction },
                      { capacity, Capacity },
                      { equivalent, "" } ],
            al_model:create_entity (Name0, ?ET_MATCH, Props),
            acc_lexer:load_token (Name0, ?TT_DMATCH),
            { main, Name0 }
        end        
    end,
  erlang:put (base, Name),
  erlang:put (rule_x, 1),
  erlang:put (rule_y, 1),
  erlang:put (group, 1),
  State;

main (?TT_SECTION, ".alphabet") ->
  % '.alphabet' name [ '.base' { parent } ] '{'
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_ALPHABET),
  { State, Parents } =
    case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_BASE ]) of
      { ?TT_CONTENT_BEGIN, _ } -> { alphabet, [] };
      { ?TT_BASE, ".base" } -> get_parents (?TT_ALPHABET, alphabet)
    end,
  Props = [ { members, [] } ],
  Type  = ?ET_ALPHABET,
  al_model:create_child_entity (Parents, Type, Name, Type, Props),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".wildcard") ->
  % '.wildcard' wildcard alphabet
  % '.wildcard' wildcard mutation
  % '.wildcard' wildcard ( '.load-state' | '.save-state' ) state
  % '.wildcard' wildcard '.eow'
  Wildcard = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Wildcard, ?TT_WILDCARD),
  { Type, Name } =
    case acc_lexer:next_token ([ ?TT_ALPHABET, ?TT_MUTATION, ?TT_REFLECTION, ?TT_ACTION ]) of
      { ?TT_ALPHABET, Name0 }   -> { ?ET_ALPHABET, Name0 };
      { ?TT_MUTATION, Name0 }   -> { ?ET_MUTATION, Name0 };
      { ?TT_REFLECTION, Name0 } -> { ?ET_REFLECTION, Name0 };
      { ?TT_ACTION, ".load-state" } ->
        Name0 = acc_lexer:next_token (?TT_STATE),
        { ?ET_STATE, { load, Name0 } };
      { ?TT_ACTION, ".save-state" } ->
        Name0 = acc_lexer:next_token (?TT_STATE),
        { ?ET_STATE, { save, Name0 } };
      { ?TT_ACTION, ".empty" } ->        
        { ?ET_ALPHABET, ".empty" };
      { ?TT_ACTION, ".eow" } ->
        { ?ET_EOW, "" }
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
  Fun1 =
    fun (#gas_entry { k = #entity_k { name = Name } }) ->
      acc_lexer:reset_token (Name, ?TT_WILDCARD)
    end,
  lists:foreach (Fun1, Wildcards),
  States = al_model:delete_entities (?ET_STATE, global, false),
  Fun2 =
    fun (#gas_entry { k = #entity_k { name = Name } }) ->
      acc_lexer:reset_token (Name, ?TT_STATE)
    end,
  lists:foreach (Fun2, States),
  main;

main (?TT_SECTION, ".mutation") ->
  % '.mutation' name [ '.base' { parent } ] '{'
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_MUTATION),
  { State, Parents } =
    case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_BASE ]) of
      { ?TT_CONTENT_BEGIN, _ } -> { mutation, [] };
      { ?TT_BASE, ".base" } -> get_parents (?TT_MUTATION, mutation)
    end,
  Props = [ { members, [] } ],
  Type  = ?ET_MUTATION,
  al_model:create_child_entity (Parents, Type, Name, Type, Props),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".reflection") ->
  % '.reflection' name [ '.base' { parent } ] '{'
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_REFLECTION),
  { State, Parents } =
    case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_BASE ]) of
      { ?TT_CONTENT_BEGIN, _ } -> { reflection, [] };
      { ?TT_BASE, ".base" } -> get_parents (?TT_REFLECTION, reflection)
    end,
  Props = [ { members, [] } ],
  Type  = ?ET_REFLECTION,
  al_model:create_child_entity (Parents, Type, Name, Type, Props),
  erlang:put (base, Name),
  State;

main (?TT_SECTION, ".state") ->
  % '.state' name
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_STATE),
  Props =
    [ { global, erlang:get (global) } ],
  al_model:create_entity (Name, ?ET_STATE, Props),
  main;

main (?TT_SECTION, ".vocabulary") ->
  % '.vocabulary' name [ '.base' { parent } ] '{'
  { State0, Name0 } =
    case acc_lexer:next_token ([ ?TT_DEFAULT, ?TT_DVOCABULARY ]) of
      { ?TT_DEFAULT, Name } ->
        case acc_lexer:next_token ([ ?TT_CONTENT_BEGIN, ?TT_CONTENT_STOP ]) of
          { ?TT_CONTENT_BEGIN, "{" } ->
            acc_lexer:load_token (Name, ?TT_VOCABULARY),
            al_model:create_vocabulary (Name),
            { vocabular_entry, Name };
          { ?TT_CONTENT_STOP, ";" } ->
            acc_lexer:load_token (Name, ?TT_DVOCABULARY),
            { main, Name };
          { ?TT_BASE, ".base" } ->
            { State, Parents } = get_parents ([ ?TT_VOCABULARY, ?TT_DVOCABULARY ], vocabular_entry),
            Type  = ?ET_VOCABULARY,
            Props = [ { members, [] } ],
            al_model:create_child_entity (Parents, Type, Name, Type, Props),
            { State, Name }
        end;
      { ?TT_DVOCABULARY, Name } ->        
        acc_lexer:reset_token (Name, ?TT_DVOCABULARY),
        acc_lexer:load_token (Name, ?TT_VOCABULARY),
        al_model:create_vocabulary (Name),
        acc_lexer:next_token (?TT_CONTENT_BEGIN),
        { vocabular_entry, Name }
    end,
  erlang:put (base, Name0),
  State0;

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

main (?TT_VOCABULAR, Vocabular) ->
  % vocabular direction name dictionary
  % vocabular = ( '.vocabular' | '.vocabular-prefix' | '.vocabular-postfix' )
  VocType =
    case Vocabular of
      ".vocabular"   -> exact;
      ".vocabular-l" -> left;
      ".vocabular-r" -> right
    end,
  { Direction, Capacity } =
    case acc_lexer:next_token (?TT_DIRECTION) of
      ".forward"       -> { forward, true };
      ".backward"      -> { backward, true };
      ".inward"        -> { inward, true };
      ".forward-void"  -> { forward, false };
      ".backward-void" -> { backward, false };
      ".inward-void"   -> { inward, false }
    end,
  Name = acc_lexer:next_token (?TT_DEFAULT),
  acc_lexer:load_token (Name, ?TT_MATCH),
  Dictionary = acc_lexer:next_token (?TT_DVOCABULARY),
  Props =
    [ { direction, Direction },
      { capacity, Capacity },
      { vocabular, { Dictionary, VocType, word } } ],
  al_model:create_entity (Name, ?ET_MATCH, Props),
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
  alphabet (?TT_PHONEME, Phoneme);

alphabet (?TT_PHONEME, Phoneme) ->
  % alpha '=' string
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
  % phoneme '=' | '+=' | '=+' phoneme
  Entity = erlang:get (base),
  case acc_lexer:next_token ([ ?TT_ASSIGNMENT, ?TT_ILASSIGNMENT, ?TT_IRASSIGNMENT ]) of
    { ?TT_ASSIGNMENT, "=" } ->
      PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
      Member     = { PhonemeSrc, PhonemeDst },
      al_model:add_property_value (Entity, ?ET_MUTATION, members, Member);
    { ?TT_ILASSIGNMENT, "+=" } ->
      PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
      Member     = { PhonemeSrc, PhonemeSrc ++ PhonemeDst },
      al_model:add_property_value (Entity, ?ET_MUTATION, members, Member);
    { ?TT_IRASSIGNMENT, "=+" } ->
      PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
      Member     = { PhonemeSrc, PhonemeDst ++ PhonemeSrc },
      al_model:add_property_value (Entity, ?ET_MUTATION, members, Member)
  end,
  mutation;

mutation (?TT_WILDCARD, WildcardSrc) ->
  % wildcard '=' | '+=' | '=+' phoneme
  Fun =
    fun (Entity) ->
      case acc_lexer:next_token ([ ?TT_ASSIGNMENT, ?TT_ILASSIGNMENT, ?TT_IRASSIGNMENT ]) of
        { ?TT_ASSIGNMENT, "=" } ->
          PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
          fun ({ Phoneme, _ }) ->
            Member = { Phoneme, PhonemeDst },
            al_model:add_property_value (Entity, ?ET_MUTATION, members, Member)
          end;
        { ?TT_ILASSIGNMENT, "+=" } ->
          PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
          fun ({ Phoneme, _ }) ->
            Member = { Phoneme, Phoneme ++ PhonemeDst },
            al_model:add_property_value (Entity, ?ET_MUTATION, members, Member)
          end;
        { ?TT_IRASSIGNMENT, "=+" } ->
          PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
          fun ({ Phoneme, _ }) ->
            Member = { Phoneme, PhonemeDst ++ Phoneme },
            al_model:add_property_value (Entity, ?ET_MUTATION, members, Member)
          end
      end
    end,  
  Entity      = al_model:get_entity_value (WildcardSrc, ?ET_WILDCARD),
  Name        = proplists:get_value (target_name, Entity#entity_v.properties),
  Type        = proplists:get_value (target_type, Entity#entity_v.properties),
  Phonemes    = al_model:get_recursive_properties (Name, Type, members),
  lists:foreach (Fun (erlang:get (base)), Phonemes),
  mutation;

mutation (Type, Token) -> default (Type, Token, mutation).

%
% reflection
%

reflection (?TT_PHONEME, PhonemeSrc) ->
  % phoneme '=' | '+=' | '=+' phoneme
  Entity = erlang:get (base),
  case acc_lexer:next_token ([ ?TT_ASSIGNMENT, ?TT_ILASSIGNMENT, ?TT_IRASSIGNMENT ]) of
    { ?TT_ASSIGNMENT, "=" } ->
      PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
      Member     = { PhonemeSrc, PhonemeDst },
      al_model:add_property_value (Entity, ?ET_REFLECTION, members, Member);
    { ?TT_ILASSIGNMENT, "+=" } ->
      PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
      Member     = { PhonemeSrc, PhonemeSrc ++ PhonemeDst },
      al_model:add_property_value (Entity, ?ET_REFLECTION, members, Member);
    { ?TT_IRASSIGNMENT, "=+" } ->
      PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
      Member     = { PhonemeSrc, PhonemeDst ++ PhonemeSrc },
      al_model:add_property_value (Entity, ?ET_REFLECTION, members, Member)
  end,
  reflection;

reflection (?TT_WILDCARD, WildcardSrc) ->
  % wildcard '=' | '+=' | '=+' phoneme
  Fun =
    fun (Entity) ->
      case acc_lexer:next_token ([ ?TT_ASSIGNMENT, ?TT_ILASSIGNMENT, ?TT_IRASSIGNMENT ]) of
        { ?TT_ASSIGNMENT, "=" } ->
          PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
          fun ({ Phoneme, _ }) ->
            Member = { Phoneme, PhonemeDst },
            al_model:add_property_value (Entity, ?ET_REFLECTION, members, Member)
          end;
        { ?TT_ILASSIGNMENT, "+=" } ->
          PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
          fun ({ Phoneme, _ }) ->
            Member = { Phoneme, Phoneme ++ PhonemeDst },
            al_model:add_property_value (Entity, ?ET_REFLECTION, members, Member)
          end;
        { ?TT_IRASSIGNMENT, "=+" } ->
          PhonemeDst = acc_lexer:next_token (?TT_PHONEME),
          fun ({ Phoneme, _ }) ->
            Member = { Phoneme, PhonemeDst ++ Phoneme },
            al_model:add_property_value (Entity, ?ET_REFLECTION, members, Member)
          end
      end
    end,  
  Entity      = al_model:get_entity_value (WildcardSrc, ?ET_WILDCARD),
  Name        = proplists:get_value (target_name, Entity#entity_v.properties),
  Type        = proplists:get_value (target_type, Entity#entity_v.properties),
  Phonemes    = al_model:get_recursive_properties (Name, Type, members),
  lists:foreach (Fun (erlang:get (base)), Phonemes),
  reflection;

reflection (Type, Token) -> default (Type, Token, reflection).

%
% match
%

match_rule (?TT_BREAK, "\n") ->
  case erlang:get (rule_x) of
    1 -> ok;
    _ ->
      Y = erlang:get (rule_y),
      erlang:put (rule_x, 1),
      erlang:put (rule_y, Y + 1),
      erlang:put (group, 1)
  end,
  match_rule;

match_rule (Type, Rule)
  when Type =:= ?TT_MATCH orelse Type =:= ?TT_DMATCH ->
  % separated rule
  Match     = erlang:get (base),
  X         = erlang:get (rule_x),
  Y         = erlang:get (rule_y),
  Entity    = al_model:get_entity_value (Rule, ?ET_MATCH),
  Direction = proplists:get_value (direction, Entity#entity_v.properties),
  Capacity  = proplists:get_value (capacity, Entity#entity_v.properties),
  Equvalent = proplists:get_value (equivalent, Entity#entity_v.properties),
  case proplists:get_value (vocabular, Entity#entity_v.properties) of
    undefined ->
      al_model:create_composite (Match, Rule, Equvalent, X, Y, Capacity, Direction);
    { Voc, VocType, MatchType } ->
      al_model:create_vocabular (Match, Rule, Voc, VocType, MatchType, X, Y, Capacity, Direction)
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
  erlang:put (group, 1),
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
       State == mutation; State == reflection ->
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

get_parents (TokenType, State) when is_atom (TokenType) ->
  do_get_parents ([ TokenType ], State, []);
get_parents (TokenTypes, State) when is_list (TokenTypes) ->
  do_get_parents (TokenTypes, State, []).

do_get_parents (TokenTypes, State, Parents) ->
  case acc_lexer:next_token () of
    { ?TT_CONTENT_BEGIN, "{" } -> { State, Parents };
    { ?TT_CONTENT_STOP, ";" } -> { main, Parents };
    { TokenType, Token } ->
      case lists:member (TokenType, TokenTypes) of
        true  -> do_get_parents (TokenTypes, State, [ Token | Parents ]);
        false ->
          fatal (?str_llang_eparent (Token, TokenType, TokenTypes)),
          throw (?e_error)
      end
  end.

%
% errors
%

fatal (Resource) ->
  ?d_result (Resource),
  throw (error).
