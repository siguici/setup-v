#requires -RunAsAdministrator

param (
    [string]$version = "latest",
    [string]$installDir = "$env:USERPROFILE\vlang",
    [switch]$force,
    [switch]$quiet,
    [switch]$check,
    [switch]$dryRun
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# Verify if the script is running with Administrator privileges
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

function Get-LatestVersion {
    $url = "https://api.github.com/repos/vlang/v/releases/latest"
    try {
        return (Invoke-RestMethod -Uri $url).tag_name
    } catch {
        Write-Log "❌ Failed to fetch latest release. Falling back to 'latest'." Red
        return "latest"
    }
}

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
    }
}

function Extract-Vlang {
    param (
        [string]$archivePath,
        [string]$targetPath
    )
    Write-Log "📦 Extracting V to $targetPath..."
    if (-not $dryRun) {
        Expand-Archive -Path $archivePath -DestinationPath $targetPath -Force
    }
}

function Build-V {
    param ([string]$path)
    $makePath = Join-Path $path "make.bat"
    if (Test-Path $makePath) {
        Write-Log "⚙️ Building V using make.bat..."
        if (-not $dryRun) {
            Start-Process -NoNewWindow -Wait -FilePath $makePath
        }
    }
}

function Symlink-V {
    param ([string]$vExePath)
    if (Test-Path $vExePath) {
        Write-Log "🔗 Creating V executable symlink..."
        if (-not $dryRun) {
            Start-Process -NoNewWindow -Wait -FilePath $vExePath -ArgumentList "symlink"
        }
    }
}

function Update-SystemPath {
    param ([string]$vPath)
    Write-Log "➕ Adding V to system PATH..."
    if (-not $dryRun) {
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$vPath", [System.EnvironmentVariableTarget]::Machine)
    }
}

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
        }
    }

    Write-Log "📁 Creating installation directory: $installDir"
    if (-not $dryRun) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    Extract-Vlang -archivePath $tempZipPath -targetPath $installDir

    if (-not $dryRun) {
        Remove-Item -Path $tempZipPath -Force
    }

    $vPath = Join-Path $installDir "v"
    Build-V -path $vPath
    Symlink-V -vExePath (Join-Path $vPath "v.exe")
    Update-SystemPath -vPath $vPath

    Write-Log "✅ Vlang has been installed to $vPath. Restart your terminal to begin using 'v'." Green
}

# -------- Main Logic --------

$installDir = [System.IO.Path]::GetFullPath($installDir)
$vPath = Join-Path $installDir "v"
$vExePath = Join-Path $vPath "v.exe"

# Check if version is already installed
if ((Test-Path "$installDir\vlang.version") -and (-not $force)) {
    $installedVersion = Get-Content "$installDir\vlang.version"
    if ($installedVersion -eq $version) {
        Write-Log "🆗 Version $version is already installed. Nothing to do."
        exit 0
    }
}

# Handle --check flag
if ($check) {
    $vCmd = Get-Command v -ErrorAction SilentlyContinue
    if ($vCmd) {
        Write-Log "✅ V is installed at: $($vCmd.Source)" Green
        & $vCmd.Source version
    } else {
        Write-Log "❌ V is not installed." Red
    }
    exit 0
}

# Handle --force flag
if ($force) {
    Write-Log "🧨 Force mode enabled — reinstalling Vlang..." Yellow
}

# Check if V is already installed
$vInstalled = Get-Command v -ErrorAction SilentlyContinue
if ($vInstalled -and -not $force) {
    Write-Log "✅ V is already installed. Running 'v up'..." Green
    if (-not $dryRun) {
        Start-Process -NoNewWindow -Wait -FilePath $vInstalled.Source -ArgumentList "up"
    }
    exit 0
}

Install-Vlang

# Create vlang version file
"$version" | Out-File -Encoding UTF8 -FilePath "$installDir\vlang.version"

# Test the executable after installation
try {
    & "$installDir\v.exe" version
} catch {
    Write-Error "❌ Something went wrong. V executable could not run."
    exit 1
}

# Cleanup .vmodules cache if necessary
$cacheDir = "$env:USERPROFILE\.vmodules"
if (Test-Path $cacheDir) {
    Write-Log "🧼 Deleting .vmodules cache..."
    if (-not $dryRun) {
        Remove-Item -Recurse -Force -Path $cacheDir
    }
}

# Add to profile if necessary
if (-not ($env:Path -like "*$installDir*")) {
    $profilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    Add-Content $profilePath "`$env:Path += `";$InstallDir`""
    Write-Log "🛠️ Added Vlang to your PowerShell profile (for future sessions)."
}

