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

$vInstalled = Get-Command v -ErrorAction SilentlyContinue
if ($vInstalled -and -not $force) {
    Write-Log "✅ V is already installed. Running 'v up'..." Green
    if (-not $dryRun) {
        Start-Process -NoNewWindow -Wait -FilePath $vInstalled.Source -ArgumentList "up"
    }
    exit 0
}

if (Test-Path $vExePath) {
    Symlink-V -vExePath $vExePath
    exit 0
}

$makeFilePath = Join-Path $vPath "make.bat"
if (Test-Path $makeFilePath) {
    Build-V -path $vPath
    exit 0
}

if (-not (Test-Path $installDir)) {
    Write-Log "📁 Creating installation directory: $installDir"
    if (-not $dryRun) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }
}

Install-Vlang
