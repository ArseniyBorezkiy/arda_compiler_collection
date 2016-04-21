%% @doc Application user interface.
%% @end
%% @author Arseniy Fedorov <fedoarsen@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (al).

% API
-export ([
          % external interface
          start/1,
          % internal callback
          run/3
         ]).

-include ("general.hrl").

% =============================================================================
% API
% =============================================================================

start ([ Node ]) ->
  Cmd = init:get_plain_arguments (),  
  _Status =
    case parse_command_line (Cmd, []) of
      error -> -4;
      Args  ->
        TargetDir = proplists:get_value (dir, Args, ""),
        TargetIn  = proplists:get_value (input, Args),
        TargetOut = proplists:get_value (output, Args),
        Lucky     = proplists:get_value (lucky, Args, false),
        Verbose   = proplists:get_value (verbose, Args, false),
        case TargetIn  =/= undefined andalso
             TargetOut =/= undefined of
          false ->
            % print usage
            io:format ("Arda lexical compiler ~s. ~n", [ ?VERSION ]),
            io:format ("  Calling format: ~n"),
            io:format ("  $ al [-l] [-v] [-d <path>] -i <file> -o <file> ~n"),
            io:format ("    -l (lucky)   - pick random variants for ambiguities.~n"),
            io:format ("    -v (verbose) - show all nuances for each word.~n"),            
            io:format ("    -i (input)   - input file for compilation.~n"),
            io:format ("    -o (output)  - output file after compilation.~n"),
            io:format ("    -d (dir)     - additional directory prefix~n"),
            io:format ("                   appending to the 'src' and 'dst'~n"),
            io:format ("                   directories respectively~n"),
            io:format ("                   (see al.app file).~n"),
            -3;
          true ->
            % print command line greetings
            Format  = fun (Cmd) -> " " ++ Cmd end,
            io:format ("AL~s~n", [ lists:append (lists:map (Format, Cmd)) ]),
            % call to specified server
            FileIn  = filename:join (TargetDir, TargetIn),
            FileOut = filename:join (TargetDir, TargetOut),
            Options = [ { lucky, Lucky },
                        { verbose, Verbose } ],
            case rpc:call (Node, ?MODULE, run, [ FileIn, FileOut, Options ]) of
              ok -> -0;
              error -> -1;
              { badrpc, _ } ->
                io:format ("! can not connect to server: ~p~n~n", [ Node ]),
                -2
            end
        end
    end,
  init:stop ().

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

run (TargetIn, TargetOut, Options) ->
  dispatcher:compile (TargetIn, TargetOut, Options).

% =============================================================================
% AUXILIARY FUNCTIONS
% =============================================================================

parse_command_line ([], Acc) -> Acc;
parse_command_line ([ "-l" | Tail ], Acc) ->
  Lucky = proplists:property (lucky, true),
  parse_command_line (Tail, [ Lucky | Acc ]);
parse_command_line ([ "-v" | Tail ], Acc) ->
  Verbose = proplists:property (verbose, true),
  parse_command_line (Tail, [ Verbose | Acc ]);
parse_command_line ([ "-i", File | Tail ], Acc) ->
  Input = proplists:property (input, File),
  parse_command_line (Tail, [ Input | Acc ]);
parse_command_line ([ "-o", File | Tail ], Acc) ->
  Output = proplists:property (output, File),
  parse_command_line (Tail, [ Output | Acc ]);
parse_command_line ([ "-d", Path | Tail ], Acc) ->
  Dir = proplists:property (dir, Path),
  parse_command_line (Tail, [ Dir | Acc ]);
parse_command_line ([ Key | _ ], _Acc) ->
  io:format ("Arda lexical compiler ~s. ~n", [ ?VERSION ]),
  io:format ("! undefined option: ~p~n~n", [ Key ]),
  error.
