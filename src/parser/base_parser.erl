%% @doc Basic lexical analyser.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (base_parser).

% API
-export ([
          % supervisor
          start_link/0,
          % user
          include_file/1
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
-type line_t      () :: pos_integer     ().

-record (file_info, { handle :: io_device_t (),
                      line   :: line_t () }).
-type file_info_t () :: #file_info {}.

-record (state, { files :: list (file_info_t ()) }).

% =============================================================================
% API
% =============================================================================

%
% supervisor
%

start_link () ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, [], []).

%
% user
%

include_file (Name) ->
  gen_server:cast (?MODULE, { include, Name }).

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

%
% intialization
%

init ([]) ->
  State = #state { files = [] },
  { ok, State }.

%
% dispatchers
%

handle_call (_, _, State) ->
  { reply, ok, State }.

handle_cast ({ include, Name }, State) ->
  File   = al_db:get_rule (Name),
  Handle =
    case file:open (File, [ read ]) of
      { ok, IoDevice } -> IoDevice;
      Error -> throw ({ path, File, Error })
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

terminate (_Reason, _State) ->
  ok.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

parse_directive (Handle, Line) ->
  case file:read_line (Handle) of
    eof -> Line;
    { ok, Data } ->
      
  end.