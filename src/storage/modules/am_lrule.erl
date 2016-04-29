%% @doc Dynamically described model's lexical rules module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (am_lrule).
-behaviour (gen_acc_storage).

%
% api
%

-export ([
          create_composite/6,
          create_vocabular/7,
          create_expression/6,
          create_guard/8,
          select_subrules/2,
          select_guards/3
        ]).

%
% gen acc storage callbacks
%

-export ([
          init/0,
          terminate/1
        ]).

%
% headers
%

-include ("general.hrl").
-include ("gen_acc_storage.hrl").
-include ("am_lrule.hrl").

%
% basic types
%

-record (s, { rules  :: tid_t (),
              guards :: tid_t () }).

% =============================================================================
% API
% =============================================================================

-spec create_composite
(
  Server     :: atom (),
  Node       :: string (),
  Name       :: string (),
  X          :: position_t (),
  Y          :: position_t (),
  D          :: direction_t ()
) -> ok.

create_composite (Server, Node, Name, X, Y, D) ->
  ?validate_list (Node),
  ?validate_list (Name),
  ?validate_integer (X, 1),
  ?validate_integer (Y, 1),
  ?validate (D, [ prefix, suffix, postfix ]),
  Key     = #match_k { node = Node, x = X, y = Y },
  Rule    = #crule_v { name = Name },
  Value   = #match_v { dir = D, rule = Rule },
  gen_acc_storage:cast (Server, create_rule, { Key, Value }).

-spec create_vocabular
(
  Server     :: atom (),
  Node       :: string (),
  Name       :: string (),
  Voc        :: string (),
  X          :: position_t (),
  Y          :: position_t (),
  D          :: direction_t ()
) -> ok.

create_vocabular (Server, Node, Name, Voc, X, Y, D) ->
  ?validate_list (Node),
  ?validate_list (Name),
  ?validate_list (Voc),
  ?validate_integer (X, 1),
  ?validate_integer (Y, 1),
  ?validate (D, [ prefix, suffix, postfix ]),
  Key     = #match_k { node = Node, x = X, y = Y },
  Rule    = #vrule_v { name = Name, voc = Voc },
  Value   = #match_v { dir = D, rule = Rule },
  gen_acc_storage:cast (Server, create_rule, { Key, Value }).

-spec create_expression
(
  Server     :: atom (),
  Node       :: string (),
  Expr       :: string (),
  X          :: position_t (),
  Y          :: position_t (),
  D          :: direction_t ()
) -> ok.

create_expression (Server, Node, Expr, X, Y, D) ->
  ?validate_list (Node),
  ?validate_list (Expr),
  ?validate_integer (X, 1),
  ?validate_integer (Y, 1),
  ?validate (D, [ prefix, postfix ]),
  Filters =
    case D of
      prefix  -> al_rule:parse_forward (Expr);
      postfix -> al_rule:parse_backward (Expr)
    end,
  Key     = #match_k { node = Node, x = X, y = Y },
  Rule    = #erule_v { regexp = Expr, filters = Filters },
  Value   = #match_v { dir = D, rule = Rule },
  gen_acc_storage:cast (Server, create_rule, { Key, Value }).

-spec create_guard
(
  Server     :: atom (),
  Node       :: string (),
  Name       :: string (),
  Base       :: string (),
  Type       :: string (),
  X          :: position_t (),
  Y          :: position_t (),
  S          :: sign_t ()
) -> ok.

create_guard (Server, Node, Name, Base, Type, X, Y, S) ->
  ?validate_list (Node),
  ?validate_list (Name),
  ?validate_list (Base),
  ?validate_list (Type),
  ?validate_integer (X, 1),
  ?validate_integer (Y, 1),
  ?validate (S, [ positive, negative ]),
  Key     = #match_k { node = Node, x = X, y = Y },
  Value   = #guard_v { sign = S, type = Type, base = Base, name = Name },
  gen_acc_storage:cast (Server, create_guard, { Key, Value }).

