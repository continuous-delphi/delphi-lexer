@echo off
setlocal

call C:\Delphi\RADStudio37\bin\RSVars.bat

set DPROJ=%~dp0..\test\DelphiLexer.Tests.dproj
set EXE=%~dp0..\test\Win32\Debug\DelphiLexer.Tests.exe

msbuild "%DPROJ%" /p:Platform=Win32 /p:Config=Debug /t:Build /verbosity:minimal /p:DCC_Define="$(DCC_Define);CI"
if %ERRORLEVEL% NEQ 0 (
    echo Build FAILED.
    exit /b %ERRORLEVEL%
)

echo.
"%EXE%"
exit /b %ERRORLEVEL%
endlocal
