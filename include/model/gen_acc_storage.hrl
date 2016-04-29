%% @doc Generic abstract key-value storage.
%% @end
%% @author Borezkiy Arseniy Petrovich <apborezkiy1990@gmail.com>
%% @copyright Elen Evenstar, 2016

-ifndef (__GEN_ACC_STORAGE_HRL__).
-define (__GEN_ACC_STORAGE_HRL__, ok).

% =============================================================================
% DEFINITIONS
% =============================================================================

%
% module runtime exception
%

-define (e_module_runtime (Resource), {{ module, runtime }, Resource }).

%
% exceptions
%

-define (e_key_exists (Key), {{ key, exists }, Key }).
-define (e_key_not_exists (Key), {{ key, not_exists }, Key }).
-define (e_key_ambiguity (Key), {{ key, ambiguity }, Key }).

%
% generic storage
%

-record (gas_entry, { k :: term (), v :: term () }).

-type gas_entry_t () :: # gas_entry { } .

%
% end
%

-endif. % __GEN_ACC_STORAGE_HRL__