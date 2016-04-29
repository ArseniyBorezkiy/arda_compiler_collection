@echo off

call %ROOT%\priv\config.bat
SET ERLANG_HOME=%ERL_TOP%
SET PATH=%PATH%;%ERL_TOP%\bin
SET HOME=%ROOT%

cd /d %HOME%

SET EROOT=%ROOT:\=/%
SET AM=erl -noinput -name %CNODE% -pa %EROOT%ebin -setcookie %ECOOK% -s acc make -extra
SET ACC=erl -noinput -name %CNODE% -pa %EROOT%ebin -setcookie %ECOOK% -s acc start %SNODE% -extra
SET ACCD=erl -noshell -noinput -name %CNODE% -pa %EROOT%ebin -setcookie %ECOOK% -s acc start %SNODE% -extra
SET ACCS=start "server" "erl" -noinput -name %SNODE% -pa %EROOT%ebin -config %ROOT%ebin/general.config -setcookie %ECOOK% -boot acc -extra
SET ACCSI=erl -noinput -name %SNODE% -pa %EROOT%ebin -config %ROOT%ebin/general.config -setcookie %ECOOK% -boot acc -extra
SET ACCSD=start "server" "erl" -noshell -noinput -name %SNODE% -pa %EROOT%ebin -config %ROOT%ebin/general.config -setcookie %ECOOK% -boot acc -extra