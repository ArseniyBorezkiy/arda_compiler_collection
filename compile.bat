@echo off
SET ERL_TOP=D:\Program Files\erl7.3
SET ERLANG_HOME=%ERL_TOP%
SET PATH=%PATH%;%ERL_TOP%\bin

SET ROOT=%~dp0
SET HOME=%ROOT%

cd /d %HOME%
SET CNODE=client@127.0.0.1
SET SNODE=server@127.0.0.1
SET ECOOK=abc

SET ROOT=%ROOT:\=/%
SET TARGET_IN=%1
SET TARGET_OUT=%2
SET ARGUMENTS="al:start(
SET ARGUMENTS=%ARGUMENTS%'%SNODE%',\"%TARGET_IN%\",\"%TARGET_OUT%\"
SET ARGUMENTS=%ARGUMENTS%)"

start "server" "erl" -name %SNODE% -pa %ROOT%ebin -config %ROOT%general.config -setcookie %ECOOK% -eval "application:start(al)"
erl -name %CNODE% -pa %ROOT%ebin -setcookie %ECOOK% -eval %ARGUMENTS%