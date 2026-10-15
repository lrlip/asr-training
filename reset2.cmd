@echo off
rem Double-click this file (or the "Reset ASR session 2" shortcut on the desktop) to remove
rem asr-session-2, clone it again and set it up. reset.cmd next to it does the work.
call "%~dp0reset.cmd" -Session 2 %*
exit /b %ERRORLEVEL%
