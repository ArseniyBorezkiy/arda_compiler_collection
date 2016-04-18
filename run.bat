@echo off
SET ROOT=%~dp0
call %ROOT%\compile.bat test.in.txt test.out.txt
pause > nul