-spec select_subrules
(
  Server     :: atom (),
  Node       :: string ()
) -> list (gas_entry_t ()).

select_subrules (Server, Node) ->
  ?validate_list (Node),
  Key   = #match_k { node = Node, x = '_', y = '$1' },
  Value = #match_v { dir = '_', rule = '_' },
  YL    = gen_acc_storage:call (Server, select_rule, { Key, Value, '$1' }),
  YS    = sets:to_list (sets:from_list (YL)),
  Fun   =
    fun (Y) ->
      KeyY      = #match_k { node = Node, x = '_', y = Y },
      Entries1  = gen_acc_storage:call (Server, select_rule, { KeyY, Value }),
      Separator =
        fun (D1) ->
          fun (#gas_entry { v = #match_v { dir = D2 } }) ->
            D2 =:= D1
          end
        end,
      Comparator =
        fun (Order) ->
          fun (#gas_entry { k = #match_k { x = X1 }},
               #gas_entry { k = #match_k { x = X2 }}) ->
            Order (X1, X2)
          end
        end,
      Inc = fun (X1, X2) -> X1 < X2 end,
      Dec = fun (X1, X2) -> X1 > X2 end,
      { Prefix, Entries2 } = lists:partition (Separator (prefix), Entries1),
      { Postfix, Suffix }  = lists:partition (Separator (postfix), Entries2),
      List =
        lists:sort (Comparator (Inc), Prefix) ++
        lists:sort (Comparator (Dec), Postfix) ++
        lists:sort (Comparator (Inc), Suffix),
      List
    end,
  SortYS = fun (Y1, Y2) -> Y1 < Y2 end,
  lists:map (Fun, lists:sort (SortYS, YS)).

-spec select_guards
(
  Server     :: atom (),
  Node       :: string (),
  Y          :: position_t ()
) -> list (gas_entry_t ()).

select_guards (Server, Node, Y) ->
  ?validate_list (Node),
  ?validate_integer (Y, 1),
  Key     = #match_k { node = Node, x = '_', y = Y },
  Value   = #guard_v { sign = '_', type = '_', name = '_' },
  gen_acc_storage:call (Server, select_guard, { Key, Value }).

% =============================================================================
% GEN ACC STORAGE CALLBACKS
% =============================================================================

%
% prologue and epilogue
%

init () ->
  State = #s { rules  = gen_acc_storage:create_table (?MODULE, set),
               guards = gen_acc_storage:create_table (?MODULE, bag) },
  Handlers = [ { select_rule,  fun handle_lrule_select_rule/2 },
               { select_guard, fun handle_lrule_select_guard/2 },
               { create_rule,  fun handle_lrule_create_rule/2 },
               { create_guard, fun handle_lrule_create_guard/2 } ],
  { ok, State, Handlers }.

terminate (_State) ->
  ok.

%
% dispatchers - rule
%

handle_lrule_create_rule ({ Key, Value }, #s { rules = Table } = State) ->
  try
    gen_acc_storage:insert_once (Table, Key, Value),
    { noreply, State }
  catch
    throw : ?e_key_exists (_) ->
      { fatalize, ?str_amlr_redefine (Key#match_k.node) }
  end.

handle_lrule_select_rule ({ Key, Value, Out }, #s { rules = Table } = State) ->
  Elements = gen_acc_storage:select_element (Table, Key, Value, Out),
  { reply, Elements, State };

handle_lrule_select_rule ({ Key, Value }, #s { rules = Table } = State) ->
  Entries = gen_acc_storage:select (Table, Key, Value),
  { reply, Entries, State }.

%
% dispatchers - guard
%

handle_lrule_create_guard ({ Key, Value }, #s { guards = Table } = State) ->
  gen_acc_storage:insert (Table, Key, Value),
  { noreply, State }.

handle_lrule_select_guard ({ Key, Value }, #s { guards = Table } = State) ->
  Entries = gen_acc_storage:select (Table, Key, Value),
  { reply, Entries, State }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================
