%% @doc Flexible debug service.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (debug).

% API
-export ([
          % supervisor
          start_link/1,
          % settings
          set_console_level/1,
          set_log_level/1,
          % print
          log/2,
          log/3
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

% SETTINGS
-define (DL_CONSOLE, 10).
-define (DL_FILE, 10).

% STATE
-type level_t () :: unsigned_t ().

-record (state, { c_level :: level_t (),
                  f_level :: level_t (),
                  handle  :: io_device_t () }).

% =============================================================================
% API
% =============================================================================

%
% supervisor
%

start_link (File) ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, File, []).

%
% settings
%

set_console_level (Level)
  when is_integer (Level), Level >= 0 ->
  gen_server:cast (?MODULE, { c_level, Level }).

set_log_level (Level)
  when is_integer (Level), Level >= 0 ->
  gen_server:cast (?MODULE, { f_level, Level }).

%
% print
%

log (Level, Message)
  when is_integer (Level), Level >= 0 ->
  gen_server:cast (?MODULE, { log, Level, Message }).

log (Level, Format, Args)
  when is_integer (Level), Level >= 0 ->
  Message = lists:flatten (io_lib:format (Format, Args)),
  gen_server:cast (?MODULE, { log, Level, Message }).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

%
% intialization
%

init (File) ->
  process_flag (trap_exit, true),
  { ok, Handle } = file:open (File, [ append ]),
  { ok, #state { c_level = ?DL_CONSOLE, f_level = ?DL_FILE, handle = Handle } }.

%
% dispatchers
%

handle_call (_, _, State) ->
  { reply, ok, State }.

handle_cast ({ c_level, Level }, State) ->
  { noreply, State#state { c_level = Level } };

handle_cast ({ f_level, Level }, State) ->
  { noreply, State#state { f_level = Level } };

handle_cast ({ log, Level, Message }, State) ->
  case Level =< State#state.c_level of
    true  -> io:format ("~p~n", [ Message ]);
    false -> ok
  end,
  Handle = State#state.handle,
  case Level =< State#state.f_level of
    true  -> log_entry (Message, Handle);
    false -> ok
  end,
  { noreply, State };

handle_cast (_, State) ->
  { noreply, State }.

%
% other
%

code_change (_, State, _) ->
  { ok, State }.

handle_info (_Info, State) ->
  { noreply, State }.

terminate (Reason, State) ->
  Handle  = State#state.handle,
  case Reason of
    normal -> ok;
    _ ->
      % crash report
      Message = "! al terminated abnormally.",
      log_entry (Message, Handle)
  end,
  file:close (Handle),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

log_entry (Message, Handle) ->
  Msg = lists:flatten (io_lib:format ("~p~n", [ Message ])),
  file:write (Handle, list_to_binary (Msg)).
