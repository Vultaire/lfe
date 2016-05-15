@ECHO OFF

REM This works after running "make compile".  If lfe.bat and
REM lfeexec.exe are moved to the Erlang bin directory, this will break
REM unless the ebin folder is also moved into the Erlang root
REM directory.

SET LFE_ROOTDIR=%~dp0..

%~dp0lfeexec
