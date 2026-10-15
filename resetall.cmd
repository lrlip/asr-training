@echo off
rem Double-click this file (or the "Reset ASR all sessions" shortcut on the desktop) to remove
rem every training session, clone them again and set them up. reset.cmd next to it does the work.
call "%~dp0reset.cmd" -Session all %*
exit /b %ERRORLEVEL%
