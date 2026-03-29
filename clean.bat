@echo off
setlocal
pushd "%~dp0"

::
:: Invoke-DelphiClean found bundled in: https://github.com/continuous-delphi/delphi-powershell-ci
:: or stand-alone in: https://github.com/continuous-delphi/delphi-clean
::
pwsh -Command Invoke-DelphiClean -Level full -IncludeFiles "*.res"

set "EXITCODE=%ERRORLEVEL%"

:: if errorlevel 1 pause
pause

popd
endlocal & exit /b %EXITCODE%