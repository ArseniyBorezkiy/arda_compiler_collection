%% Users' requests dispatcher.
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (acc_dispatcher).
-behaviour (gen_server).

%
% api
%

-export ([
          % management
          start_link/1,
          fatal_error/0,
          % payload
          compile/3,
          % internal callbacks
          process/3
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

compile (FileIn, FileOut, Options) ->
  gen_server:call (?MODULE, { compile, FileIn, FileOut, Options }).

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

handle_call ({ compile, FileIn, FileOut, Options }, From, State) ->
  % start and register new process
  Args = [ FileIn, FileOut, Options ],
  { Pid, Ref } = erlang:spawn_monitor (?MODULE, process, Args),
  Dict = dict:store ({ Pid, Ref }, { From, FileIn }, State#s.dict),
  { noreply, State#s { dict = Dict } }.

handle_cast ({ error, fatal }, State) ->
  % normal shutdown
  ?d_error (?str_ad_fatal),
  { stop, normal, State }.

handle_info ({ 'DOWN', Ref, process, Pid, Reason }, State) ->
  % return
  { From, Name } = dict:fetch ({ Pid, Ref }, State#s.dict),  
  case Reason of
    ok -> gen_server:reply (From, ok);
    error ->
      ?d_warning (?str_ad_compile_error (Name, Pid)),
      gen_server:reply (From, error);
    { error, Error } ->
      ?d_error (?str_ad_runtime_error (Name, Pid, Error)),
      gen_server:reply (From, error);
    { result, Result } ->
      ?d_success (?str_ad_dispatched (Name, Pid)),
      gen_server:reply (From, Result)
  end,
  Dict = dict:erase ({ Pid, Ref }, State#s.dict),
  { noreply, State#s { dict = Dict } }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

process (FileIn, FileOut, Options) ->  
  acc_lexer:register (src, FileIn, FileOut),
  ?d_section (?str_ad_compiling (FileIn)),
  Reason =
    try al_sentence:compile (Options) of
      Result ->
        ?d_success (?str_ad_compiled (FileIn)),
        Result
    catch
      throw:_ ->
        Status = acc_lexer:get_status (),
        ?d_warning (?str_ad_not_compiled (FileIn, Status)),
        error;
      _:Error ->
        Status = acc_lexer:get_status (),
        Stack  = erlang:get_stacktrace (),
        ?d_warning (?str_ad_not_compiled (FileIn, Status)),
        { error, { Error, Stack } }
    after
      acc_lexer:unregister ()
    end,
  exit (Reason).

load_grammar (File) ->
  acc_lexer:register (lang, File, File),
  ?d_section (?str_ad_loading (File)),
  try al_language:parse () of
    _ ->
      ?d_success (?str_ad_loaded (File)),
      ok
  catch
    throw:_ ->
      Status = acc_lexer:get_status (),
      ?d_warning (?str_ad_not_loaded (File, Status)),
      error
  after
    acc_lexer:unregister ()
  end.