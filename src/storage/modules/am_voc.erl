%% @doc Dynamically described model's vocabulary module.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-module (am_voc).
-behaviour (gen_acc_storage).

%
% api
%

-export ([
          create_vocabulary/2,
          select_vocabularies/1,
          create_stem/4,
          find_stem/3,
          select_stems/4
        ]).

%
% gen acc storage callbacks
%

-export ([
          init/0,
          terminate/1
        ]).

%
% headers
%

-include ("general.hrl").
-include ("gen_acc_storage.hrl").
-include ("am_voc.hrl").

%
% basic types
%

-record (s, { tables :: dict_t (string (), tid_t ()) }).

% =============================================================================
% API
% =============================================================================

-spec create_vocabulary
(
  Server     :: atom (),
  Voc        :: string ()
) -> ok.

create_vocabulary (Server, Voc) ->
  ?validate_list (Voc),
  gen_acc_storage:cast (Server, create_voc, { Voc }).

-spec select_vocabularies
(
  Server     :: atom ()
) -> list (Voc :: string ()).

select_vocabularies (Server) ->
  gen_acc_storage:call (Server, select_voc, { }).

-spec create_stem
(
  Server     :: atom (),
  Voc        :: string (),
  Stem       :: string (),
  Guards     :: list (guard_v_t ())
) -> ok.

create_stem (Server, Voc, Stem, Guards) ->
  ?validate_list (Voc),
  ?validate_list (Stem),
  ?validate_record_list (Guards, guard_v),
  Key   = #stem_k { voc = Voc, stem = Stem },
  Value = #stem_v { guards = Guards },
  gen_acc_storage:cast (Server, create_stem, { Key, Value }).

-spec find_stem
(
  Server     :: atom (),
  Voc        :: string (),
  Stem       :: string ()
) -> false | { true, stem_v_t () }.

find_stem (Server, Voc, Stem) ->
  ?validate_list (Voc),
  ?validate_list (Stem),
  Key = #stem_k { voc = Voc, stem = Stem },
  gen_acc_storage:call (Server, find_stem, { Key }).

-spec select_stems
(
  Server     :: atom (),
  Voc        :: string (),
  Word       :: string (),
  Direction  :: direction_t ()
) -> list (gas_entry_t ()).

select_stems (Server, Voc, Word, Direction) ->
  ?validate_list (Voc),
  ?validate_list (Word),
  ?validate (Direction, [ prefix, postfix ]),
  Key    = #stem_k { voc = Voc, stem = '_' },
  Value  = #stem_v { guards = '_' },
  Filter =
    fun
      (#gas_entry { k = #stem_k { stem = Stem }})
        when Direction == prefix ->
          case string:str (Word, Stem) of
            1 -> true;
            _ -> false
          end;
       (#gas_entry { k = #stem_k { stem = Stem }})
        when Direction == postfix ->
          Pos = length (Word) - length (Stem) + 1,
          case string:rstr (Word, Stem) of
            Pos when Pos > 0 -> true;
            _ -> false
          end
    end,
  gen_acc_storage:call (Server, select_stem, { Key, Value, Filter }).

% =============================================================================
% GEN ACC STORAGE CALLBACKS
% =============================================================================

%
% prologue and epilogue
%

init () ->
  State = #s { tables = dict:new () },
  Handlers = [ { create_voc, fun handle_voc_create_voc/2 },
               { select_voc, fun handle_voc_select_voc/2 },
               { create_stem, fun handle_voc_create_stem/2 },
               { find_stem, fun handle_voc_find_stem/2 },
               { select_stem, fun handle_voc_select_stem/2 } ],
  { ok, State, Handlers }.

terminate (_State) ->
  ok.

%
% dispatchers - voc
%

handle_voc_create_voc ({ Voc }, #s { tables = Dict1 } = State) ->
  Table = gen_acc_storage:create_table (?MODULE, set),
  case dict:is_key (Voc, Dict1) of
    false ->
      Dict2 = dict:store (Voc, Table, Dict1),
      { noreply, State#s { tables = Dict2 } };
    true ->
      { fatalize, ?str_amvoc_vredefine (Voc) }
  end.

handle_voc_select_voc ({ }, #s { tables = Dict } = State) ->
  Vocs = dict:fetch_keys (Dict),
  { reply, Vocs, State }.

%
% dispatchers - stem
%

handle_voc_create_stem ({ Key, Value }, #s { tables = Dict } = State) ->
  try
    Table = dict:fetch (Key#stem_k.voc, Dict),
    gen_acc_storage:insert_once (Table, Key, Value),
    { noreply, State }
  catch
    throw : ?e_key_exists (_) ->
      Voc   = Key#stem_k.voc,
      Stem  = Key#stem_k.stem,
      { fatalize, ?str_amvoc_sredefine (Voc, Stem) }
  end.

handle_voc_find_stem ({ Key }, #s { tables = Dict } = State) ->
  Table = dict:fetch (Key#stem_k.voc, Dict),
  Reply =
    case gen_acc_storage:get_default (Table, Key) of
      undefined -> false;
      Value -> { true, Value }
    end,
  { reply, Reply, State }.

handle_voc_select_stem ({ Key, Value, Filter }, #s { tables = Dict } = State) ->
  Table = dict:fetch (Key#stem_k.voc, Dict),
  Reply = gen_acc_storage:select_filter (Table, Key, Value, Filter),
  { reply, Reply, State }.

% =============================================================================
% INTERNAL FUNCTIONS
% =============================================================================
