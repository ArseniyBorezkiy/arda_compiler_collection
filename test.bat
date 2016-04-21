@echo off

SET ROOT=%~dp0
SET TEST_LOG=%ROOT%\var\tmp\test.log
SET QU_DIR=./tests.qu

call %ROOT%\priv\common.bat

%ALS%
TIMEOUT /T 3 > nul

echo *** QUENYA TEST *** > %TEST_LOG%
%AL% -l -d %QU_DIR% -i test.in.txt -o test.out.txt >> %TEST_LOG%
%AL% -l -d %QU_DIR% -i test.in.txt -o test.out.txt >> %TEST_LOG%