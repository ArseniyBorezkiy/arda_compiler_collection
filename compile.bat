@echo off

SET ROOT=%~dp0

call %ROOT%\priv\common.bat

%ACCD% %1 -i %2 -o %3