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
          start_link/3,
          register/2,
          unregister/0,
          get_status/0,
          % payload
          include_file/2,
          load_token/2,
          next_token/0,
          next_token/1,
          next_token_type/0
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
-record (s, { dict :: dict:dict (),
              src  :: string (),
              dst  :: string (),
              lang :: string () }).

% =============================================================================
% API
% =============================================================================

%
% management
%

start_link (Src, Dst, Lang) ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, { Src, Dst, Lang }, []).

register (Loc, File)
  when Loc == src; Loc == dst; Loc == lang ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { register, Pid, Loc, File }).

unregister () ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { unregister, Pid }).

get_status () ->
  Pid = erlang:self (),
  gen_server:call (?MODULE, { get_status, Pid }).

%
% payload
%

include_file (Loc, Name)
  when Loc == src; Loc == dst; Loc == lang ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { include, Pid, Loc, Name }).

load_token (Token, Type) ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { token, load, Pid, Token, Type }).

next_token () ->
  Pid = erlang:self (),
  case gen_server:call (?MODULE, { token, next, Pid }) of
    { error, denied } -> throw (error);
    Result -> Result
  end.

next_token (Type) ->
  case next_token () of
    { Type, Token } -> Token;
    { Other, Token } ->
      Format = "expected token '~s' of type '~p' instead of '~p'",
      debug:result (?MODULE, Format, [ Token, Type, Other ]),
      throw (error)
  end.

next_token_type () ->
  { Type, _Token } = next_token (),
  Type.

% =============================================================================
% GEN LEXER CALLBACKS
% =============================================================================

success (Server) ->
  debug:section (?MODULE, "lexical alasyzer sucessfully finished in ~p", [ Server ]).

error (Server, Message) ->
  debug:section (?MODULE, "~s in ~p", [ Message, Server ]).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

init ({ Src, Dst, Lang }) ->
  Dict = dict:new (),
  { ok, #s { dict = Dict, src = Src, dst = Dst, lang = Lang } }.

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
        debug:error (?MODULE, "unauthorized access of ~p", [ Pid ]),
        { error, denied }
    end,
  { reply, Result, State };

handle_call ({ get_status, Pid }, _, State) ->
  Dict = State#s.dict,
  Result =
    case dict:is_key (Pid, Dict) of
      true ->
        Server = dict:fetch (Pid, Dict),
        gen_lexer:get_status (Server, report);
      false ->
        debug:error (?MODULE, "unauthorized access of ~p", [ Pid ]),
        { error, denied }
    end,
  { reply, Result, State }.

handle_cast ({ register, Pid, Loc, File }, State) ->
  Dict1 = State#s.dict,
  case dict:is_key (Pid, Dict1) of
    false ->
      Ref            = erlang:make_ref (),
      Name           = erlang:list_to_atom (erlang:ref_to_list (Ref)),
      { ok, Server } = gen_lexer:start_link (Name, ?MODULE),
      Dict2          = dict:store (Pid, Server, Dict1),
      debug:detail (?MODULE, "registered ~p as ~p for ~p", [ Pid, Server, File ]),
      Dir =
        case Loc of
          src  -> State#s.src;
          dst  -> State#s.dst;
          lang -> State#s.lang
        end,
      gen_lexer:include_file (Server, Dir, File),
      { noreply, State#s { dict = Dict2 } };
    true ->
      debug:error (?MODULE, "try to reauthorization of ~p for ~p", [ Pid, File ]),
      { noreply, State }
  end;

handle_cast ({ unregister, Pid }, State) ->
  Dict1 = State#s.dict,
  case dict:is_key (Pid, Dict1) of
    true ->
      Server = dict:fetch (Pid, Dict1),
      Dict2  = dict:erase (Pid, Dict1),
      gen_lexer:stop (Server),
      debug:detail (?MODULE, "unregistered ~p that ~p", [ Pid, Server ]),
      { noreply, State#s { dict = Dict2 } };
    false ->
      debug:warning (?MODULE, "unauthorizated unregistration of ~p", [ Pid ]),
      { noreply, State }
  end;

handle_cast ({ token, load, Pid, Token, Type }, State) ->
  Dict = State#s.dict,
  case dict:is_key (Pid, Dict) of
    true ->
      Server = dict:fetch (Pid, Dict),
      gen_lexer:load_token (Server, Token, Type);
    false ->
      debug:error (?MODULE, "unauthorized access of ~p", [ Pid ])
  end,
  { noreply, State };

handle_cast ({ include, Pid, Loc, Name }, State) ->
  Dict = State#s.dict,
  case dict:is_key (Pid, Dict) of
    true ->
      Server = dict:fetch (Pid, Dict),
      Dir =
        case Loc of
          src  -> State#s.src;
          dst  -> State#s.dst;
          lang -> State#s.lang
        end,
      gen_lexer:include_file (Server, Dir, Name);
    false ->
      debug:error (?MODULE, "unauthorized access of ~p", [ Pid ])
  end,
  { noreply, State }.