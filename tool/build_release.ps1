[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$flutterSource = (Get-Command flutter -ErrorAction Stop).Source
$flutterSdkRoot = Split-Path -Parent (Split-Path -Parent $flutterSource)
$flutterCommand = $flutterSource
$dartCommand = Join-Path $flutterSdkRoot 'bin\dart.bat'

# Flutter native-asset hooks on Windows may split an SDK path that contains
# spaces. Invoke the same SDK through a temporary junction with a safe path.
if ($flutterSdkRoot -match '\s') {
    $flutterSdkLink = Join-Path ([System.IO.Path]::GetTempPath()) 'waste-classification-flutter-sdk'
    if (Test-Path -LiteralPath $flutterSdkLink) {
        $existingLink = Get-Item -LiteralPath $flutterSdkLink
        $existingTarget = [string]$existingLink.Target
        if ($existingLink.LinkType -ne 'Junction' -or
            $existingTarget -ne $flutterSdkRoot) {
            throw "Cannot use Flutter SDK junction at $flutterSdkLink."
        }
    }
    else {
        [void](New-Item -ItemType Junction -Path $flutterSdkLink -Target $flutterSdkRoot)
    }

    $flutterCommand = Join-Path $flutterSdkLink 'bin\flutter.bat'
    $dartCommand = Join-Path $flutterSdkLink 'bin\dart.bat'
}

function Invoke-CheckedStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    Write-Host "`n==> $Name" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

Push-Location $projectRoot
try {
    Invoke-CheckedStep 'Checking Dart formatting' {
        & $dartCommand format --output=none --set-exit-if-changed lib test
    }
    Invoke-CheckedStep 'Cleaning stale Flutter and Gradle outputs' {
        & $flutterCommand clean
    }
    Invoke-CheckedStep 'Resolving dependencies' {
        & $flutterCommand pub get
    }
    Invoke-CheckedStep 'Running static analysis' {
        & $flutterCommand analyze --no-pub
    }
    Invoke-CheckedStep 'Running tests' {
        & $flutterCommand test --no-pub
    }
    Invoke-CheckedStep 'Building release APK' {
        & $flutterCommand build apk --release --no-pub
    }

    if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
        throw "Release APK was not created at $apkPath."
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $requiredEntries = @(
        'assets/flutter_assets/AssetManifest.bin',
        'assets/flutter_assets/assets/translations/en.json',
        'assets/flutter_assets/assets/translations/vi.json',
        'assets/flutter_assets/assets/fonts/BeVietnamPro-Regular.ttf',
        'assets/flutter_assets/assets/fonts/BeVietnamPro-SemiBold.ttf',
        'assets/flutter_assets/assets/fonts/BeVietnamPro-Bold.ttf'
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
    try {
        $entryNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )
        foreach ($entry in $archive.Entries) {
            [void]$entryNames.Add($entry.FullName)
        }

        $missingEntries = @(
            $requiredEntries | Where-Object { -not $entryNames.Contains($_) }
        )
        if ($missingEntries.Count -gt 0) {
            throw "APK is missing required Flutter assets:`n$($missingEntries -join "`n")"
        }
    }
    finally {
        $archive.Dispose()
    }

    $apk = Get-Item -LiteralPath $apkPath
    $sha256 = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()

    Write-Host "`nRelease APK verified successfully." -ForegroundColor Green
    Write-Host "Path:    $($apk.FullName)"
    Write-Host "Size:    $($apk.Length) bytes"
    Write-Host "SHA-256: $sha256"
}
finally {
    Pop-Location
}
