@ECHO OFF
REM Copyright (c) 2016 Paul Goins
REM
REM Licensed under the Apache License, Version 2.0 (the "License");
REM you may not use this file except in compliance with the License.
REM You may obtain a copy of the License at
REM
REM     http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.

REM Script for building and installing LFE on Windows.
REM
REM Intent is to allow users to build and run LFE with no dependencies
REM other than Erlang.  Implicitly this removes the need for 3rd-party
REM tools such as Make on Windows.

SETLOCAL EnableDelayedExpansion
SET "SRCDIR=src"
SET "INCDIR=include"
SET "BINDIR=bin"
SET "EBINDIR=ebin"
SET "ERLC=erlc"
SET "ERLCFLAGS=-W1"
SET "LFEC=%BINDIR%\lfe %BINDIR%\lfec"
SET "LFECFLAGS=-pa ../lfe"
SET "APP_DEF=lfe.app"

CALL :MAIN %*
IF !ERRORLEVEL! NEQ 0 GOTO :ERROR
GOTO :SUCCESS


:MAIN
CALL :PARSE_ARGS %*
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!

IF "%COMMAND%"=="compile" (
    CALL :COMPILE_COMMAND
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
) ELSE IF "%COMMAND%"=="install" (
    CALL :INSTALL_COMMAND
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
) ELSE IF "%COMMAND%"=="clean" (
    CALL :CLEAN_COMMAND
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
)
EXIT /B 0


:PARSE_ARGS
SET "COMMAND="
IF "%1"=="compile" (
    SET "COMMAND=compile"
) ELSE IF "%1"=="install" (
    SET "COMMAND=install"
) ELSE IF "%1"=="clean" (
    SET "COMMAND=clean"
)
REM Ignoring extra arguments for the time being.

IF "%COMMAND%"=="" (
    CALL :PRINT_SYNTAX
    EXIT /B 1
)
EXIT /B 0


:PRINT_SYNTAX
ECHO Syntax: %~nx0 ^<compile^|install^|clean^>
EXIT /B 0


:COMPILE_COMMAND
echo Command: compile
CALL :COMPILE
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
EXIT /B 0


:INSTALL_COMMAND
echo Command: install
CALL :COMPILE
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
CALL :INSTALL
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
EXIT /B 0


:CLEAN_COMMAND
IF EXIST maps_opts.mk (
    CALL :FORCE_ECHO DEL maps_opts.mk
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
)
IF EXIST ebin (
    CALL :FORCE_ECHO RMDIR /S /Q ebin
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
)
EXIT /B 0


:COMPILE
CALL :GET_MAPS_OPTS
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
CALL :COMPILE_XRL_TO_ERL
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
CALL :COMPILE_ERL_FILES
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
IF NOT EXIST "%EBINDIR%\%APP_DEF%" (
    CALL :FORCE_ECHO COPY /Y "%SRCDIR%\%APP_DEF%.src" "%EBINDIR%\%APP_DEF%"
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
)
CALL :COMPILE_LFE_FILES
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
CALL :CLEANUP_INTERMEDIATE_FILES
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
EXIT /B 0


:GET_MAPS_OPTS
IF NOT EXIST maps_opts.mk (
    CALL :FORCE_ECHO escript get_maps_opts.escript
    IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
)
REM Format of maps_opt.mk is: key = value
REM Value may be more than a single token.
FOR /F "tokens=1,3*" %%A in (maps_opts.mk) DO (
    CALL :FORCE_ECHO SET "%%A=%%B"
)
EXIT /B 0


:COMPILE_XRL_TO_ERL
FOR %%F in ("%SRCDIR%\*.xrl") DO (
    IF NOT EXIST %SRCDIR%\%%~nF.erl (
        CALL :FORCE_ECHO %ERLC% -o %SRCDIR% %%F
        IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
    )
)
EXIT /B 0


:COMPILE_ERL_FILES
IF NOT EXIST "%EBINDIR%" (
    CALL :FORCE_ECHO MKDIR "%EBINDIR%"
)

FOR %%F in ("%SRCDIR%\*.erl") DO (
    IF NOT EXIST %EBINDIR%\%%~nF.beam (
        CALL :FORCE_ECHO %ERLC% -I %INCDIR% -o %EBINDIR% %MAPS_OPTS% %ERLCFLAGS% %%F
        IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
    )
)
EXIT /B 0


:COMPILE_LFE_FILES
FOR %%F in ("%SRCDIR%\*.lfe") DO (
    IF NOT EXIST %EBINDIR%\%%~nF.beam (
        CALL :FORCE_ECHO %LFEC% -I %INCDIR% -o %EBINDIR% %LFECFLAGS% %%F
        IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
    )
)
EXIT /B 0


:CLEANUP_INTERMEDIATE_FILES
REM Remove .erl files generated from .xrl files
FOR %%F in ("%SRCDIR%\*.xrl") DO (
    IF EXIST %SRCDIR%\%%~nF.erl (
        CALL :FORCE_ECHO DEL %SRCDIR%\%%~nF.erl
        IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!
    )
)
EXIT /B 0


:FORCE_ECHO
ECHO %*
REM For some reason, when calling werl, this seems to fail critically
REM if I simply call via "%*".  Via CMD /C, it seems to run.
CMD /C %*
EXIT /B !ERRORLEVEL!


:INSTALL
ECHO Installation is not yet implemented.
EXIT /B 1


:ERROR
ECHO Error occurred; aborting. >&2
GOTO :FINISH


:SUCCESS
ECHO Completed successfully.
GOTO :FINISH


:FINISH
ENDLOCAL
GOTO :EOF
