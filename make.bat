@echo off

SET ROOT=%~dp0

call %ROOT%\priv\common.bat

cd %ROOT%

echo *** MAKE ***

SET ERLC=erlc -W0 -o ./ebin -I ./include/auxiliary -I ./include/common -I ./include/model -I ./include/model/modules -I ./include/parser

%ERLC% ./src/interface/acc.erl
%ERLC% ./src/interface/acc_dispatcher.erl
%ERLC% ./src/interface/acc_sup.erl

%ERLC% ./src/auxiliary/acc_debug.erl
%ERLC% ./src/auxiliary/acc_resource.erl

%ERLC% ./src/parser/al/al_language.erl
%ERLC% ./src/parser/al/al_rule.erl
%ERLC% ./src/parser/al/al_sentence.erl
%ERLC% ./src/parser/al/al_word.erl

%ERLC% ./src/parser/lexer/acc_lexer.erl
%ERLC% ./src/parser/lexer/gen_acc_lexer.erl

%ERLC% ./src/storage/modules/am_ensure.erl
%ERLC% ./src/storage/modules/am_entity.erl
%ERLC% ./src/storage/modules/am_lrule.erl
%ERLC% ./src/storage/modules/am_voc.erl

%ERLC% ./src/storage/al_model.erl
%ERLC% ./src/storage/as_model.erl
%ERLC% ./src/storage/gen_acc_storage.erl

cd /d %ROOT%\ebin

%AM%
cd %ROOT%

echo make - successfully finished.