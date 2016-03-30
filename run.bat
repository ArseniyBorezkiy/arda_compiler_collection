@echo off
SET ROOT=%~dp0
call %ROOT%\compile.bat test.in.txt
pause > nul