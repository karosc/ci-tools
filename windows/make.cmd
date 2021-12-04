::
::  make.cmd - builds project
::
::  Created: Oct 15, 2019
::  Updated: Dec 3, 2021
::
::  Author: See AUTHORS
::
::  Requires:
::    Build Tools for Visual Studio download:
::      https://visualstudio.microsoft.com/downloads/
::
::    CMake download:
::      https://cmake.org/download/
::
::  Optional Arguments:
::    -g ("GENERATOR") defaults to "Visual Studio 15 2017"
::    -t builds and runs unit tests (requires Boost)
::

::echo off


:: set global defaults
set "BUILD_HOME=build"
set "PLATFORM=win32"

:: check if on an Actions runner or local
if not defined GITHUB_ENV (
  set GITHUB_ENV=nul
)

:: determine project directory
set "SCRIPT_HOME=%~dp0"
cd %SCRIPT_HOME%
pushd ..
pushd ..
set "PROJ_DIR=%CD%"


:: check for requirements
where cmake > nul || (
  echo ERROR: cmake not installed )
)

:: prepare for artifact upload
if not exist upload (
  mkdir upload
)

setlocal EnableDelayedExpansion

:: determine PROJECT
for %%i in ( %PROJ_DIR% ) do (
  set BASENAME=%%~ni && set SHORTNAME=!BASENAME:~0,3!
)

if not defined PROJECT (
  if /I "%SHORTNAME%"=="sto" ( set "PROJECT=swmm" )
  if /I "%SHORTNAME%"=="swm" ( set "PROJECT=swmm" )
  if /I "%SHORTNAME%"=="wat" ( set "PROJECT=epanet" )
  if /I "%SHORTNAME%"=="epa" ( set "PROJECT=epanet" )
)

if not defined PROJECT (
  echo "ERROR: PROJECT could not be determined" & exit /B 1
)

:: GitHub Actions
echo PROJECT=%PROJECT% >> %GITHUB_ENV%


echo INFO: Building %PROJECT%  ...


:: set local defaults
set "GENERATOR=Visual Studio 15 2017"
set "TESTING=0"

:: process arguments
:loop
if NOT [%1]==[] (
  if "%1"=="/g" (
    set "GENERATOR=%~2"
    shift
  )
  if "%1"=="/t" (
    set "TESTING=1"
  )
  shift
  goto :loop
)


:: if generator has changed delete the build folder
if exist %BUILD_HOME% (
  for /F "tokens=*" %%f in ( 'findstr CMAKE_GENERATOR:INTERNAL %BUILD_HOME%\CmakeCache.txt' ) do (
    for /F "delims=:= tokens=3" %%m in ( 'echo %%f' ) do (
      set CACHE_GEN=%%m
      if not "!CACHE_GEN!" == "!GENERATOR!" ( rmdir /s /q %BUILD_HOME% )
    )
  )
)

:: perform the build
cmake -E make_directory %BUILD_HOME%

if %TESTING% equ 1 (
  cmake -E chdir .\%BUILD_HOME% cmake -G"%GENERATOR%" -DBUILD_TESTS=ON ..^
  && cmake --build .\%BUILD_HOME% --config Debug^
  && cmake -E chdir .\%BUILD_HOME% ctest -C Debug --output-on-failure^
  || (
    echo ERROR: Build and Test Failed & exit /B 1
  )

) else (
  cmake -E chdir .\%BUILD_HOME% cmake -G"%GENERATOR%" -DBUILD_TESTS=OFF ..^
  && cmake --build .\%BUILD_HOME% --config Release --target package^
  && (
    move /Y .\%BUILD_HOME%\*.zip .\upload > nul
  ) || (
    echo ERROR: Build Failed & exit /B 1
  )

)


:: determine PLATFORM from CmakeCache.txt file
for /F "tokens=*" %%f in ( 'findstr CMAKE_SHARED_LINKER_FLAGS:STRING %BUILD_HOME%\CmakeCache.txt' ) do (
  for /F "delims=: tokens=3" %%m in ( 'echo %%f' ) do (
    if "%%m" == "X86" ( set "PLATFORM=win32" ) else if "%%m" == "x64" ( set "PLATFORM=win64" )
  )
)
if not defined PLATFORM ( echo ERROR: PLATFORM could not be determined & exit /B 1 )


:: GitHub Actions
echo PLATFORM=%PLATFORM% >> %GITHUB_ENV%

:: return to users to project directory
cd %PROJ_DIR%

exit /B 1
