%% @doc Application supervisor.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
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
start (_, [ LogName ]) ->
  start_link([ LogName ]).
stop (_) -> ok.

% DIRECT START
start_link (Args) ->
    supervisor:start_link(?MODULE, Args).

% OTP GEN SUPERVISOR
init ([ LogName ]) ->
  { ok, Cwd } = file:get_cwd (),
  LogFile = filename:join (Cwd, LogName),
  { ok, {{ one_for_one, ?APP_RESTART_COUNT, ?APP_RESTART_INTERVAL }, [
    { debug,
      { debug, start_link, [ LogFile ] },
      transient,
      ?SRV_SHUTDOWN_TIME,
      worker,
      [ debug ]},
    { lexer,
      { lexer, start_link, [] },
      transient,
      ?SRV_SHUTDOWN_TIME,
      worker,
      [ lexer ]}
	] }}.
