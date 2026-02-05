# Java Setup Tool for Windows
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
    Write-Host "=== Java Setup Tool ===" -ForegroundColor Cyan

    # 1. Check/Install Scoop
    $scoopShimPath = "$env:USERPROFILE\scoop\shims"
    $scoopExecutable = "$scoopShimPath\scoop.cmd"
    $scoopInPath = Get-Command scoop -ErrorAction SilentlyContinue

    if (-not $scoopInPath -and (Test-Path $scoopExecutable)) {
        Write-Host "Scoop detected at $scoopShimPath but not in PATH. Adding locally..." -ForegroundColor Yellow
        $env:Path = "$scoopShimPath;" + $env:Path
        $scoopInPath = $true
    }

    if (-not $scoopInPath) {
        Write-Host "Scoop is not installed. Installing Scoop..." -ForegroundColor Yellow
        try {
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
            # Add to current session path immediately after install
            if (Test-Path $scoopShimPath) {
                $env:Path = "$scoopShimPath;" + $env:Path
            }
        }
        catch {
            Write-Error "Failed to install Scoop. Run 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser' and try again."
            Pause-Script
            exit 1
        }
    } else {
        Write-Host "Scoop is installed." -ForegroundColor Green
    }

    # 2. Add 'java' bucket
    # This is critical for JDKs
    Write-Host "Ensuring 'java' bucket is available..." -ForegroundColor Cyan
    # Use full path if command still fails, or rely on just added path
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket add java | Out-Null
        scoop update | Out-Null
    } else {
        # Fallback to direct executable if path update failed for some reason
        & $scoopExecutable bucket add java | Out-Null
        & $scoopExecutable update | Out-Null
    }
    Refresh-Environment

    # Helper to find installed scoop java packages
    function Get-Scoop-Java-Package {
        $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
        # Common openjdk packages in java bucket
        $possible = @("openjdk", "openjdk21", "openjdk17", "openjdk11", "openjdk8", "temurin", "oraclejdk", "temurin8-jdk", "ojdkbuild8", "zulujdk8")
        
        foreach ($p in $possible) {
            if (Test-Path "$scoopPath\apps\$p\current") {
                return $p
            }
        }
        return $null
    }

    # 3. Check current status
    $currentJavaPkg = Get-Scoop-Java-Package
    
    if (Get-Command java -ErrorAction SilentlyContinue) {
        # Use cmd /c to capture stderr (where java -version outputs) without tripping PowerShell error handlers
        $javaVer = cmd /c "java -version 2>&1" | Select-Object -First 1
        Write-Host "Detected installed Java: $javaVer" -ForegroundColor Yellow
        
        if ($currentJavaPkg) {
            Write-Host "Managed by Scoop (Package: $currentJavaPkg)" -ForegroundColor Gray
            Write-Host "1. Install/Switch Version"
            Write-Host "2. Uninstall Current Version ($currentJavaPkg)"
            Write-Host "3. Exit"
            
            $c = Read-Host "Select (1-3)"
            
            if ($c -eq '2') {
                Write-Host "Uninstalling $currentJavaPkg..." -ForegroundColor Yellow
                
                # Robust Uninstall Strategy
                $oldEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                
                try {
                    scoop uninstall $currentJavaPkg
                } catch {
                     Write-Warning "Standard uninstall incomplete. Switching to FORCE cleanup..."
                }

                # Manual Force Cleanup
                $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
                $appDir = "$scoopPath\apps\$currentJavaPkg"
                if (Test-Path $appDir) {
                     Remove-Item -Recurse -Force $appDir -ErrorAction SilentlyContinue
                }
                
                $ErrorActionPreference = $oldEAP
                
                Refresh-Environment
                Write-Host "Uninstalled process execution complete." -ForegroundColor Green
                Pause-Script
                exit 0
            }
            if ($c -eq '3') { exit 0 }
        } else {
             Write-Host "Note: This Java installation is NOT managed by Scoop." -ForegroundColor Gray
             Write-Host "1. Install Scoop Java (Install parallel)"
             Write-Host "2. Exit"
             if ((Read-Host "Select (1-2)") -ne '1') { exit 0 }
        }
    }

    # 4. Version Input
    Write-Host "`nEnter the Java version you want to install." -ForegroundColor Cyan
    Write-Host "Examples: '21', '17', '8', 'latest'"
    $inputVer = Read-Host "Version"

    if ([string]::IsNullOrWhiteSpace($inputVer)) {
        Write-Host "No version entered. Exiting."
        exit 0
    }

    # Helper for package naming
    $pkgCandidates = @()
    
    if ($inputVer -eq 'latest') {
        $pkgCandidates += "openjdk"
    }
    elseif ($inputVer -match '8') {
         # Java 8 has many names
         $pkgCandidates += "openjdk8"
         $pkgCandidates += "temurin8-jdk"
         $pkgCandidates += "ojdkbuild8"
         $pkgCandidates += "zulujdk8"
    }
    elseif ($inputVer -match '^\d+$') {
        # Format 21 -> openjdk21
        $pkgCandidates += "openjdk" + $inputVer
    }
    else {
        # Try direct match
        $pkgCandidates += $inputVer
    }

    $installSuccess = $false
    foreach ($pkg in $pkgCandidates) {
        Write-Host "Attempting to install: $pkg" -ForegroundColor Cyan
        try {
            # Check if manifest exists (dry run essentially, or just try install)
            # Scoop install throws if not found
            scoop install $pkg
            if ($?) { 
                $installSuccess = $true
                break 
            }
        } catch {
            Write-Warning "Package '$pkg' installation failed (or incorrectly named). Trying next..."
        }
    }

    if (-not $installSuccess) {
        Write-Host "Could not install any matching package for input '$inputVer'." -ForegroundColor Red
        Write-Host "Try searching manually: 'scoop search jdk'"
    } else {
        Refresh-Environment
        
        if ($javaPath -and ($javaPath -notmatch "scoop")) {
             $inSystemPath = [Environment]::GetEnvironmentVariable("Path", "Machine") -match [regex]::Escape($javaPath)
             if ($inSystemPath) {
                 Write-Host "`n[CRITICAL WARNING] System Java detected in MACHINE PATH at: $javaPath" -ForegroundColor Red
                 Write-Host "Windows always invokes Machine PATH before User PATH." -ForegroundColor Yellow
                 Write-Host "To make Scoop Java default permanently, you MUST remove the Oracle/System Java path from your System Environment Variables manually." -ForegroundColor Yellow
                 Write-Host "OR restart your computer/terminal to see if any user-path overrides take effect." -ForegroundColor Gray
             }
        }
        
        Refresh-Environment
        if (Get-Command java -ErrorAction SilentlyContinue) {
            $newVer = cmd /c "java -version 2>&1" | Select-Object -First 1
            Write-Host "Success! Java is available: $newVer" -ForegroundColor Green
            if ($newVer -match "1\.8") {
                Write-Host "Note: Java 8 uses 'java -version' (one dash), not '--version'." -ForegroundColor Cyan
            }
        }
    }

} catch {
    Write-Error "An unexpected error occurred: $_"
}

Pause-Script
