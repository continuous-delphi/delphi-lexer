@echo off
setlocal
pushd "%~dp0"

::
:: invoke-delphici found in: https://github.com/continuous-delphi/delphi-powershell-ci
::
pwsh -Command invoke-delphici -ConfigFile ci.json

set "EXITCODE=%ERRORLEVEL%"

:: if errorlevel 1 pause
pause
popd
endlocal & exit /b %EXITCODE%