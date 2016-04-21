@echo off

SET ROOT=%~dp0

call %ROOT%\priv\common.bat

%ALS%
TIMEOUT /T 3 > nul

%AL% -l -d %QU_DIR% -i test.in.txt -o test.out.txt