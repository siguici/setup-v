﻿#!/usr/bin/env pwsh
#requires -RunAsAdministrator
<#
.SYNOPSIS
    Vlang installation and update script.

.DESCRIPTION
    This script installs and updates Vlang (the V programming language) on Windows.
    It downloads the latest version, extracts it, builds Vlang if necessary,
    and adds the executable to the system path.

.PARAMETER version
    The version to install (default: "latest"). If "latest" is specified,
    the latest stable version is used.

.PARAMETER installDir
    The directory where Vlang will be installed.
    Default: `$env:USERPROFILE\vlang`.

.PARAMETER force
    Forces the installation even if the specified version is already installed.

.PARAMETER quiet
    Suppresses detailed log output.

.PARAMETER dryRun
    Displays what would be done without actually performing the actions.

.PARAMETER check
    Checks if Vlang is already installed and displays its version.

.PARAMETER update
    Updates Vlang only if a newer version is available.

.PARAMETER link
    Creates a symbolic link for the executable after installation.

.PARAMETER noLink
    Does not create a symbolic link for the executable after installation.

.PARAMETER help
    Displays usage help and exits.

#>


param (
    [string]$version = "latest",
    [string]$installDir = "$env:USERPROFILE\vlang",
    [switch]$force,
    [switch]$quiet,
    [switch]$check,
    [switch]$dryRun,
    [switch]$update,
    [switch]$link = $true,
    [switch]$noLink,
    [switch]$help
)

# Show help message
if ($help -or $args -contains '-?') {
    Write-Host @"
Vlang Installer Script

USAGE:
    .\install.ps1 [-version <version>] [-installDir <path>] [-force] [-quiet]
                  [-dryRun] [-check] [-update] [-link] [-noLink] [-help]

OPTIONS:
    -version     Specify version to install (default: latest)
    -installDir  Directory to install Vlang (default: $env:USERPROFILE\vlang)
    -force       Force reinstall even if already installed
    -quiet       Suppress log output
    -dryRun      Simulate actions without making changes
    -check       Show current installed version of Vlang
    -update      Run 'v up' to update Vlang
    -link        Create symlink to 'v' (enabled by default)
    -noLink      Disable symlink creation
    -help        Show this help message
"@
    exit 0
}


[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# Ensure the script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "⚠️ This script must be run as Administrator!"
    exit 1
}


function Write-Log {
    param (
        [string]$message,
        [ConsoleColor]$color = [ConsoleColor]::White
    )
    if (-not $quiet) {
        Write-Host $message -ForegroundColor $color
    }
}


# Get the latest version from GitHub API
function Get-LatestVersion {
    $url = "https://api.github.com/repos/vlang/v/releases/latest"
    try {
        return (Invoke-RestMethod -Uri $url).tag_name
    } catch {
        Write-Log "❌ Failed to fetch latest release. Falling back to 'latest'." Red
        return "latest"
    }
}


# Download V from the provided URL
function Download-Vlang {
    param (
        [string]$url,
        [string]$destination
    )
    Write-Log "📥 Downloading V from $url..."
    if (-not $dryRun) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
        } catch {
            Write-Log "❌ Download failed. Check your internet connection." Red
            exit 1
        }
    } else {
        Write-Log "[dry-run] Would download V from $url to $destination" Yellow
    }
}

# Extract the downloaded V package
function Extract-Vlang {
    param (
        [string]$archivePath,
        [string]$targetPath
    )
    Write-Log "📦 Extracting V to $targetPath..."
    if (-not $dryRun) {
        Expand-Archive -Path $archivePath -DestinationPath $targetPath -Force
    } else {
        Write-Log "[dry-run] Would extract $archivePath to $targetPath" Yellow
    }
}

# Build V using the make.bat script
function Build-V {
    param ([string]$path)
    $makePath = Join-Path $path "make.bat"
    if (Test-Path $makePath) {
        Write-Log "⚙️ Building V using make.bat..."
        if (-not $dryRun) {
            Start-Process -NoNewWindow -Wait -FilePath $makePath -ArgumentList "/NoLogo"
        } else {
            Write-Log "[dry-run] Would run make.bat in $path" Yellow
        }
    }
}

# Create the symlink for the V executable
function Symlink-V {
    param ([string]$vExePath)
    if ($link -and (Test-Path $vExePath)) {
        Write-Log "🔗 Creating V executable symlink..."
        if (-not $dryRun) {
            Start-Process -NoNewWindow -Wait -FilePath $vExePath -ArgumentList "symlink"
        } else {
            Write-Log "[dry-run] Would run 'v.exe symlink'" Yellow
        }
    }
}

# Update the system PATH variable to include Vlang
function Update-SystemPath {
    param ([string]$vPath)
    Write-Log "➕ Adding V to system PATH..."
    if (-not $dryRun) {
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$vPath", [System.EnvironmentVariableTarget]::Machine)
    } else {
        Write-Log "[dry-run] Would add $vPath to system PATH" Yellow
    }
}

