@echo off
setlocal

call C:\Delphi\RADStudio37\bin\RSVars.bat

set DPROJ=%~dp0..\projects\TokenDump\DelphiLexer.TokenDump.dproj

msbuild "%DPROJ%" /p:Platform=Win32 /p:Config=Release /t:Build /verbosity:minimal
if %ERRORLEVEL% NEQ 0 (
    echo Build FAILED.
    exit /b %ERRORLEVEL%
)
echo Build succeeded: ..\projects\TokenDump\Win32\Release\DelphiLexer.TokenDump.exe
endlocal
