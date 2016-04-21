@echo off

call %ROOT%\priv\config.bat
SET ERLANG_HOME=%ERL_TOP%
SET PATH=%PATH%;%ERL_TOP%\bin
SET HOME=%ROOT%

cd /d %HOME%

SET EROOT=%ROOT:\=/%
SET AL=erl -noinput -name %CNODE% -pa %EROOT%ebin -setcookie %ECOOK% -s al start %SNODE% -extra
SET ALC=erl -noshell -noinput -name %CNODE% -pa %EROOT%ebin -setcookie %ECOOK% -s al start %SNODE% -extra
SET ALS=start "server" "erl" -noinput -name %SNODE% -pa %EROOT%ebin -config %ROOT%ebin/general.config -setcookie %ECOOK% -eval "application:start(al)"
SET ALSD=start "server" "erl" -noshell -noinput -name %SNODE% -pa %EROOT%ebin -config %ROOT%ebin/general.config -setcookie %ECOOK% -eval "application:start(al)"