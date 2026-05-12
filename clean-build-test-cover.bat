@echo off
setlocal
pushd "%~dp0"

::
:: invoke-delphici found in: https://github.com/continuous-delphi/delphi-powershell-ci
::
pwsh -Command invoke-delphici -ConfigFile clean-build-test-cover.json

set "EXITCODE=%ERRORLEVEL%"

:: if errorlevel 1 pause

popd
endlocal & exit /b %EXITCODE%