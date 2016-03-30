%% Word matcher.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (word).

% API
-export ([
          parse/0
        ]).

% WORD DESCRIPTION
-record (attribute, { name  :: string (),
                      value :: string () }).

-type attribute_t () :: # attribute { }.

-record (word, { class      :: string (),
                 attributes :: list (attribute_t ()) }).

-record (match, { name  :: string (),
                  value :: string () }).

-type match_t () :: # match { }.

-record (variant, { attributes :: list (attribute_t ()),
                    matches    :: list (match_t ()) }).

-type patterns_t () :: rule | expression .

-record (pattern, { type  :: patterns_t (),
                    value :: string () }).

-type pattern_t () :: # pattern { }.

-type filter_t () :: fun ((string ()) -> boolean ()).

-record (rule, { name       :: string (),
                 patterns   :: list (pattern_t ()),
                 attributes :: list (string ()),
                 filters    :: list (filter_t ()) }).

% SETTINGS
-define (RULE_TIMEOUT, 10000).

% =============================================================================
% API
% =============================================================================

parse () -> ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

rule (Subword, Attributes, Rule) ->
  case get_subrules (Rule) of
    [] -> exit (error);
    [ Subrule ] ->
      % simple rule
      ok;
    Subrules ->
      % complex rule
      Spawn =
        fun (Subrule) ->
          Args = [ Subword, Attributes, Subrule ],
          erlang:spawn_monitor (?MODULE, subrule, Args)
        end,
      lists:foreach (Spawn, Subrules),
      Count = length (Subrules),
      Variants = rule_loop (Count, []),
      { ok, { true, Variants } }
  end.

rule_loop (0, Acc) -> Acc;
rule_loop (Count, Acc) ->
  % wait for child subrule
  receive
    { 'DOWN', _, process, _, error } -> exit (error);
    { 'DOWN', _, process, _, timeout } -> exit (timeout);
    { 'DOWN', _, process, _, { ok, false } } ->
      % does not match
      rule_loop (Count - 1, Acc);
    { 'DOWN', _, process, _, { ok, { true, Subvariants } } } ->
      % does match
      rule_loop (Count - 1, [ Subvariants | Acc ])
  after
    ?RULE_TIMEOUT ->
      debug:warning (?MODULE, "rule timeout (~p ms)", [ ?RULE_TIMEOUT ]),
      exit (timeout)
  end.

is_conflict (Attributes1, Attributes2) -> false.

get_subrules (Rule) -> ok.