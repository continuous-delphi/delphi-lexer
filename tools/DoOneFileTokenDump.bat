@echo off
setlocal

pwsh -File run-tokendump-file.ps1 "C:\code\ThirdParty\graphics32\Source\GR32_Transforms.pas"

set "EXITCODE=%ERRORLEVEL%"
::pause

endlocal & exit /b %EXITCODE%
