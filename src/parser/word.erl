%% Word matcher.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (word).

% API
-export ([
          parse/1
        ]).

% HEADERS
-include ("general.hrl").
-include ("model.hrl").

% DEFINITIONS
-record (variant, { match    :: string (),
                    word_in  :: string (),
                    word_out :: string (),
                    value    :: string (),
                    guards   :: list (string ()),
                    level    :: position_t (),
                    pos_x    :: position_t (),
                    pos_y    :: position_t (),
                    phony    :: boolean () }).

% =============================================================================
% API
% =============================================================================

parse (Word) ->
  Table = ets:new ('case storage', [ set, private, { keypos, 2 } ]),
  try
    [ Rule ] = model:ensure (target),
    rule (Word, [], Rule, Table, 1),
    dump (Table, 1),
    []
  catch
    _:_ -> throw (error)
  after
    ets:close (Table)
  end.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

rule (Word, Guards, Rule, Table, Level) ->
  case model:get_subrules (Rule) of
    [] ->
      % bad grammar reference
      debug:warning (?MODULE, "the rule '~s' have not subrules", [ Rule ]),
      throw (error);
    Subrules ->
      % match subrules
      detail (Level, "rule: ~s, word: ~s | ~p", [ Rule, Word, length (Guards) ]),
      Vertical =
        fun (SubruleY) ->
          Horizontal =
            fun
              (_SubruleX, false) -> false;
              (SubruleX, Subword) ->
                Subguards = get_subguards (SubruleX),
                case is_conflict (Guards, Subguards) of
                  true  -> false;
                  false ->
                    // here is wrong
                    Subwords = clause (SubruleX, Guards ++ Subguards, Subword, Table, Level)
                end
            end,
          lists:foldl (Horizontal, [ Word ], SubruleY)
        end,
      lists:map (Vertical, Subrules)
  end.

clause ({ Expression, X, Y }, Guards, Word, Table, Level)
  when is_record (Expression, regexp) ->
  % single regular expression
  { Match, X, Y } = Expression#regexp.instance,
  Filters = Expression#regexp.filters,
  Text    = Expression#regexp.expression,
  case rule:match (Word, Filters) of
    false ->
      Args = [ Word, Match, X, Y, Text, length (Guards) ],
      detail (Level, "no match '~s' for ~s (~p,~p): ~s | ~p", Args),
      false;
    { true, Subword, Value } ->
      Args = [ Word, Subword, Match, X, Y, Text, Value, length (Guards) ],
      detail (Level, "match '~s' -> '~s' for ~s (~p,~p): ~s = ~s | ~p", Args),
      Variant = #variant { match    = Match,
                           word_in  = Word,
                           word_out = Subword,
                           value    = Value,
                           guards   = Guards,
                           level    = Level,
                           pos_x    = X,
                           pos_y    = Y,
                           phony    = false },
      ets:insert (Table, Variant),
      Subword
  end;

clause ({ Rule, X, Y }, Guards, Word, Table, Level)
  when is_record (Rule, rule) ->
  % single complex rule
  { Match, X, Y } = Rule#rule.instance,
  Name = Rule#rule.name,
  Variant = #variant { match    = Match,
                       word_in  = Word,
                       word_out = "?",
                       value    = "?",
                       guards   = Guards,
                       level    = Level,
                       pos_x    = X,
                       pos_y    = Y,
                       phony    = true },
  ets:insert (Table, Variant),
  rule (Word, Guards, Name, Table, Level + 1).
  
get_subguards ({ #regexp { instance = { Match, X, Y } }, X, Y }) ->
  model:get_guards (Match, Y);

get_subguards ({ #rule { instance = { Match, X, Y } }, X, Y }) ->
  model:get_guards (Match, Y).

is_conflict (Guards1, Guards2) ->
  Fun2 =
    fun (Guard2) ->
      Fun1 =
        fun
          (Guard1) when Guard1 =/= Guard2 ->
            Entity1 = model:get_entity (Guard1),
            Entity2 = model:get_entity (Guard2),
            Entity1 =:= Entity2;
          (_) -> false
        end,
      lists:any (Fun1, Guards1)
    end,
  lists:any (Fun2, Guards2).

detail (Level, Format, Args) ->
  Message = string:right ("", Level, 32) ++ Format,
  debug:detail (?MODULE, Message, Args).

dump (Table, Level) ->
  Mask    = { '$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8' },
  Entries = ets:select (Table, #variant { match    = '$1',
                                          word_in  = '$2',
                                          word_out = '$3',
                                          value    = '$4',
                                          guards   = '$5',
                                          level    = Level,
                                          pos_x    = '$6',
                                          pos_y    = '$7',
                                          phony    = '$8' }, [], [ Mask ]),  
  case Entries of
    [] -> debug:detail (?MODULE, "--");
    _  ->
      debug:detail (?MODULE, "-- level ~p", [ Level ]),
      Fun =
        fun
          ({ M, WI, WO, V, GS, X, Y, false }) ->
            Format = "~s (~p,~p) = ~s; ~s -> ~s | ~p",
            Args   = [ M, X, Y, V, WI, WO, GS ],
            debug:detail (?MODULE, Format, Args);
          ({ M, WI, _WO, _V, GS, X, Y, true }) ->
            Format = "~s (~p,~p) ~s | ~p",
            Args   = [ M, X, Y, WI, GS ],
            debug:detail (?MODULE, Format, Args)
        end,
      lists:foreach (Fun, Entries)
  end.
