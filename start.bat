@echo off

SET ROOT=%~dp0

call %ROOT%\priv\common.bat

%ALS% -l al.log -d qu -r lang.qu.txt
TIMEOUT /T 3 > nul

%AL% -l -d %QU_DIR% -i test.in.txt -o test.out.txt