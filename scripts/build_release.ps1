[CmdletBinding()]
param(
    [ValidateSet("Windows", "Android", "Web")]
    [string[]]$Platforms = @("Windows", "Android", "Web")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description
    )

    Write-Host "`n==> $Description" -ForegroundColor Cyan
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter was not found in PATH. Install the Flutter SDK and add its bin directory to PATH."
}

if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    throw "pubspec.yaml was not found. Run this script from the FlutterDraw repository."
}

$Pubspec = Get-Content (Join-Path $ProjectRoot "pubspec.yaml") -Raw
$VersionMatch = [regex]::Match($Pubspec, '(?m)^version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)')
if (-not $VersionMatch.Success) {
    throw "Could not read version from pubspec.yaml."
}
$Version = $VersionMatch.Groups[1].Value
$ReleaseFolderName = "v" + ($Version -replace '\+.*$', '')
$DistRoot = Join-Path $ProjectRoot "dist"
$ReleaseRoot = Join-Path $DistRoot $ReleaseFolderName

$PlatformFolders = @{
    Windows = "windows"
    Android = "android"
    Web = "web"
}
$MissingFolders = @(
    foreach ($Platform in $Platforms) {
        $Folder = Join-Path $ProjectRoot $PlatformFolders[$Platform]
        if (-not (Test-Path $Folder)) {
            $PlatformFolders[$Platform]
        }
    }
)

if ($MissingFolders.Count -gt 0) {
    $MissingList = $MissingFolders -join ", "
    throw "Required platform folders are missing: $MissingList. Generate them once with: flutter create --platforms=$($Platforms -join ',')."
}

Invoke-Checked -Command "flutter" -Arguments @("pub", "get") -Description "Installing dependencies"
Invoke-Checked -Command "flutter" -Arguments @("analyze") -Description "Running static analysis"
Invoke-Checked -Command "flutter" -Arguments @("test") -Description "Running tests"

if (Test-Path $ReleaseRoot) {
    Remove-Item $ReleaseRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null

$FlutterVersionOutput = & flutter --version --machine 2>&1
$FlutterVersionExitCode = $LASTEXITCODE
if ($FlutterVersionExitCode -ne 0) {
    throw "Could not determine the Flutter version. Run: flutter --version --machine. Details: $($FlutterVersionOutput -join ' ')"
}

try {
    $FlutterVersionInfo = ($FlutterVersionOutput -join "`n") | ConvertFrom-Json -ErrorAction Stop
    $FlutterVersion = $FlutterVersionInfo.frameworkVersion
    if ([string]::IsNullOrWhiteSpace($FlutterVersion)) {
        throw "The frameworkVersion field is empty."
    }
}
catch {
    throw "Could not parse the Flutter version output. Run: flutter --version --machine. Details: $($FlutterVersionOutput -join ' ')"
}

foreach ($Platform in $Platforms) {
    switch ($Platform) {
        "Windows" {
            Invoke-Checked -Command "flutter" -Arguments @("build", "windows", "--release") -Description "Building Windows"
            $BuildFolder = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
            if (-not (Test-Path (Join-Path $BuildFolder "flutterdraw.exe"))) {
                throw "flutterdraw.exe was not found in $BuildFolder. Check that Visual Studio with the Desktop development with C++ workload is installed."
            }
            $Archive = Join-Path $ReleaseRoot "flutterdraw-windows-x64.zip"
            Compress-Archive -Path (Join-Path $BuildFolder "*") -DestinationPath $Archive -CompressionLevel Optimal
        }
        "Android" {
            Invoke-Checked -Command "flutter" -Arguments @("build", "apk", "--release") -Description "Building Android APK"
            $Apk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
            if (-not (Test-Path $Apk)) {
                throw "APK was not found: $Apk. Check the Android SDK and accepted Android SDK licenses."
            }
            Copy-Item $Apk (Join-Path $ReleaseRoot "flutterdraw-android.apk")
        }
        "Web" {
            Invoke-Checked -Command "flutter" -Arguments @("build", "web", "--release") -Description "Building Web"
            $WebFolder = Join-Path $ProjectRoot "build\web"
            if (-not (Test-Path (Join-Path $WebFolder "index.html"))) {
                throw "Web build was not found: $WebFolder."
            }
            $Archive = Join-Path $ReleaseRoot "flutterdraw-web.zip"
            Compress-Archive -Path (Join-Path $WebFolder "*") -DestinationPath $Archive -CompressionLevel Optimal
        }
    }
}

$BuildInfo = @(
    "FlutterDraw $Version"
    "Built: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
    "Flutter: $FlutterVersion"
    "Platforms: $($Platforms -join ', ')"
)
$BuildInfo | Set-Content -Path (Join-Path $ReleaseRoot "BUILD-INFO.txt") -Encoding UTF8

Write-Host "`nBuild completed." -ForegroundColor Green
Write-Host "Output: $ReleaseRoot" -ForegroundColor Green
Get-ChildItem $ReleaseRoot | Select-Object Name, Length
