%% @doc Application supervisor.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (acc_sup).
-behaviour (supervisor).
-behaviour (application).

%
% api
%

-export([
        % application
        start/2,
        stop/1,
        % otp gen supervisor
        init/1
        ]).

%
% headers
%

-include ("general.hrl").

%
% settings
%

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
  Levc   = proplists:get_value (log_cl, Args),
  Levf   = proplists:get_value (log_fl, Args),
  Lang   = proplists:get_value (lang, Args),
  Src    = filename:join (Dir, proplists:get_value (src_dir, Args)),
  Dst    = filename:join (Dir, proplists:get_value (dst_dir, Args)),  
  LogDir = filename:join (Dir, proplists:get_value (log_dir, Args)),
  RefDir = filename:join (Dir, proplists:get_value (ref_dir, Args)),
  Cmd    = init:get_plain_arguments (),
  case parse_command_line (Cmd, []) of
      error -> ignore;
      Options ->
        Abt = proplists:get_value (about, Options, false),
        case proplists:get_value (log, Options) =/= undefined andalso
             proplists:get_value (ref, Options) =/= undefined of
          false when Abt == false ->
            % print usage
            Fun =
              fun ({ L, _ }, Acc) ->
                acc_debug:sprintf ("~s~s ", [ Acc, L ])
              end,
            Languages = lists:foldl (Fun, "", ?languages),
            io:format ("Arda compiler collection server ~p.~p. ~n", [ ?BC_VERSION, ?FC_VERSION ]),
            io:format ("  Calling format: ~n"),
            io:format ("  $ accs [-a] ~n"),
            io:format ("  $ accs -l <file> [-d <dir>] [-i <lang>] -r <file> ~n"),
            io:format ("    -a (about)     - author, license, products links.~n"),
            io:format ("    -l (log)       - log file relative to 'log_dir' (see al.app).~n"),
            io:format ("    -r (reference) - grammar reference relative to <dir> option.~n"),
            io:format ("    -d (dir)       - directory relative to 'ref_dir' (see al.app).~n"),
            io:format ("    -i (interface) - interface language: ~s.~n~n", [ Languages ]),
            ignore;
          false when Abt == true ->
            % print about
            al:about (),
            ignore;
          true ->
            % start server
            RefSubDir = filename:join (RefDir, proplists:get_value (dir, Options)),
            Ref       = filename:join (RefSubDir, proplists:get_value (ref, Options)),
            Log       = filename:join (LogDir, proplists:get_value (log, Options)),
            IfLang    = proplists:get_value (interface, Options, Lang),
            case proplists:get_value (IfLang, ?languages) of
              undefined ->
                io:format ("Arda compiler collection server ~p.~p. ~n", [ ?BC_VERSION, ?FC_VERSION ]),
                io:format ("! unsupported language: ~s~n~n", [ IfLang ]),
                ignore;
              Language ->
                { ok, {{ one_for_one, ?APP_RESTART_COUNT, ?APP_RESTART_INTERVAL }, [
                  { acc_debug,
                    { acc_debug, start_link, [ Log, Levf, Levc, Language ] },
                    transient,
                    ?SRV_SHUTDOWN_TIME,
                    worker,
                    [ acc_debug ] },
                  { acc_lexer,
                    { acc_lexer, start_link, [ Src, Dst, RefSubDir ] },
                    transient,
                    ?SRV_SHUTDOWN_TIME,
                    worker,
                    [ acc_lexer ] },
                  { al_model,
                    { al_model, start_link, [] },
                    transient,
                    ?SRV_SHUTDOWN_TIME,
                    worker,
                    [ al_model ] },
                  { as_model,
                    { as_model, start_link, [] },
                    transient,
                    ?SRV_SHUTDOWN_TIME,
                    worker,
                    [ as_model ] },
                  { acc_dispatcher,
                    { acc_dispatcher, start_link, [ Ref ] },
                    transient,
                    ?SRV_SHUTDOWN_TIME,
                    worker,
                    [ acc_dispatcher ] }
              	] }}
            end
        end
  end.

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

parse_command_line ([], Acc) -> Acc;
parse_command_line ([ "-l", File | Tail ], Acc) ->
  Log = proplists:property (log, File),
  parse_command_line (Tail, [ Log | Acc ]);
parse_command_line ([ "-r", File | Tail ], Acc) ->
  Reference = proplists:property (ref, File),
  parse_command_line (Tail, [ Reference | Acc ]);
parse_command_line ([ "-d", Path | Tail ], Acc) ->
  Dir = proplists:property (dir, Path),
  parse_command_line (Tail, [ Dir | Acc ]);
parse_command_line ([ "-a" | Tail ], Acc) ->
  About = proplists:property (about, true),
  parse_command_line (Tail, [ About | Acc ]);
parse_command_line ([ "-i", Language | Tail ], Acc) ->
  Interface = proplists:property (interface, Language),
  parse_command_line (Tail, [ Interface | Acc ]);
parse_command_line ([ Key | _ ], _Acc) ->
  io:format ("Arda compiler collection server ~p.~p. ~n", [ ?BC_VERSION, ?FC_VERSION ]),
  io:format ("! undefined option: ~p~n~n", [ Key ]),
  error.
