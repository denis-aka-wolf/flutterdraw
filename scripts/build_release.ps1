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
        throw "$Description завершилась с кодом $LASTEXITCODE."
    }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter не найден в PATH. Установи Flutter SDK и добавь папку bin в PATH."
}

if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    throw "Не найден pubspec.yaml. Запусти скрипт из репозитория FlutterDraw."
}

$Pubspec = Get-Content (Join-Path $ProjectRoot "pubspec.yaml") -Raw
$VersionMatch = [regex]::Match($Pubspec, '(?m)^version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)')
if (-not $VersionMatch.Success) {
    throw "Не удалось прочитать version из pubspec.yaml."
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
    $CreatePlatforms = "windows,android,web"
    Invoke-Checked -Command "flutter" -Arguments @(
        "create", "--platforms=$CreatePlatforms", "--project-name", "flutterdraw", "."
    ) -Description "Подготовка платформенных проектов"
}

Invoke-Checked -Command "flutter" -Arguments @("pub", "get") -Description "Установка зависимостей"
Invoke-Checked -Command "flutter" -Arguments @("analyze") -Description "Статический анализ"
Invoke-Checked -Command "flutter" -Arguments @("test") -Description "Запуск тестов"

if (Test-Path $ReleaseRoot) {
    Remove-Item $ReleaseRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null

$FlutterVersion = (& flutter --version | Select-Object -First 1)
if ($LASTEXITCODE -ne 0) {
    throw "Не удалось определить версию Flutter."
}

foreach ($Platform in $Platforms) {
    switch ($Platform) {
        "Windows" {
            Invoke-Checked -Command "flutter" -Arguments @("build", "windows", "--release") -Description "Сборка Windows"
            $BuildFolder = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
            if (-not (Test-Path (Join-Path $BuildFolder "flutterdraw.exe"))) {
                throw "Не найден flutterdraw.exe в $BuildFolder. Проверь установку Visual Studio с workload Desktop development with C++."
            }
            $Archive = Join-Path $ReleaseRoot "flutterdraw-windows-x64.zip"
            Compress-Archive -Path (Join-Path $BuildFolder "*") -DestinationPath $Archive -CompressionLevel Optimal
        }
        "Android" {
            Invoke-Checked -Command "flutter" -Arguments @("build", "apk", "--release") -Description "Сборка Android APK"
            $Apk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
            if (-not (Test-Path $Apk)) {
                throw "APK не найден: $Apk. Проверь Android SDK и принятые Android SDK licenses."
            }
            Copy-Item $Apk (Join-Path $ReleaseRoot "flutterdraw-android.apk")
        }
        "Web" {
            Invoke-Checked -Command "flutter" -Arguments @("build", "web", "--release") -Description "Сборка Web"
            $WebFolder = Join-Path $ProjectRoot "build\web"
            if (-not (Test-Path (Join-Path $WebFolder "index.html"))) {
                throw "Web-сборка не найдена: $WebFolder."
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

Write-Host "`nСборка завершена." -ForegroundColor Green
Write-Host "Результаты: $ReleaseRoot" -ForegroundColor Green
Get-ChildItem $ReleaseRoot | Select-Object Name, Length
