%% @doc Arguments checker.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__VALIDATE_HRL__).
-define (__VALIDATE_HRL__, ok).

% =============================================================================
% DEFINITIONS
% =============================================================================

%
% exceptions
%

-define (e_invalid_value (Value), {{ value, invalid }, Value }).

%
% macroses
%

-ifdef (DEBUG).

-define (validate (V, VS), _validate (V, VS)).
-define (validate_integer (V, Min), _validate_integer (V, Min)).
-define (validate_integer (V, Min, Max), _validate_integer (V, Min, Max)).
-define (validate_list (V), _validate_list (V)).
-define (validate_atom (V), _validate_atom (V)).
-define (validate_record (V, R), _validate_record (V, R)).
-define (validate_function (V, A), _validate_function (V, A)).
-define (validate_record_list (V, R), _validate_record_list (V, R)).

-else.

-define (validate (_V, _VS), ok).
-define (validate_integer (_V, _Min), ok).
-define (validate_integer (_V, _Min, _Max), ok).
-define (validate_list (_V), ok).
-define (validate_atom (_V), ok).
-define (validate_record (_V, _R), ok).
-define (validate_function (_V, _A), ok).
-define (validate_record_list (_V, _R), ok).

-endif. % DEBUG

% =============================================================================
% FUNCTIONS
% =============================================================================

%
% validators
%

-ifdef (DEBUG).

_validate (Value, Values) when is_list (Values) ->
  case lists:member (Value, Values) of
    true  -> ok;
    false -> throw (?e_invalid_value (Value))
  end.

_validate_integer (Value, Min)
  when is_integer (Min),
       Value >= Min ->
  ok;

_validate_integer (Value, _Min) ->
  throw (?e_invalid_value (Value)).

_validate_integer (Value, Min, Max)
  when is_integer (Min), is_integer (Max),
       Value >= Min, Value =< Max ->
  ok;

_validate_integer (Value, _Min, _Max) ->
  throw (?e_invalid_value (Value)).

_validate_list (Value)
  when is_list (Value) ->
  ok;

_validate_list (Value) ->
  throw (?e_invalid_value (Value)).

_validate_atom (Value)
  when is_atom (Value) ->
  ok;

_validate_atom (Value) ->
  throw (?e_invalid_value (Value)).

_validate_record (Value, Record)
  when is_record (Value, Record) ->
  ok;

_validate_record (Value, _Record) ->
  throw (?e_invalid_value (Value)).

_validate_function (Value, Arity)
  when is_function (Value, Arity) ->
  ok;

_validate_function (Value, _Arity) ->
  throw (?e_invalid_value (Value)).

_validate_record_list ([], _Record) -> ok;
_validate_record_list ([ Value | Tail ], Record)
  when is_record (Value, Record) ->
  _validate_record_list (Tail, Record);

_validate_record_list (Value, _Record) ->
  throw (?e_invalid_value (Value)).

-endif. % DEBUG

%
% end
%

-endif. % __VALIDATE_HRL__