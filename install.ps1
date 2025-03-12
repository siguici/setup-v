#requires -RunAsAdministrator

param (
    [string]$Version = "latest",
    [string]$InstallDir = "$env:USERPROFILE\vlang"
)

$ErrorActionPreference = "Stop"

function Get-LatestRelease {
    $url = "https://api.github.com/repos/vlang/v/releases/latest"
    $response = Invoke-RestMethod -Uri $url
    return $response.tag_name
}

function Download-Vlang {
    param ([string]$url, [string]$outputPath)

    Write-Host "Downloading Vlang from $url..."
    Invoke-WebRequest -Uri $url -OutFile $outputPath
}

function Extract-Vlang {
    param ([string]$zipPath, [string]$extractPath)

    Write-Host "Extracting Vlang..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
}

function Install-Vlang {
    if ($Version -eq "latest") {
        $Version = Get-LatestRelease
    }

    $zipName = "v_windows.zip"
    $downloadUrl = "https://github.com/vlang/v/releases/download/$Version/$zipName"
    $zipPath = "$env:TEMP\$zipName"

    if (-Not (Test-Path -Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }

    Download-Vlang -url $downloadUrl -outputPath $zipPath
    Extract-Vlang -zipPath $zipPath -extractPath $InstallDir

    Remove-Item -Path $zipPath -Force

    Write-Host "Vlang has been installed in $InstallDir"
}

Install-Vlang
