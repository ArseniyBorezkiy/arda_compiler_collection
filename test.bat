@echo off

SET LANG=qu

SET ROOT=%~dp0
SET TEST_LOG=%ROOT%\var\tmp\test.log
SET LANG_DIR=./tests.%LANG%

call %ROOT%\priv\common.bat

%ALS% -l al.%LANG%.log -d %LANG% -r lang.%LANG%.txt
TIMEOUT /T 3 > nul

echo *** QUENYA TEST *** > %TEST_LOG%
echo. >> %TEST_LOG%

%AL% >> %TEST_LOG%
%AL% -s -m -a >> %TEST_LOG%
%AL% -s -m -d %LANG_DIR% -i test.in.txt -o test.out.txt >> %TEST_LOG%