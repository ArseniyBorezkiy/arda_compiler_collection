@echo off

SET LANG=tpl

SET ROOT=%~dp0
SET TEST_LOG=%ROOT%\var\tmp\test.log
SET LANG_DIR=./tests.%LANG%

call %ROOT%\priv\common.bat

%ACCS% -l al.%LANG%.log -d %LANG% -r lang.%LANG%.txt
TIMEOUT /T 3 > nul

echo *** QUENYA TEST *** > %TEST_LOG%
echo. >> %TEST_LOG%

%ACC% >> %TEST_LOG%
%ACC% -s -m -a >> %TEST_LOG%
%ACC% -s -m -d %LANG_DIR% -i test.in.txt -o test.out.txt >> %TEST_LOG%