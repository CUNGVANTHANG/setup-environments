# Java Home Setup Tool for Windows
# Helper to set JAVA_HOME environment variable

$ErrorActionPreference = "Stop"

function Pause-Script {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

try {
    Write-Host "=== JAVA_HOME Setup Tool ===" -ForegroundColor Cyan
    
    # 1. Discovery Phase
    Write-Host "Scanning for JDK installations..." -ForegroundColor Yellow
    $candidates = @()

    # A. Check Scoop Apps (Best bet)
    $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
    $scoopApps = "$scoopPath\apps"
    if (Test-Path $scoopApps) {
        $dirs = Get-ChildItem -Path $scoopApps -Directory | Where-Object { 
            # Filter for common java names
            $_.Name -match "jdk" -or $_.Name -match "java" -or $_.Name -match "temurin" -or $_.Name -match "openjdk"
        }
        foreach ($d in $dirs) {
            # Check for 'current' folder or version folders
            $currentLink = "$($d.FullName)\current"
            if (Test-Path $currentLink) {
                # Verify it looks like a JDK (has bin/java.exe)
                if (Test-Path "$currentLink\bin\java.exe") {
                    $candidates += [PSCustomObject]@{
                        Name = "Scoop: $($d.Name) (Current)"
                        Path = $currentLink
                    }
                }
            }
        }
    }

    # B. Check Program Files (Standard)
    $progFilesJava = "C:\Program Files\Java"
    if (Test-Path $progFilesJava) {
        $dirs = Get-ChildItem -Path $progFilesJava -Directory
        foreach ($d in $dirs) {
            if (Test-Path "$($d.FullName)\bin\java.exe") {
                $candidates += [PSCustomObject]@{
                    Name = "System: $($d.Name)"
                    Path = $d.FullName
                }
            }
        }
    }

    # C. Check PATH (Fallback)
    if ($candidates.Count -eq 0) {
        $pathJavas = Get-Command java -All -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if ($pathJavas) {
            Write-Warning "Could not find standard JDK folders. Found 'java.exe' in PATH."
            foreach ($p in $pathJavas) {
                 Write-Host " - $p"
            }
        }
    }

    # 2. Selection Menu
    $finalPath = ""
    
    if ($candidates.Count -gt 0) {
        Write-Host "`nFound the following JDKs:" -ForegroundColor Green
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "$($i+1). $($candidates[$i].Name)" -ForegroundColor Cyan
            Write-Host "   Path: $($candidates[$i].Path)" -ForegroundColor Gray
        }
        Write-Host "$($candidates.Count+1). Enter Custom Path"
        
        $selection = Read-Host "`nSelect an option (1-$($candidates.Count+1))"
        if ($selection -match '^\d+$' -and [int]$selection -le $candidates.Count) {
            $finalPath = $candidates[[int]$selection - 1].Path
        }
    } else {
        Write-Host "No standard JDKs detected automatically."
    }

    if ([string]::IsNullOrWhiteSpace($finalPath)) {
        $finalPath = Read-Host "`nEnter path for JAVA_HOME (Root JDK folder)"
    }
    
    if ([string]::IsNullOrWhiteSpace($finalPath)) {
        Write-Host "No path entered. Exiting."
        exit 0
    }

    # Cleanup input (remove trailing slash)
    $finalPath = $finalPath.TrimEnd('\').TrimEnd('/')

    # Validate
    if (-not (Test-Path "$finalPath\bin\java.exe")) {
        Write-Warning "Warning: Could not find '\bin\java.exe' inside '$finalPath'."
        Write-Warning "This might not be a valid JDK root folder."
        $confirm = Read-Host "Set it anyway? (y/n)"
        if ($confirm -ne 'y') { exit 0 }
    }

    # 3. Set Variable
    Write-Host "Setting JAVA_HOME to '$finalPath'..." -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $finalPath, "User")
    
    # 4. Optional: Update PATH
    Write-Host "`nDo you also want to use this JDK for the 'java' command?" -ForegroundColor Yellow
    Write-Host "(This will add '$finalPath\bin' to the top of your PATH)" -ForegroundColor Gray
    $updatePath = Read-Host "Update PATH? (y/n)"
    
    if ($updatePath -eq 'y') {
        $binPath = "$finalPath\bin"
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        
        # Remove any existing references to this specific bin path to avoid dupes
        # Also could remove other java paths if we wanted to be aggressive, but let's just prepend
        $parts = $userPath -split ';' | Where-Object { $_ -ne $binPath }
        
        $newPath = "$binPath;" + ($parts -join ';')
        
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = $newPath + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        Write-Host "PATH updated successfully." -ForegroundColor Green
    }
    
    # 5. Refresh & Verify
    $env:JAVA_HOME = $finalPath
    Write-Host "`nSuccess! Setup complete." -ForegroundColor Green
    Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Gray
    if ($updatePath -eq 'y') {
         $ver = cmd /c "java -version 2>&1" | Select-Object -First 1
         Write-Host "Java Command: $ver" -ForegroundColor Gray
    }
    Write-Host "Note: You may need to restart your terminal/IDE for changes to persist fully." -ForegroundColor Yellow

} catch {
    Write-Error "An unexpected error occurred: $_"
}

Pause-Script
