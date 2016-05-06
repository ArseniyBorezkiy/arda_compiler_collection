%% @doc Lexical analyzers' manager.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (acc_lexer).
-behaviour (gen_acc_lexer).
-behaviour (gen_server).

%
% api
%

-export ([
          % management
          start_link/3,
          register/3,
          unregister/0,
          get_status/0,
          % payload
          include_file/2,
          load_token/2,
          reset_token/2,
          next_token/0,
          next_token/1,
          next_token_type/0,
          save/1
         ]).

%
% gen lexer callbacks
%

-export ([
          success/1,
          error/2
         ]).

%
% gen server callbacks
%

-export ([
          init/1,
          handle_call/3,
          handle_cast/2,
          handle_info/2,
          terminate/2,
          code_change/3
         ]).

%
% headers
%

-include ("general.hrl").

%
% basic types
%

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

register (Loc, FileIn, FileOut)
  when Loc == src; Loc == dst; Loc == lang ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { register, Pid, Loc, FileIn, FileOut }).

unregister () ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { unregister, Pid }).

get_status () ->
  Pid = erlang:self (),
  gen_server:call (?MODULE, { get_status, Pid }).

save (Text) ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { save, Pid, Text }).

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

reset_token (Token, Type) ->
  Pid = erlang:self (),
  gen_server:cast (?MODULE, { token, reset, Pid, Token, Type }).

next_token () ->
  Pid = erlang:self (),
  case gen_server:call (?MODULE, { token, next, Pid }) of
    { error, denied } -> throw (error);
    Result -> Result
  end.

next_token (Type) when is_atom (Type) ->
  case next_token () of
    { Type, Token } -> Token;
    { Other, Token } ->
      ?d_result (?str_al_expected (Token, Type, Other)),
      throw (error)
  end;

next_token (Types) when is_list (Types) ->
  { Type, Token } = next_token (),
  case lists:member (Type, Types) of
    true  -> { Type, Token };
    false ->
      ?d_result (?str_al_expected_any (Token, Types, Type)),
      throw (error)
  end.

next_token_type () ->
  { Type, _Token } = next_token (),
  Type.

% =============================================================================
% GEN LEXER CALLBACKS
% =============================================================================

success (Server) ->
  ?d_section (?str_al_finished (Server)).

error (Server, Message) ->
  ?d_section (?str_al_msg (Message, Server)).

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
        { Server, _FileOut } = dict:fetch (Pid, Dict),
        gen_acc_lexer:next_token (Server);
      false ->
        ?d_error (?str_al_uaccess (Pid)),
        { error, denied }
    end,
  { reply, Result, State };

handle_call ({ get_status, Pid }, _, State) ->
  Dict = State#s.dict,
  Result =
    case dict:is_key (Pid, Dict) of
      true ->
        { Server, _FileOut } = dict:fetch (Pid, Dict),
        gen_acc_lexer:get_status (Server, report);
      false ->
        ?d_error (?str_al_uaccess (Pid)),
        { error, denied }
    end,
  { reply, Result, State }.

handle_cast ({ register, Pid, Loc, FileIn, FileOut }, State) ->
  Dict1 = State#s.dict,
  case dict:is_key (Pid, Dict1) of
    false ->
      Ref            = erlang:make_ref (),
      Name           = erlang:list_to_atom (erlang:ref_to_list (Ref)),
      { ok, Server } = gen_acc_lexer:start_link (Name, ?MODULE),
      Dict2          = dict:store (Pid, { Server, FileOut }, Dict1),
      ?d_detail (?str_al_registered (Pid, Server, FileIn)),
      Dir =
        case Loc of
          src  -> State#s.src;
          dst  -> State#s.dst;
          lang -> State#s.lang
        end,
      gen_acc_lexer:include_file (Server, Dir, FileIn),
      { noreply, State#s { dict = Dict2 } };
    true ->
      ?d_error (?str_al_reauth (Pid, FileIn)),
      { noreply, State }
  end;

handle_cast ({ unregister, Pid }, State) ->
  Dict1 = State#s.dict,
  case dict:is_key (Pid, Dict1) of
    true ->
      { Server, FileOut } = dict:fetch (Pid, Dict1),
      Dict2 = dict:erase (Pid, Dict1),
      gen_acc_lexer:stop (Server),
      ?d_detail (?str_al_unregistered (Pid, Server, FileOut)),
      { noreply, State#s { dict = Dict2 } };
    false ->
      ?d_warning (?str_al_uunregistration (Pid)),
      { noreply, State }
  end;

handle_cast ({ token, load, Pid, Token, Type }, State) ->
  Dict = State#s.dict,
  case dict:is_key (Pid, Dict) of
    true ->
      { Server, _FileOut } = dict:fetch (Pid, Dict),
      gen_acc_lexer:load_token (Server, Token, Type);
    false ->
      ?d_error (?str_al_uaccess (Pid))
  end,
  { noreply, State };

handle_cast ({ token, reset, Pid, Token, Type }, State) ->
  Dict = State#s.dict,
  case dict:is_key (Pid, Dict) of
    true ->
      { Server, _FileOut } = dict:fetch (Pid, Dict),
      gen_acc_lexer:reset_token (Server, Token, Type);
    false ->
      ?d_error (?str_al_uaccess (Pid))
  end,
  { noreply, State };

handle_cast ({ include, Pid, Loc, Name }, State) ->
  Dict = State#s.dict,
  case dict:is_key (Pid, Dict) of
    true ->
      { Server, _FileOut } = dict:fetch (Pid, Dict),
      Dir =
        case Loc of
          src  -> State#s.src;
          dst  -> State#s.dst;
          lang -> State#s.lang
        end,
      gen_acc_lexer:include_file (Server, Dir, Name);
    false ->
      ?d_error (?str_al_uaccess (Pid))
  end,
  { noreply, State };

handle_cast ({ save, Pid, Text }, State) ->
  Dict = State#s.dict,
  case dict:is_key (Pid, Dict) of
    true ->
      { _Server, FileOut } = dict:fetch (Pid, Dict),
      Dir  = State#s.dst,
      Name = filename:join (Dir, FileOut),
      case file:write_file (Name, Text, [ write ]) of
        ok -> ok;
        { error, Reason } ->
          ?d_error (?str_al_notwritable (FileOut, Pid, Reason))
      end;
    false ->
      ?d_error (?str_al_uaccess (Pid))
  end,
  { noreply, State }.
