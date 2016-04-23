@echo off

SET ROOT=%~dp0
SET TEST_LOG=%ROOT%\var\tmp\test.log
SET QU_DIR=./tests.qu

call %ROOT%\priv\common.bat

%ALS% -l al.log -d qu -r lang.qu.txt
TIMEOUT /T 3 > nul

echo *** QUENYA TEST *** > %TEST_LOG%
echo. >> %TEST_LOG%

%AL% >> %TEST_LOG%
%AL% -a >> %TEST_LOG%
%AL% -d %QU_DIR% -i test.in.txt -o test.out.txt >> %TEST_LOG%