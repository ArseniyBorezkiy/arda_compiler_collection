%% @doc Lexical analyzers' manager.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (lexer).
-behaviour (gen_lexer).
-behaviour (gen_server).

% API
-export ([
          % management
          start_link/0,
          register/0,
          unregister/0,
          % payload
          next_token/0
         ]).

% GEN LEXER CALLBACKS
-export ([
          success/1,
          error/2
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

% HEADERS
-include ("general.hrl").

% STATE
-record (s, { dict :: dict:dict () }).

% =============================================================================
% API
% =============================================================================

start_link () ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, [], []).

register () ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { register, Pid }).

unregister () ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { unregister, Pid }).

next_token () ->
  Pid = erlang:self (),
  case gen_server:call (?MODULE, { token, next, Pid }) of
    { error, denied } -> throw ({ error, ?MODULE });
    Result -> Result
  end.

% =============================================================================
% GEN LEXER CALLBACKS
% =============================================================================

success (Server) ->
  Format = "lexical alasyzer sucessfully finished in ~p",
  debug:log (?DL_SUCCESS, Format, [ Server ]).

error (Server, Message) ->
  Format = "! " ++ Message ++ " by ~p in ~p",
  debug:log (?DL_WARNING, Format, [ Server, ?MODULE ]).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

init ([]) ->
  Dict = dict:new (),
  { ok, #s { dict = Dict } }.

terminate (_, _State) ->
  ok.

handle_info (_, State) ->
  { noreply, State }.

code_change (_, State, _) ->
  { ok, State }.

%
% dispatchers
%

handle_call ({ token, next, Pid }, _, State) ->
  Dict = State#s.dict,
  Result =
    case dict:is_key (Pid, Dict) of
      true ->
        Server = dict:fetch (Pid, Dict),
        gen_lexer:next_token (Server);
      false ->
        debug:log (?DL_WARNING, "! unauthorized access of ~p in ~p", [ Pid, ?MODULE ]),
        { error, denied }
    end,
  { reply, Result, State }.

handle_cast ({ register, Pid }, State) ->
  Dict1 = State#s.dict,
  case dict:is_key (Pid, Dict1) of
    false ->
      Ref    = erlang:make_ref (),
      Name   = erlang:list_to_atom (erlang:ref_to_list (Ref)),
      Server = gen_lexer:start_link (Name, ?MODULE),
      Dict2  = dict:store (Pid, Server, Dict1),
      debug:log (?DL_SUCCESS, "registered ~p as ~p in ~p", [ Pid, Server, ?MODULE ]),
      { noreply, State#s { dict = Dict2 } };
    true ->
      debug:log (?DL_WARNING, "! try to reauthorization of ~p in ~p", [ Pid, ?MODULE ]),
      { noreply, State }
  end;

handle_cast ({ unregister, Pid }, State) ->
  Dict1 = State#s.dict,
  case dict:is_key (Pid, Dict1) of
    true ->
      Server = dict:fetch (Pid, Dict1),
      Dict2  = dict:erase (Pid, Dict1),
      gen_lexer:stop (Server),
      Format = "unregistered ~p that ~p in ~p",
      debug:log (?DL_SUCCESS, Format, [ Pid, Server, ?MODULE ]),
      { noreply, State#s { dict = Dict2 } };
    false ->
      Format = "! unauthorizated unregistration of ~p in ~p",
      debug:log (?DL_WARNING, Format, [ Pid, ?MODULE ]),
      { noreply, State }
  end.