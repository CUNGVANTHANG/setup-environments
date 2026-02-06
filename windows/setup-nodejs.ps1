# Node.js Setup Tool for Windows
# Uses Scoop to manage installation
# Features: Version Selection, Uninstallation, Path Refresh

$ErrorActionPreference = "Stop"

function Pause-Script {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Refresh-Environment {
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

function Get-Installed-Node {
    # Check common scoop node package names
    $packages = @("nodejs-lts", "nodejs", "nodejs22", "nodejs20", "nodejs18")
    foreach ($pkg in $packages) {
        if (scoop list $pkg | Select-String $pkg -Quiet) {
            return $pkg
        }
    }
    return $null
}

try {
    Write-Host "=== Node.js Setup Tool ===" -ForegroundColor Cyan

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

    # 3. Check current status
    Refresh-Environment
    $currentPkg = Get-Installed-Node
    
    if ($currentPkg) {
        $nodeVer = node -v
        Write-Host "Detected installed Node.js: $nodeVer (Package: $currentPkg)" -ForegroundColor Yellow
        Write-Host "1. Uninstall Current Version"
        Write-Host "2. Switch Version (Uninstall current & Install new)"
        Write-Host "3. Exit"
        
        $choice = Read-Host "Select an option (1-3)"
        
        switch ($choice) {
            '1' {
                scoop uninstall $currentPkg
                Refresh-Environment
                Write-Host "Uninstalled successfully." -ForegroundColor Green
                Pause-Script
                exit 0
            }
            '2' {
                scoop uninstall $currentPkg
                # Fall through to installation menu
            }
            '3' { exit 0 }
            Default { exit 0 }
        }
    }

    # 4. Installation Menu
    Write-Host "`nSelect Node.js Version to Install:" -ForegroundColor Cyan
    Write-Host "1. Node.js LTS (Recommended) [nodejs-lts]"
    Write-Host "2. Node.js Latest [nodejs]"
    Write-Host "3. Node.js 22 [nodejs22]"
    Write-Host "4. Node.js 20 [nodejs20]"
    Write-Host "5. Node.js 18 [nodejs18]"
    Write-Host "0. Exit"

    $installChoice = Read-Host "Enter number (1-5)"
    
    $pkgToInstall = ""
    switch ($installChoice) {
        '1' { $pkgToInstall = "nodejs-lts" }
        '2' { $pkgToInstall = "nodejs" }
        '3' { $pkgToInstall = "nodejs22" }
        '4' { $pkgToInstall = "nodejs20" }
        '5' { $pkgToInstall = "nodejs18" }
        '0' { exit 0 }
        Default { Write-Host "Invalid choice."; exit 1 }
    }

    if ($pkgToInstall) {
        Write-Host "Installing $pkgToInstall..." -ForegroundColor Cyan
        scoop install $pkgToInstall
        
        Refresh-Environment
        
        if (Get-Command node -ErrorAction SilentlyContinue) {
            $newVer = node -v
            Write-Host "Success! Node.js $newVer installed." -ForegroundColor Green
            Write-Host "Location: $(Get-Command node | Select-Object -ExpandProperty Source)" -ForegroundColor Gray
        } else {
            Write-Warning "Installation finished, but 'node' command not found yet. You may need to restart PowerShell."
        }
    }

} catch {
    Write-Error "An unexpected error occurred: $_"
}

Pause-Script
