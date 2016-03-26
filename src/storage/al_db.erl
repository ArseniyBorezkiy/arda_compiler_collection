%% @doc Database.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_db).

% API
-export ([
          start_link/3,
          % configuration
          set_target_file/1,
          get_target_file/1,
          get_rule_file/1
         ]).

% GEN SERVER CALLBACKS
-export ([
          init/1,
          handle_call/3,
          handle_cast/2,
          handle_info/2,
          terminate/2,
          code_change/3
         ]).

% STATE
-record (state, { dict }).

% =============================================================================
% API
% =============================================================================

%
% supervisor
%

start_link (SrcDir, DstDir, RuleDir) ->
  Pairs = [ { src_dir,  SrcDir },
            { dst_dir,  DstDir },
            { rule_dir, RuleDir } ],
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, Pairs, []).

%
% configuration
%

set_target_file (Name) ->
  Pairs = [ { target, Name } ],
  gen_server:cast (?MODULE, { dict, set, Pairs }).

get_target_file (Direction)
  when Direction == in orelse Direction == out ->
  Key =
    case Direction of
      in  -> src_dir;
      out -> dst_dir
    end,
  Target = gen_server:call (?MODULE, { dict, get, target }),
  Dir    = gen_server:call (?MODULE, { dict, get, Key }),
  filename:join (Dir, Target).

get_rule_file (Name) ->
  RuleDir = gen_server:call (?MODULE, { dict, get, rule_dir }),
  filename:join (RuleDir, Name).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

%
% intialization
%

init (Pairs) ->
  Fun   = fun ({ K, V }, D) -> dict:store (K, V, D) end,
  Dict1 = dict:new (),
  Dict2 = lists:foldl (Fun, Dict1, Pairs),
  { ok, #state { dict = Dict2 } }.

%
% dispatchers
%

handle_call ({ dict, get, Key }, _, State) ->
  Dict  = State#state.dict,
  Value = dict:fetch (Key, Dict),
  { reply, Value, State };

handle_call (_, _, State) ->
  { reply, ok, State }.

handle_cast ({ dict, set, Pairs }, State) ->
  Fun   = fun ({ K, V }, D) -> dict:store (K, V, D) end,
  Dict1 = State#state.dict,
  Dict2 = lists:foldl (Fun, Dict1, Pairs),
  { noreply, State#state { dict = Dict2 } };

handle_cast (_, State) ->
  { noreply, State }.

%
% other
%

code_change (_, State, _) ->
  { ok, State }.

handle_info (_Info, State) ->
  { noreply, State }.

terminate (_Reason, _State) ->
  ok.