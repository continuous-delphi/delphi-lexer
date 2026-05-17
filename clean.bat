@echo off
setlocal

pushd "%~dp0"

REM
REM Invoke-DelphiClean found bundled in: https://github.com/continuous-delphi/delphi-powershell-ci
REM or stand-alone in: https://github.com/continuous-delphi/delphi-clean
REM

pwsh -NoProfile -NoLogo -Command "$ErrorActionPreference='Stop'; Invoke-DelphiClean -CleanLevel deep -CleanIncludeFilePattern '*.res'"

set "EXITCODE=%ERRORLEVEL%"
if %EXITCODE% NEQ 0 pause
popd
pause
endlocal & exit /b %EXITCODE%
