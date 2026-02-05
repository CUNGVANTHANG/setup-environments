# Python Setup Tool for Windows
# Uses Scoop to manage installation
# Features: Specific Version Input, Uninstallation, Path Refresh

$ErrorActionPreference = "Stop"

function Pause-Script {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Refresh-Environment {
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

try {
    Write-Host "=== Python Setup Tool ===" -ForegroundColor Cyan

    # 1. Check/Install Scoop
    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop is not installed. Installing Scoop..." -ForegroundColor Yellow
        try {
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
        }
        catch {
            Write-Error "Failed to install Scoop. Run 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser' and try again."
            Pause-Script
            exit 1
        }
    } else {
        Write-Host "Scoop is installed." -ForegroundColor Green
    }

    # 2. Add 'versions' bucket (silent if exists)
    Write-Host "Ensuring 'versions' bucket is available..." -ForegroundColor Cyan
    scoop bucket add versions | Out-Null
    scoop update | Out-Null
    Refresh-Environment

    # 3. Check current status & Main Menu
    
    # Helper to find installed scoop python packages
    function Get-Scoop-Python-Package {
        $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
        $possible = @("python", "python312", "python311", "python310", "python39", "python38", "python37", "python27")
        
        foreach ($p in $possible) {
            if (Test-Path "$scoopPath\apps\$p\current") {
                return $p
            }
        }
        return $null
    }

    $currentPyPkg = Get-Scoop-Python-Package

    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pyVer = python --version 2>&1
        Write-Host "Detected installed Python: $pyVer" -ForegroundColor Yellow
        
        if ($currentPyPkg) {
            Write-Host "Managed by Scoop (Package: $currentPyPkg)" -ForegroundColor Gray
            Write-Host "1. Install/Switch Version"
            Write-Host "2. Uninstall Current Version ($currentPyPkg)"
            Write-Host "3. Exit"
            
            $c = Read-Host "Select (1-3)"
            
            if ($c -eq '2') {
                Write-Host "Uninstalling $currentPyPkg..." -ForegroundColor Yellow
                
                # Temporarily relax error handling as Scoop uninstall script may fail on registry keys
                # This is a known issue with non-admin Scoop Python uninstallers
                $oldEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                
                try {
                    scoop uninstall $currentPyPkg
                } catch {
                    Write-Warning "Standard uninstall failed (registry permission). switching to FORCE cleanup..."
                    
                    # Manual Cleanup Strategy
                    $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
                    $appDir = "$scoopPath\apps\$currentPyPkg"
                    
                    if (Test-Path $appDir) {
                        Write-Host "Removing app directory: $appDir" -ForegroundColor Gray
                        Remove-Item -Recurse -Force $appDir -ErrorAction SilentlyContinue
                    }
                    
                    # Remove common shims
                    $shims = @("python", "python3", "pip", "pip3", "idle", "idle3", "$currentPyPkg")
                    foreach ($shim in $shims) {
                        $shimPath = "$scoopPath\shims\$shim.exe"
                        if (Test-Path $shimPath) {
                            Remove-Item -Force $shimPath -ErrorAction SilentlyContinue
                        }
                         $shimPathShim = "$scoopPath\shims\$shim.shim"
                        if (Test-Path $shimPathShim) {
                            Remove-Item -Force $shimPathShim -ErrorAction SilentlyContinue
                        }
                    }
                    Write-Host "Force cleanup completed." -ForegroundColor Yellow
                }
                
                $ErrorActionPreference = $oldEAP
                
                Refresh-Environment
                Write-Host "Uninstalled process execution complete." -ForegroundColor Green
                Pause-Script
                exit 0
            }
            if ($c -eq '3') { exit 0 }
            # If 1, proceed to installation logic below
        } else {
            Write-Host "Note: This Python installation does not appear to be managed by Scoop or is not a recognized package name." -ForegroundColor Gray
            Write-Host "1. Install/Switch Version (Will install alongside)"
            Write-Host "2. Exit"
            if ((Read-Host "Select (1-2)") -ne '1') { exit 0 }
        }
    } else {
        # Not installed, strictly proceed to install
        Write-Host "Python is not installed."
    }

    # 4. Version Input
    Write-Host "`nEnter the Python version you want to install." -ForegroundColor Cyan
    Write-Host "Examples: '3.12', '3.11', '3.10', 'latest', or specific like '3.12.4' (if available)"
    $inputVer = Read-Host "Version"

    if ([string]::IsNullOrWhiteSpace($inputVer)) {
        Write-Host "No version entered. Exiting."
        exit 0
    }

    $pkgToInstall = ""
    
    if ($inputVer -eq 'latest') {
        $pkgToInstall = "python"
    }
    elseif ($inputVer -match '^\d+\.\d+$') {
        # Format 3.12 -> python312
        $pkgToInstall = "python" + $inputVer.Replace('.', '')
    }
    else {
        # Try direct match first (e.g. python@3.12.4)
        $pkgToInstall = "python@$inputVer"
    }

    Write-Host "Attempting to install: $pkgToInstall" -ForegroundColor Cyan
    
    # Try install
    try {
        scoop install $pkgToInstall
    } catch {
        Write-Warning "Direct install failed. Trying to search for close matches..."
        # Fallback search if needed, but scoop usually gives good error msgs
        scoop search python
    }

    Refresh-Environment
    
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $newVer = python --version 2>&1
        Write-Host "Success! Python is available: $newVer" -ForegroundColor Green
        Write-Host "Location: $(Get-Command python | Select-Object -ExpandProperty Source)" -ForegroundColor Gray
    } else {
        Write-Warning "Installation finished, but 'python' command not found yet. You may need to restart PowerShell."
    }

} catch {
    Write-Error "An unexpected error occurred: $_"
}

Pause-Script