function Check-InstalledVersion {
    $vCmd = Get-Command v -ErrorAction SilentlyContinue
    if ($vCmd) {
        Write-Log "✅ V is installed at: $($vCmd.Source)" Green
        & $vCmd.Source version
    } else {
        Write-Log "❌ V is not installed." Red
    }
}

# Install Vlang
function Install-Vlang {
    if ($version -eq "latest") {
        Write-Log "🔍 Fetching latest V version..."
        $script:version = Get-LatestVersion
    }

    $zipFileName = "v_windows.zip"
    $downloadUrl = "https://github.com/vlang/v/releases/download/$version/$zipFileName"
    $tempZipPath = Join-Path $env:TEMP $zipFileName

    Download-Vlang -url $downloadUrl -destination $tempZipPath

    if (Test-Path $installDir) {
        Write-Log "🗑️ Removing previous installation from $installDir..."
        if (-not $dryRun) {
            Remove-Item -Recurse -Force -Path $installDir
        } else {
            Write-Log "[dry-run] Would remove $installDir" Yellow
        }
    }

    Write-Log "📁 Creating installation directory: $installDir"
    if (-not $dryRun) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    } else {
        Write-Log "[dry-run] Would create directory $installDir" Yellow
    }

    Extract-Vlang -archivePath $tempZipPath -targetPath $installDir

    if (-not $dryRun -and (Test-Path $tempZipPath)) {
        Remove-Item -Path $tempZipPath -Force
    }

    $vPath = Join-Path $installDir "v"
    Build-V -path $vPath
    Symlink-V -vExePath (Join-Path $vPath "v.exe")
    Update-SystemPath -vPath $vPath

    if (-not $dryRun) {
        "$version" | Out-File -Encoding UTF8 -FilePath "$installDir\vlang.version"
    } else {
        Write-Log "[dry-run] Would write version file to $installDir\vlang.version" Yellow
    }

    Write-Log "✅ Vlang has been installed to $vPath. Restart your terminal to begin using 'v'." Green
}

function Update-Vlang {
    Write-Log "🔄 Running 'v up' to update V..."
    $vCmd = Get-Command v -ErrorAction SilentlyContinue
    if ($vCmd) {
        if (-not $dryRun) {
            Start-Process -NoNewWindow -Wait -FilePath $vCmd.Source -ArgumentList "up"
        } else {
            Write-Log "[dry-run] Would run 'v up'" Yellow
        }
    } else {
        Write-Log "❌ V is not installed. Cannot run 'v up'." Red
    }
}


# -------- Main Logic --------

$installDir = [System.IO.Path]::GetFullPath($installDir)
$vPath = Join-Path $installDir "v"
$vExePath = Join-Path $vPath "v.exe"

if ($check) {
    Check-InstalledVersion
    exit 0
}

# Handle update option
if ($update) {
    Update-Vlang
    exit 0
}

# Check if version is already installed
if ((Test-Path "$installDir\vlang.version") -and (-not $force)) {
    $installedVersion = Get-Content "$installDir\vlang.version"
    if ($installedVersion -eq $version) {
        Write-Log "🆗 Version $version is already installed. Nothing to do."
        exit 0
    }
}

# Handle --force
if ($force) {
    Write-Log "🧨 Force mode enabled — reinstalling Vlang..." Yellow
}


# Check if V is already installed
$vInstalled = Get-Command v -ErrorAction SilentlyContinue
if ($vInstalled -and -not $force) {
    Write-Log "✅ V is already installed. Running 'v up'..." Green
    if (-not $dryRun) {
        Start-Process -NoNewWindow -Wait -FilePath $vInstalled.Source -ArgumentList "up"
    } else {
        Write-Log "[dry-run] Would run 'v up'" Yellow
    }
    exit 0
}


Install-Vlang

# Post-install: test V
if (-not $dryRun) {
    try {
        & "$vExePath" version
    } catch {
        Write-Error "❌ Something went wrong. V executable could not run."
        exit 1
    }
} else {
    Write-Log "[dry-run] Would run '$vExePath version'" Yellow
}


# Cleanup .vmodules
$cacheDir = "$env:USERPROFILE\.vmodules"
if (Test-Path $cacheDir) {
    Write-Log "🧼 Deleting .vmodules cache..."
    if (-not $dryRun) {
        Remove-Item -Recurse -Force -Path $cacheDir
    } else {
        Write-Log "[dry-run] Would delete $cacheDir" Yellow
    }
}


# Add to PowerShell profile
if (-not ($env:Path -like "*$installDir*")) {
    $profilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    if (-not (Test-Path $profilePath)) {
        if (-not $dryRun) {
            New-Item -ItemType File -Path $profilePath -Force | Out-Null
        } else {
            Write-Log "[dry-run] Would create PowerShell profile at $profilePath" Yellow
        }
    }
    if (-not $dryRun) {
        # Ensure no duplicates in the profile file
        if (-not (Get-Content $profilePath | Select-String -Pattern $installDir)) {
            Add-Content $profilePath "`$env:Path += `";$installDir`""
        }
    } else {
        Write-Log "[dry-run] Would add Vlang to PowerShell profile" Yellow
    }
    Write-Log "🛠️ Added Vlang to your PowerShell profile (for future sessions)."
}
