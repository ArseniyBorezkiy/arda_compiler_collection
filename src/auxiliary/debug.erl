%% @doc Flexible debug service.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (debug).

% API
-export ([
          % supervisor
          start_link/3,
          % settings
          set_console_level/1,
          set_log_level/1,
          % print
          log/3,
          log/4,
          error/2,
          error/3,
          warning/2,
          warning/3,
          result/2,
          result/3,
          detail/2,
          detail/3,
          section/2,
          section/3,
          success/2,
          success/3
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

start_link (File, Levf, Levc) ->
  Args = { File, Levf, Levc },
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, Args, []).

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
% low level api
%

log (Module, Level, Message)
  when is_integer (Level), Level >= 0 ->
  gen_server:cast (?MODULE, { log, Module, Level, Message }).

log (Module, Level, Format, Args)
  when is_integer (Level), Level >= 0 ->
  Message = lists:flatten (io_lib:format (Format, Args)),
  log (Module, Level, Message).

%
% high level api
%

error (Module, Message) ->
  log (Module, ?DL_ERROR, Message).

error (Module, Format, Args) ->
  log (Module, ?DL_ERROR, Format, Args).

warning (Module, Message) ->
  log (Module, ?DL_WARNING, Message).

warning (Module, Format, Args) ->
  log (Module, ?DL_WARNING, Format, Args).

result (Module, Message) ->
  log (Module, ?DL_RESULT, Message).

result (Module, Format, Args) ->
  log (Module, ?DL_RESULT, Format, Args).

detail (Module, Message) ->
  log (Module, ?DL_DETAIL, Message).

detail (Module, Format, Args) ->
  log (Module, ?DL_DETAIL, Format, Args).

section (Module, Message) ->
  log (Module, ?DL_SECTION, Message).

section (Module, Format, Args) ->
  log (Module, ?DL_SECTION, Format, Args).
 
success (Module, Message) ->
  log (Module, ?DL_SUCCESS, Message).

success (Module, Format, Args) ->
  log (Module, ?DL_SUCCESS, Format, Args).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

%
% intialization
%

init ({ File, Levf, Levc }) ->
  process_flag (trap_exit, true),
  { ok, Handle } = file:open (File, [ append ]),
  { Year, Month, Day } = erlang:date (),
  { Hour, Min, Sec }   = erlang:time(),
  Format  = "~p.~p.~p at ~p:~p:~p",
  Args    = [ Day, Month, Year, Hour, Min, Sec ],
  log_entry (Handle, "~n*** ", ?MODULE, "al started " ++ Format, Args),
  { ok, #state { c_level = Levc, f_level = Levf, handle = Handle } }.

%
% dispatchers
%

handle_call (_, _, State) ->
  { reply, ok, State }.

handle_cast ({ c_level, Level }, State) ->
  { noreply, State#state { c_level = Level } };

handle_cast ({ f_level, Level }, State) ->
  { noreply, State#state { f_level = Level } };

handle_cast ({ log, Module, Level, Message }, State) ->
  Prefix =
    case Level of
      ?DL_ERROR   -> "!!! ";
      ?DL_WARNING -> "! ";
      ?DL_SUCCESS -> "* ";
      _ -> ""
    end,
  case Level =< State#state.c_level of
    true  -> io:format ("~s~p: ~s.~n", [ Prefix, Module, Message ]);
    false -> ok
  end,
  Handle = State#state.handle,
  case Level =< State#state.f_level of
    true  -> log_entry (Handle, Prefix, Module, Message, []);
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
  Handle = State#state.handle,
  { Year, Month, Day } = erlang:date (),
  { Hour, Min, Sec }   = erlang:time(),
  Format  = "~p.~p.~p at ~p:~p:~p",
  Args    = [ Day, Month, Year, Hour, Min, Sec ],
  case Reason of
    normal ->
      Message = "al normally shutdowned " ++ Format,
      log_entry (Handle, "*** ", ?MODULE, Message, Args);
    _ ->
      Message = "al terminated abnormally " ++ Format,
      log_entry (Handle, "!!! ", ?MODULE, Message, Args)
  end,
  file:close (Handle),
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

log_entry (Handle, Prefix, Module, Message, Args) ->
  Format = Prefix ++ "~p: " ++ Message ++ ".~n",
  Text   = lists:flatten (io_lib:format (Format, [ Module | Args ])),
  file:write (Handle, list_to_binary (Text)).
