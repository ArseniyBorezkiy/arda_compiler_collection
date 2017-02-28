@echo off

SET ROOT=%~dp0
SET QU_DIR=%ROOT%\var\tests.qu

call %ROOT%\priv\common.bat

%ACCS% -l al.log -d qu -r lang.qu.txt
TIMEOUT /T 3 > nul

%ACC% -l -d %QU_DIR% -i test.in.txt -o test.out.txt