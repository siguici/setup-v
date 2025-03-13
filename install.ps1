#requires -RunAsAdministrator

param (
    [string]$Version = "latest",
    [string]$InstallDir = "$env:USERPROFILE\vlang"
)

$ErrorActionPreference = "Stop"
$CreatedDir = $false

if (Get-Command v -ErrorAction SilentlyContinue) {
    Write-Host "✅ Vlang is already installed! Skipping installation..." -ForegroundColor Green
    exit 0
}

if (-Not (Test-Path -Path $InstallDir)) {
    Write-Host "📂 Creating installation directory: $InstallDir"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $CreatedDir = $true
}

function Get-LatestRelease {
    $url = "https://api.github.com/repos/vlang/v/releases/latest"
    $response = Invoke-RestMethod -Uri $url
    return $response.tag_name
}

function Download-Vlang {
    param ([string]$url, [string]$outputPath)

    Write-Host "📥 Downloading Vlang from $url..."
    Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
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
    Extract-Vlang -zipPath $zipPath -extractPath $InstallDir

    Remove-Item -Path $zipPath -Force
    Write-Host "🧹 Cleanup completed."

    Set-Location -Path $InstallDir

    Write-Host "⚙️ Running `"make`" to build V..."
    Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c make"

    Write-Host "🔗 Creating symlink for V..."
    Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c v symlink"

    Write-Host "🎉 Vlang has been installed in $InstallDir! Restart your terminal to use `"v`"." -ForegroundColor Green
}

Install-Vlang
