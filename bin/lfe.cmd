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
SET LFE_PROGNAME=%~nx0
SET LFE_BINDIR=%~dp0
SET LFE_ROOTDIR=%~dp0..

CALL :MAIN %*
IF !ERRORLEVEL! NEQ 0 GOTO :ERROR
IF "%NOOP%"=="true" (
    GOTO :FINISH
)
GOTO :SUCCESS


:MAIN
SET CMDLINE=
SET NOSHELL=

CALL :PARSE_ARGS %*
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!

CALL :FIND_ALL_LIBS
IF !ERRORLEVEL! NEQ 0 EXIT /B !ERRORLEVEL!

REM Due to inconsistencies between erl.exe and werl.exe, launch
REM werl.exe if a shell is needed, and erl.exe otherwise.  I'm not
REM sure this will satisfy all cases, but it sounds like a good
REM heuristic to start with.
IF "%NOSHELL%"=="true" (
    SET ERL=erl
) ELSE (
    SET ERL=werl
)
SET CMDLINE=%ERL% -pa %LFE_ROOTDIR%\ebin %CMDLINE%

ECHO Using libs: %ALL_LIBS%
ECHO Command line: %CMDLINE%
%CMDLINE%

EXIT /B 0


REM ----------------------------------------------------------------------
REM This is especially hairy since using shift affects the parameters
REM to the subprocedure rather than the outermost batch file's
REM enviornment.  To get around this, we fall back to GOTOs and handle
REM all arg shifting within this function.  Not fun...
:PARSE_ARGS

:PARSE_ARGS_MAIN_LOOP
SET ARG=%1
IF "%ARG%"=="" GOTO :PARSE_ARG_DONE_WITH_ARG
IF "%ARG%"=="-h" GOTO :PARSE_ARG_HANDLE_HELP
IF "%ARG%"=="--help" GOTO :PARSE_ARG_HANDLE_HELP
IF "%ARG%"=="-e" GOTO :PARSE_ARG_HANDLE_EVAL
IF "%ARG%"=="-eval" GOTO :PARSE_ARG_HANDLE_EVAL
IF "%ARG%"=="--" GOTO :PARSE_ARG_HANDLE_EXTRA
IF "%ARG%"=="-extra" GOTO :PARSE_ARG_HANDLE_EXTRA
IF "%ARG:~0,1%"=="-" GOTO :PARSE_ARG_HANDLE_FLAG
IF "%ARG:~0,1%"=="+" GOTO :PARSE_ARG_HANDLE_FLAG
GOTO :PARSE_ARG_HANDLE_OTHER

:PARSE_ARG_HANDLE_HELP
CALL :SHOW_HELP
EXIT /B 1

:PARSE_ARG_HANDLE_EVAL
SET EVAL_FLAG=-lfe_eval
SHIFT
GOTO :PARSE_ARG_DONE_PARSING

:PARSE_ARG_HANDLE_EXTRA
SHIFT
GOTO :PARSE_ARG_DONE_PARSING

:PARSE_ARG_HANDLE_FLAG
IF "%ARG%"=="-erl_eval" (
    CALL :ADD_ARG -eval
) ELSE (
    CALL :ADD_ARG %ARG%
)
:PARSE_ARG_HANDLE_FLAG_LOOP
SHIFT
SET ARG=%1
REM If we're out of args, or if the next arg is a flag, break out.
IF "%ARG%"=="" GOTO :PARSE_ARG_HANDLE_FLAG_LOOP_DONE
IF "%ARG:~0,1%"=="-" GOTO :PARSE_ARG_HANDLE_FLAG_LOOP_DONE
IF "%ARG:~0,1%"=="+" GOTO :PARSE_ARG_HANDLE_FLAG_LOOP_DONE
REM Otherwise...
CALL :ADD_ARG %ARG%
GOTO :PARSE_ARG_HANDLE_FLAG_LOOP
:PARSE_ARG_HANDLE_FLAG_LOOP_DONE
GOTO :PARSE_ARG_DONE_WITH_ARG

:PARSE_ARG_HANDLE_OTHER
GOTO :PARSE_ARG_DONE_PARSING

:PARSE_ARG_DONE_PARSING
SET DONE_PARSING=true
GOTO :PARSE_ARG_DONE_WITH_ARG

:PARSE_ARG_DONE_WITH_ARG
IF "%1"=="" (
    GOTO :PARSE_ARGS_MAIN_LOOP_DONE
)
IF "%DONE_PARSING%"=="true" (
    GOTO :PARSE_ARGS_MAIN_LOOP_DONE
)
GOTO :PARSE_ARGS_MAIN_LOOP

:PARSE_ARGS_MAIN_LOOP_DONE

IF NOT "%1"=="" (
    SET NOSHELL=true
    CALL :ADD_ARG -noshell
)
CALL :ADD_ARG -user
CALL :ADD_ARG lfe_init
CALL :ADD_ARG -extra
IF NOT "%EVAL_FLAG%"=="" (
    CALL :ADD_ARG %EVAL_FLAG%
)

:PARSE_ARGS_REMAINING_ARGS_LOOP
IF NOT "%1"=="" (
    CALL :ADD_ARG %1
    SHIFT
    GOTO :PARSE_ARGS_REMAINING_ARGS_LOOP
)
EXIT /B 0
REM End of arg parsing
REM ----------------------------------------------------------------------


:SHOW_HELP
ECHO Usage: %~nx0 [flags] [lfe_file] [args]>&2
ECHO.>&2
ECHO     -h ^| --help              Print this help and exit>&2
ECHO     -e ^| -eval "sexp"        Evaluates the given sexpr>&2
ECHO     -- ^| -extra "switches"   Send misc configuration switches to the Erlang VM>&2
ECHO     -flag ^| +flag            Enables/disables configuration flags to be>&2
ECHO                              used by the Erlang VM>&2
EXIT /B 0


:ADD_ARG
IF "%CMDLINE%"=="" (
    SET CMDLINE=%1
) ELSE (
    SET CMDLINE=%CMDLINE% %1
)
EXIT /B 0


:FIND_ALL_LIBS
CALL :FIND_LIBS PROJ_LIBS .\deps
CALL :FIND_LIBS R3_PROJ_LIBS_1 .\_build\default\deps
CALL :FIND_LIBS R3_PROJ_LIBS_2 .\_build\default\lib
SET R3_PROJ_LIBS=%R3_PROJ_LIBS_1%;%R3_PROJ_LIBS_2%
IF NOT "%HOME%"=="" (
    CALL :FIND_LIBS LFE_HOME_LIBS %HOME%\.lfe\lib
) ELSE (
    CALL :FIND_LIBS LFE_HOME_LIBS %USERPROFILE%\.lfe\lib
)
SET ALL_LIBS=%LFE_ROOTDIR%;%ERL_LIBS%;%PROJ_LIBS%;%R3_PROJ_LIBS%;%LFE_HOME_LIBS%
EXIT /B 0


:FIND_LIBS
SET VAR_NAME=%1
SET DIR=%2
SET THIS_LIB_DIR=
FOR %%A IN (%DIR%\*) DO (
    SET THIS_LIB_DIR=!THIS_LIB_DIR!;%%A
)
ECHO SET %VAR_NAME%=%THIS_LIB_DIR%
SET %VAR_NAME%=%THIS_LIB_DIR%
EXIT /B 0


:ERROR
ECHO Error occurred; aborting.>&2
GOTO :FINISH


:SUCCESS
ECHO Completed successfully.
GOTO :FINISH


:FINISH
ENDLOCAL
GOTO :EOF
