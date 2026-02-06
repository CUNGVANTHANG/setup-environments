# PHP Setup Tool for Windows
# Uses Scoop (versions bucket) to manage installation and switching

$ErrorActionPreference = "Stop"

function Pause-Script {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Refresh-Environment {
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

function Check-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop is not installed. Please run setup-nodejs.ps1 (or others) to install Scoop first." -ForegroundColor Red
        Pause-Script
        exit 1
    }
}

function Ensure-Versions-Bucket {
    Write-Host "Checking for 'versions' bucket..." -ForegroundColor Cyan
    $buckets = scoop bucket list
    if ($buckets -notmatch "versions") {
        Write-Host "Adding 'versions' bucket (host of PHP versions)..." -ForegroundColor Yellow
        scoop bucket add versions
    } else {
        Write-Host "'versions' bucket is ready." -ForegroundColor Green
    }
    
    # Ensure we have the latest manifests
    # Write-Host "Updating Scoop manifests..." -ForegroundColor Gray
    # scoop update
}


function Get-Installed-Php {
    $installed = @()
    $output = scoop list
    if ($output) {
        $lines = $output -split "`n"
        foreach ($line in $lines) {
            if ($line -match "^(php[\d\.]*)\s+([^\s]+)") {
                 $installed += $matches[1]
            }
        }
    }
    return $installed
}

try {
    Write-Host "=== PHP Setup Tool ===" -ForegroundColor Cyan
    Check-Scoop
    Ensure-Versions-Bucket

    Write-Host "`nAvailable PHP targets (via Scoop versions bucket):" -ForegroundColor Gray
    $targets = @("php", "php83", "php82", "php81", "php80", "php74")
    
    $installed = Get-Installed-Php
    
    foreach ($t in $targets) {
        if ($installed -contains $t) {
            Write-Host " [Installed] $t" -ForegroundColor Green
        } else {
             Write-Host " [       ] $t" -ForegroundColor Gray
        }
    }

function Enable-Extensions {
    Write-Host "Configuring PHP extensions for Laravel..." -ForegroundColor Cyan
    
    # Get active php.ini path
    $phpInfo = php --ini
    $iniPathLine = $phpInfo | Select-String "Loaded Configuration File"
    if ($iniPathLine -match ":\s*(.*)$") {
        $iniPath = $matches[1].Trim()
    }

    if (-not (Test-Path $iniPath)) {
        Write-Error "Could not locate php.ini at: $iniPath"
        return
    }

    Write-Host "Editing: $iniPath" -ForegroundColor Gray
    
    $content = Get-Content $iniPath
    $newContent = @()
    $extensions = @("fileinfo", "pdo_mysql", "mbstring", "openssl", "curl", "gd", "zip")
    $modified = $false

    foreach ($line in $content) {
        $newLine = $line
        foreach ($ext in $extensions) {
            # Regex to find commented out extension: ;extension=fileinfo
            if ($line -match "^;\s*extension\s*=\s*$ext") {
                 $newLine = "extension=$ext"
                 $modified = $true
                 Write-Host " [Enabled] $ext" -ForegroundColor Green
            }
        }
        $newContent += $newLine
    }

    if ($modified) {
        Set-Content -Path $iniPath -Value $newContent
        Write-Host "Extensions enabled successfully." -ForegroundColor Green
    } else {
        Write-Host "Required extensions seem to be already enabled." -ForegroundColor Yellow
    }
}

# ... (inside existing script)

    Write-Host "`nActions:"
    Write-Host "1. Install a specific version"
    Write-Host "2. Switch active version (scoop reset)"
    Write-Host "3. Uninstall a version"
    Write-Host "4. Enable Extensions (Laravel)"
    Write-Host "5. Exit"

    $choice = Read-Host "Select an option (1-5)"

    switch ($choice) {
        # ... cases 1, 2, 3 same as before ...
        "1" {
            # ... (keep existing case 1) ...
            $inputVer = Read-Host "Enter version to install (e.g., 8.2 or php8.2)"
            
            # Normalize: If user types "8.2" or "83", result should be "php82" or "php83"
            if ($inputVer -match "^\d+(\.\d+)?$") {
                $ver = "php" + ($inputVer -replace '\.', '')
            } else {
                $ver = $inputVer
            }

            if (-not ($targets -contains $ver)) {
                Write-Warning "Target '$ver' is not in the standard list."
                $confirm = Read-Host "Try checking Scoop anyway? (y/n)"
                if ($confirm -ne 'y') { exit }
            }
            
            Write-Host "Installing $ver..." -ForegroundColor Cyan
            scoop install $ver
            
            if ($LASTEXITCODE -eq 0) {
                Refresh-Environment
                Write-Host "`nInstalled successfully." -ForegroundColor Green
            } else {
                Write-Host "`nInstallation failed." -ForegroundColor Red
            }
        }
        "2" {
            # ... (keep existing case 2) ...
            $inputVer = Read-Host "Enter version to switch to (e.g., 8.2 or php8.2)"
            
            if ($inputVer -match "^\d+(\.\d+)?$") {
                $ver = "php" + ($inputVer -replace '\.', '')
            } else {
                $ver = $inputVer
            }

            if ($installed -notcontains $ver) {
                Write-Warning "'$ver' does not seem to be installed."
                $confirm = Read-Host "Try resetting anyway? (y/n)"
                if ($confirm -ne 'y') { exit }
            }
            Write-Host "Switching to $ver..." -ForegroundColor Cyan
            
            # scoop reset logic
            scoop reset $ver
            
            if ($LASTEXITCODE -eq 0) {
                Refresh-Environment
                $current = cmd /c "php -v 2>&1" | Select-Object -First 1
                Write-Host "Active Version: $current" -ForegroundColor Green
            } else {
                 Write-Host "Switch failed." -ForegroundColor Red
            }
        }
        "3" {
            # ... (keep existing case 3) ...
            $inputVer = Read-Host "Enter version to uninstall (e.g., 8.2)"
             if ($inputVer -match "^\d+(\.\d+)?$") {
                $ver = "php" + ($inputVer -replace '\.', '')
            } else {
                $ver = $inputVer
            }
            
            Write-Host "Uninstalling $ver..." -ForegroundColor Yellow
            scoop uninstall $ver
            Write-Host "Done." -ForegroundColor Green
        }
        "4" {
            Enable-Extensions
        }
        "5" {
            exit 0
        }
        Default {
            Write-Host "Invalid option." -ForegroundColor Red
        }
    }

    Pause-Script

} catch {
    Write-Error "An error occurred: $_"
    Pause-Script
}
