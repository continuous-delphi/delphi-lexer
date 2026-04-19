param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile
)

$BaseOutput = 'C:\delphi-testing\delphi-lexer\tokendump'
$TimeStamp = Get-Date -Format 'yyyy-MM-dd.HH-mm'
$ResolvedInputFile = (Resolve-Path -Path $InputFile -ErrorAction Stop).Path

$LeafName = [System.IO.Path]::GetFileName($ResolvedInputFile)
$LeafStem = [System.IO.Path]::GetFileNameWithoutExtension($ResolvedInputFile)

$RunName = "$TimeStamp-$LeafStem"
$OutputDirectory = Join-Path $BaseOutput $RunName
$LogFile = Join-Path $BaseOutput "$RunName-TokenDump.log"
$OutputFile = Join-Path $OutputDirectory "$LeafName.txt"

# Delete the old executable before building (to ensure a clean build)
$ExePath = ".\Delphi.Lexer.TokenDump.exe"
if (Test-Path $ExePath) {
    Remove-Item $ExePath -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted old executable: $ExePath" -ForegroundColor Yellow
}

Write-Host "Building: $ExePath" -ForegroundColor Yellow
Invoke-DelphiBuild `
    -Toolchain Latest `
    -ProjectFile ..\projects\TokenDump\Delphi.Lexer.TokenDump.dproj `
    -Platform Win64 `
    -Configuration Release `
    -BuildEngine MSBuild `
    -ExeOutputDir ..\..\tools

if ($LASTEXITCODE -gt 0) {
    Write-Error "Delphi build failed with exit code $LASTEXITCODE. Aborting script."
    exit $LASTEXITCODE
}


if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

Write-Host "$TimeStamp Running: $ResolvedInputFile" -ForegroundColor Yellow

(
    & cmd.exe /d /c "`"$ExePath`" `"$ResolvedInputFile`" --format:json > `"$OutputFile`""
) *>&1 | Tee-Object -FilePath $LogFile

if ($LASTEXITCODE -gt 0) {
    Write-Warning "TokenDump failed with exit code $LASTEXITCODE"
}
else {
    Write-Host "Output written to: $OutputFile" -ForegroundColor Green
}

start $OutputFile

pause