@echo off

SET ROOT=%~dp0

call %ROOT%\priv\common.bat

cd /d %ROOT%\ebin

echo *** MAKE ***
%AM%
echo make - successfully finished.