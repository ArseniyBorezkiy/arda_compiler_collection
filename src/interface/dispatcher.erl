%% Users' requests dispatcher.
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (dispatcher).
-behaviour (gen_server).

% API
-export ([
          % management
          start_link/1,
          fatal_error/0,
          % payload
          compile/1,
          % internal callbacks
          process/1
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
-record (s, { dict :: dict:dict () }).

% =============================================================================
% API
% =============================================================================

%
% management
%

start_link (Ref) ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, Ref, []).

fatal_error () ->
  gen_server:cast (?MODULE, { error, fatal }).

%
% payload
%

compile (File) ->
  gen_server:call (?MODULE, { compile, File }).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

init (Ref) ->
  process_flag (trap_exit, true),
  Dict  = dict:new (),
  State = #s { dict = Dict },
  case load_grammar (Ref) of
    ok -> { ok, State };
    error -> { stop, shutdown }
  end.

terminate (_, _State) ->
  ok.

code_change (_, State, _) ->
  { ok, State }.

%
% dispatchers
%

handle_call ({ compile, File }, From, State) ->
  % start and register new process
  { Pid, Ref } = erlang:spawn_monitor (?MODULE, process, [ File ]),
  Dict = dict:store ({ Pid, Ref }, { From, File }, State#s.dict),
  { noreply, State#s { dict = Dict } }.

handle_cast ({ error, fatal }, State) ->
  % normal shutdown
  debug:error (?MODULE, "fatal error"),
  { stop, normal, State }.

handle_info ({ 'DOWN', Ref, process, Pid, Reason }, State) ->
  % return
  { From, Name } = dict:fetch ({ Pid, Ref }, State#s.dict),  
  case Reason of
    error ->
      debug:warning (?MODULE, "~p error in ~p", [ Name, Pid ]),
      gen_server:reply (From, error);
    { error, Error } ->
      debug:error (?MODULE, "~p error in ~p: ~p", [ Name, Pid, Error ]),
      gen_server:reply (From, error);
    { result, Result } ->
      debug:success (?MODULE, "~p dispatched in ~p", [ Name, Pid ]),
      gen_server:reply (From, Result)
  end,
  Dict = dict:erase ({ Pid, Ref }, State#s.dict),
  { noreply, State#s { dict = Dict } }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

process (File) ->  
  lexer:register (src, File),
  debug:section (?MODULE, "compiling ~p", [ File ]),
  Reason =
    try sentence:compile () of
      Result ->
        debug:success (?MODULE, "compilation finished for ~p", [ File ]),
        Result
    catch
      throw:_ ->
        Status = lexer:get_status (),
        debug:warning (?MODULE, "compilation failed for ~p~n~s", [ File, Status ]),
        error;
      error:Error ->
        Status = lexer:get_status (),
        Stack  = erlang:get_stacktrace (),
        debug:warning (?MODULE, "compilation failed for ~p~n~s", [ File, Status ]),
        { error, { Error, Stack } }
    after
      lexer:unregister ()
    end,
  exit (Reason).

load_grammar (File) ->
  lexer:register (lang, File),
  debug:section (?MODULE, "loading grammar reference: ~p", [ File ]),
  try language:parse () of
    _ ->
      debug:success (?MODULE, "grammar reference loaded: ~p", [ File ]),
      ok
  catch
    throw:_ ->
      Status = lexer:get_status (),
      debug:warning (?MODULE, "error in grammar reference: ~p~n~s", [ File, Status ]),
      error
  after
    lexer:unregister ()
  end.