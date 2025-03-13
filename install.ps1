#requires -RunAsAdministrator

param (
    [string]$Version = "latest",
    [string]$InstallDir = "$env:USERPROFILE\vlang"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

if (Get-Command v -ErrorAction SilentlyContinue) {
    Write-Host "✅ Vlang is already installed! Updating with 'v up'..." -ForegroundColor Green
    Start-Process -NoNewWindow -Wait -FilePath "v" -ArgumentList "up"
    exit 0
}

$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$InstallPath = "$InstallDir\v"

if (Test-Path -Path $InstallPath) {
    if (Test-Path -Path "$InstallPath\v.exe") {
        Write-Host "🔗 Running 'v.exe symlink' in $InstallPath..."
        Start-Process -NoNewWindow -Wait -FilePath "$InstallPath\v.exe" -ArgumentList "symlink"
        exit 0
    } elseif (Test-Path -Path "$InstallPath\make.bat") {
        Write-Host "⚙️ Running 'make.bat' to build V..."
        Start-Process -NoNewWindow -Wait -FilePath "$InstallPath\make.bat"
        exit 0
    }
} else {
    Write-Host "📂 Creating installation directory: $InstallDir"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

function Get-LatestRelease {
    $url = "https://api.github.com/repos/vlang/v/releases/latest"
    try {
        return (Invoke-RestMethod -Uri $url).tag_name
    } catch {
        Write-Host "❌ Failed to fetch latest release. Using 'latest'." -ForegroundColor Red
        return "latest"
    }
}

function Download-Vlang {
    param ([string]$url, [string]$outputPath)

    Write-Host "📥 Downloading Vlang from $url..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
    } catch {
        Write-Host "❌ Download failed! Check your internet connection." -ForegroundColor Red
        exit 1
    }
}

function Extract-Vlang {
    param ([string]$zipPath, [string]$extractPath)

    Write-Host "📦 Extracting Vlang..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
}

function Install-Vlang {
    if ($Version -eq "latest") {
        Write-Host "🔍 Fetching latest Vlang version..."
        $Version = Get-LatestRelease
    }

    $zipName = "v_windows.zip"
    $downloadUrl = "https://github.com/vlang/v/releases/download/$Version/$zipName"
    $zipPath = "$env:TEMP\$zipName"

    Download-Vlang -url $downloadUrl -outputPath $zipPath

    if (Test-Path -Path $InstallDir) {
        Write-Host "🗑️ Removing existing installation..."
        Remove-Item -Recurse -Force -Path $InstallDir
    }

    Extract-Vlang -zipPath $zipPath -extractPath $InstallDir
    Remove-Item -Path $zipPath -Force
    Write-Host "🧹 Cleanup completed."

    Set-Location -Path $InstallPath

    if (Test-Path -Path "$InstallPath\make.bat") {
        Write-Host "⚙️ Running 'make.bat' to build V..."
        Start-Process -NoNewWindow -Wait -FilePath "$InstallPath\make.bat"
    }

    Write-Host "🔗 Running 'v.exe symlink'..."
    Start-Process -NoNewWindow -Wait -FilePath "$InstallPath\v.exe" -ArgumentList "symlink"

    Write-Host "➕ Adding Vlang to system PATH..."
    [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$InstallPath", [System.EnvironmentVariableTarget]::Machine)

    Write-Host "🎉 Vlang has been installed in $InstallPath! Restart your terminal to use `"v`"." -ForegroundColor Green
}

Install-Vlang
