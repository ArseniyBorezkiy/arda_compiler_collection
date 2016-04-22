%% @doc Application supervisor.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al_sup).
-behaviour (supervisor).
-behaviour (application).

% CALLBACKS
-export([
        % application
        start/2,
        stop/1,
        % otp gen supervisor
        init/1
        ]).

% SETTINGS
-define (APP_RESTART_COUNT, 0).
-define (APP_RESTART_INTERVAL, 1000).
-define (SRV_SHUTDOWN_TIME, 3000).

% =============================================================================
% CALLBACKS
% =============================================================================

% APPLICATION
start (_, Args) ->
  start_link (Args).

stop (_) -> ok.

% DIRECT START
start_link (Args) ->
    supervisor:start_link (?MODULE, Args).

% OTP GEN SUPERVISOR
init (Args) ->
  { ok, Dir } = file:get_cwd (),
  Levc = proplists:get_value (log_cl, Args),
  Levf = proplists:get_value (log_fl, Args),
  Log  = filename:join (Dir, proplists:get_value (log, Args)),
  Src  = filename:join (Dir, proplists:get_value (src, Args)),
  Dst  = filename:join (Dir, proplists:get_value (dst, Args)),
  Lang = filename:join (Dir, proplists:get_value (lang, Args)),
  Ref  = proplists:get_value (ref, Args),
  { ok, {{ one_for_one, ?APP_RESTART_COUNT, ?APP_RESTART_INTERVAL }, [
    { debug,
      { debug, start_link, [ Log, Levf, Levc ] },
      transient,
      ?SRV_SHUTDOWN_TIME,
      worker,
      [ debug ] },
    { lexer,
      { lexer, start_link, [ Src, Dst, Lang ] },
      transient,
      ?SRV_SHUTDOWN_TIME,
      worker,
      [ lexer ] },
    { model,
      { model, start_link, [] },
      transient,
      ?SRV_SHUTDOWN_TIME,
      worker,
      [ model ] },
    { dispatcher,
      { dispatcher, start_link, [ Ref ] },
      transient,
      ?SRV_SHUTDOWN_TIME,
      worker,
      [ dispatcher ] }
	] }}.
