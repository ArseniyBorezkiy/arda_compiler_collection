@echo off

SET ROOT=%~dp0
SET TEST_LOG=%ROOT%\var\tmp\test.log
SET QU_DIR=./tests.tpl

call %ROOT%\priv\common.bat

%ALS% -l al.log -d tpl -r lang.tpl.txt
TIMEOUT /T 3 > nul

echo *** QUENYA TEST *** > %TEST_LOG%
echo. >> %TEST_LOG%

%AL% >> %TEST_LOG%
%AL% -a >> %TEST_LOG%
%AL% -d %QU_DIR% -i test.in.txt -o test.out.txt >> %TEST_LOG%