%% @doc Generic lexical analyzer.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (gen_lexer).
-behaviour (gen_server).

% API
-export ([
          % management
          start_link/2,
          stop/1,
          behaviour_info/1,
          get_status/2,
          % payload
          include_file/3,
          load_token/3,
          reset_token/3,
          next_token/1
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
-include ("token.hrl").

% STATE
-record (file_entry, { dir         :: string (),
                       name        :: string (),
                       handle      :: io_device_t (),
                       line   = 1  :: position_t (),
                       column = 1  :: position_t () }).

-type file_entry_t () :: # file_entry { }.

-record (token, { name :: string (),
                  type :: string () }).

-type token_t () :: # token { }.

-record (s, { module  :: atom (),
              server  :: atom (),
              status  :: term (),
              break   :: string (),
              table   :: ets:tid (token_t ()),
              entries :: list (file_entry_t ()) }).

% =============================================================================
% API
% =============================================================================

%
% management
%

start_link (Server, Module) ->
  gen_server:start_link ({ local, Server }, ?MODULE, { Module, Server }, []).

stop (Server) ->
  gen_server:stop (Server).

behaviour_info (callbacks) ->
  [ { error, 2 },
    { success, 1 } ];

behaviour_info (_) -> undefined.

get_status (Server, Variant)
  when Variant == summary ; Variant == report ->
  gen_server:call (Server, { get_status, Variant }).

%
% payload
%

include_file (Server, Dir, Name)
  when is_list (Dir), is_list (Name) ->
  gen_server:cast (Server, { include, Dir, Name }).

load_token (Server, Token, Type)
  when is_list (Token) ->
  gen_server:cast (Server, { token, load, Token, Type }).

reset_token (Server, Token, Type)
  when is_list (Token) ->
  gen_server:cast (Server, { token, reset, Token, Type }).

next_token (Server) ->
  case gen_server:call (Server, { token, next }) of
    { ?TT_DEFAULT, "" } -> next_token (Server);
    { Type, Token } -> { Type, Token };
    eot -> { ?TT_EOT, "" }
  end.

% =============================================================================
% GEN SERVER CALLBACKS
% =============================================================================

init ({ Module, Server }) ->
  process_flag (trap_exit, true),
  Table = ets:new ('token storage', [ set, private ]),
  State = #s { module  = Module,
               server  = Server,
               break   = undefined,
               table   = Table,
               status  = ok,
               entries = [] },
  { ok, State }.

terminate (_, State) ->
  Close =
    fun
      (undefined) -> ok;
      (Handle) -> file:close (Handle)
    end,
  lists:foreach (Close, State#s.entries),
  ok.

handle_info (_, State) ->
  { noreply, State }.

code_change (_, State, _) ->
  { ok, State }.

%
% dispatchers
%

handle_call ({ get_status, Variant }, _, State) ->
  case State#s.entries of
    [] -> { reply, "end of text", State };
    [ Active | _ ] ->
      Dir    = Active#file_entry.dir,
      Name   = Active#file_entry.name,
      Line   = Active#file_entry.line,
      Column = Active#file_entry.column,
      { Status, Error } =
        case State#s.status of
          ok -> { "", "" };
          { error, Message }  -> { "error ", format ("~n" ++ Message, []) }
        end,
      Result =
        case Variant of
          summary ->
            Format = "~sin ~s (line: ~p, column: ~p)~n",
            Args   = [ Status, Name, Line, Column ],
            format (Format, Args);
          report ->
            Format = "~sin ~s (line: ~p, column: ~p)~n"
                     "dir: ~s"
                     "~s",
            Args   = [ Status, Name, Line, Column, Dir, Error ],
            format (Format, Args)
        end,
      { reply, Result, State }
  end;

handle_call ({ token, next }, _, #s { break = Break } = State)
  when Break =/= undefined ->
  { reply, { ?TT_BREAK, Break }, State#s { break = undefined }};

handle_call ({ token, next }, _, State) ->
  Entries = State#s.entries,
  Module  = State#s.module,
  { Result, NewState } =
    case Entries of
      [] ->
        Module:success (State#s.server),
        { eot, State };
      [ Active | Tail ] ->
        Handle    = Active#file_entry.handle,
        Line      = Active#file_entry.line,
        Column    = Active#file_entry.column,
        Table     = State#s.table,
        Splitters = ets:select (Table, [{ { '$1', ?TT_SEPARATOR } , [], ['$1'] }]),
        Breaks    = ets:select (Table, [{ { '$1', ?TT_BREAK } , [], ['$1'] }]),
        { Data, NewLine, NewColumn, Break } = parse (Handle, Table, Line, Column, Splitters, Breaks, ""),
        NewActive = Active#file_entry { line = NewLine, column = NewColumn },
        case Data of
          { ok, Token, Type } when Break =:= undefined ->
            { { Type, Token }, State#s { entries = [ NewActive | Tail ] }};
          { ok, Token, Type } when Break =/= undefined ->
            { { Type, Token }, State#s { entries = [ NewActive | Tail ], break = Break }};
          { eof, Token, Type } ->
            { { Type, Token }, State#s { entries = Tail } };
          { error, ambiguity } ->
            Error = format ("splitters ambiguity ~p", [ Splitters ]),
            Module:error (State#s.server, Error),
            { eot, State#s { status = { error, Error } } };
          { error, file } ->
            Error = format ("can not read from stream", []),
            Module:error (State#s.server, Error),
            { eot, State#s { status = { error, Error } } }
        end
    end,
  { reply, Result, NewState }.

handle_cast ({ token, load, Token, Type }, State) ->
  Table = State#s.table,
  case ets:lookup (Table, Token) of
    [] ->
      ets:insert (Table, { Token, Type }),
      { noreply, State };
    [ { Token, OtherType } | _ ] ->
      Format = "token redefinition ~p of type ~p to type ~p",
      Error  = format (Format, [ Token, Type, OtherType ]),
      Module = State#s.module,
      Module:error (State#s.server, Error),
      { noreply, State }
  end;  

handle_cast ({ token, reset, Token, Type }, State) ->
  Table = State#s.table,
  case ets:lookup (Table, Token) of
    [] ->
      Format = "token ~p of type ~p not found to be reset",
      Error  = format (Format, [ Token, Type ]),
      Module = State#s.module,
      Module:error (State#s.server, Error),      
      { noreply, State };
    [ { Token, Type } | _ ] ->
      ets:delete (Table, Token),
      { noreply, State };
    [ { Token, OtherType } | _ ] ->
      Format = "token ~p of type ~p to be reset cause has type ~p",
      Error  = format (Format, [ Token, Type, OtherType ]),
      Module = State#s.module,
      Module:error (State#s.server, Error), 
      { noreply, State }
  end;  

handle_cast ({ include, Dir, Name }, State) ->
  File = filename:join (Dir, Name),
  { Handle, Status } =
    case file:open (File, [ read ]) of
      { ok, IoDevice } -> { IoDevice, State#s.status };
      _ ->
        Format = "can not open file: ~p",
        Error  = format (Format, [ File ]),
        Module = State#s.module,
        Module:error (State#s.server, Error),
        { undefined, { error, Error } }
    end,
  Entry   = #file_entry { dir = Dir, name = Name, handle = Handle },
  Entries = [ Entry | State#s.entries ],
  { noreply, State#s { entries = Entries, status = Status } }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================

format (Format, Args) ->
  lists:flatten (io_lib:format (Format, Args)).

parse (Handle, Table, Line, Column, Splitters, Breaks, Token) ->
  case file:read (Handle, 1) of
    { ok, Char } ->
      NewToken = Token ++ Char,
      % synchronization
      { NewLine, NewColumn } =
        case Char of
          "\n" -> { Line + 1, 1 };
          _ -> { Line, Column + 1 }
        end,
      case Char of
        "\"" ->
          read_string (Handle, Line, Column, "");
        _ ->
          % check for splitters
          Fun =
            fun (Splitter) ->
              case string:rstr (NewToken, Splitter) of
                0 -> false;
                N -> { true, N }
              end
            end,
          { TargetToken, Splitter, IsSplitted, IsAmbiguity } =
            case lists:filtermap (Fun, Splitters ++ Breaks) of
              [] -> { NewToken, "", false, false };
              [ N ] -> { string:sub_string (NewToken, 1, N - 1), string:substr (NewToken, N), true, false };
              [ _ | _ ] -> { NewToken, "", false, true }
            end,      
          % check for ambiguity
          case IsAmbiguity of
            true  -> { error, ambiguity };
            false ->
              case IsSplitted of
                false -> parse (Handle, Table, NewLine, NewColumn, Splitters, Breaks, TargetToken);
                true  ->
                  % find lexem
                  IsBreak = lists:member (Splitter, Breaks),
                  BreakInfo =
                    case IsBreak of
                      false -> undefined;
                      true  -> Splitter
                    end,
                  case ets:lookup (Table, TargetToken) of
                    [] -> {{ ok, TargetToken, ?TT_DEFAULT }, NewLine, NewColumn, BreakInfo };
                    [ { TargetToken, TokenType } ] -> {{ ok, TargetToken, TokenType }, NewLine, NewColumn, BreakInfo }
                  end
              end
          end
      end;
    eof ->
      % find lexem
      Type =
        case ets:lookup (Table, Token) of
          [] -> ?TT_DEFAULT;
          [ { Token, TokenType } ] -> TokenType
        end,
      {{ eof, Token, Type }, Line, Column, undefined };
    { error, _ } -> {{ error, file }, Line, Column, undefined }
  end.

read_string (Handle, Line, Column, String) ->
  case file:read (Handle, 1) of
    { ok, "\"" } -> {{ ok, String, ?TT_STRING }, Line, Column + 1, undefined };
    { ok, "\n" } -> read_string (Handle, Line + 1, 1, String ++ "\n");
    { ok, Char } -> read_string (Handle, Line, Column + 1, String ++ Char);
    eof -> {{ ok, String, ?TT_STRING }, Line, Column, undefined };
    { error, _ } -> {{ error, file }, Line, Column, undefined }
  end.
