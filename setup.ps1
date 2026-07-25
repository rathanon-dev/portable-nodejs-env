# ========================================================
# Ultimate Portable Dev Environment (Smart CLI Mode)
# PowerShell 5.0+ Compatible
# ========================================================
[CmdletBinding()]
param (
    [Alias("install")]
    [string]$i = "",

    [string]$url = "",

    [Alias("help")]
    [switch]$h ,

    [Alias("Environment")]
    [switch]$env
)

# Force TLS 1.2 protocol for web requests (Required for PS 5.0)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Fallback for $PSScriptRoot when executed via ScriptBlock in PS 5.0
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# 1. Cleanup Background Processes
Write-Host "Cleaning up background processes..." -ForegroundColor DarkGray
Stop-Process -Name "node", "7za" -Force -ErrorAction SilentlyContinue

# 2. Define Variables & Create Folders
$root         = $PSScriptRoot
$toolsDir     = "$root\tools"
$workspaceDir = "$root\workspace"
$tempDir      = "$root\temp_download"
$7zDir        = "$toolsDir\7zip"
$7zExe        = "$7zDir\7za.exe"
$gitDir       = "$toolsDir\git"
$nodeDir      = "$toolsDir\node"

$folders = @($toolsDir, $workspaceDir, $tempDir, $7zDir, $gitDir, $nodeDir)
foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
}

# ========================================================
# Core Functions
# ========================================================

function Show-Help {
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host " Portable Dev Environment - CLI Tool" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Usage: .\setup.ps1 [Options]`n" -ForegroundColor Yellow
    Write-Host "Options:"
    Write-Host "  -h, -help             Show this help message"
    Write-Host "  -i, -install <tool>   Install specific tools ('git', 'node', 'all')"
    Write-Host "  -url <link>           Clone a GitHub repository and run it"
    Write-Host "`nExamples:"
    Write-Host "  .\setup.ps1                      (Smart Default: Auto-run or choose project)"
    Write-Host "  .\setup.ps1 -env                 (Dev Environment Mode)"
    Write-Host "  .\setup.ps1 -i node              (Install only Node.js)"
    Write-Host "  .\setup.ps1 -i all               (Install Git and Node.js)"
    Write-Host "  .\setup.ps1 -url https://...     (Clone repository and run)"
    Write-Host "==========================================`n" -ForegroundColor Cyan
}

function Expand-With7z([string]$ArchiveFilePath, [string]$DestinationPath) {
    & $7zExe x $ArchiveFilePath -y "-o$DestinationPath" | Out-Null
}

function Install-7Zip {
    if (-not (Test-Path $7zExe)) {
        Write-Host "[INFO] Checking for the latest 7-Zip version on NuGet..." -ForegroundColor Cyan
        
        try {
            $nugetUrl = "https://azuresearch-usnc.nuget.org/query?q=packageid:7-Zip.CommandLine&prerelease=false"
            $packageInfo = Invoke-RestMethod -Uri $nugetUrl -ErrorAction Stop
            
            $latestVersion = $packageInfo.data[0].version
            
            if ([string]::IsNullOrEmpty($latestVersion)) {
                throw "Could not retrieve version from NuGet API response."
            }
            
            Write-Host "[+] Found latest version: $latestVersion" -ForegroundColor Green
            Write-Host "Downloading 7-Zip v$latestVersion..." -ForegroundColor Yellow
            
            $tempZip = "$tempDir\7z_temp.zip"
            $tempExtract = "$tempDir\7z_temp_extract"
            
            $downloadUrl = "https://www.nuget.org/api/v2/package/7-Zip.CommandLine/$latestVersion"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -ErrorAction Stop
            
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
            Move-Item -Path "$tempExtract\tools\7za.exe" -Destination $7zExe -Force
            
            Remove-Item -Path $tempZip, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
            
            Write-Host "[OK] 7-Zip v$latestVersion Ready." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to fetch or download the latest 7-Zip from NuGet." -ForegroundColor Red
            Write-Host "Details: $_" -ForegroundColor DarkGray
        }
    }
}

function Install-Git {
    if (-not (Test-Path "$gitDir\cmd\git.exe")) {
        Write-Host "Downloading Portable Git..." -ForegroundColor Yellow
        $gitData = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $gitAsset = $gitData.assets | Where-Object { $_.name -match "PortableGit-.*-64-bit\.7z\.exe" } | Select-Object -First 1
        $tempGit = "$tempDir\$($gitAsset.name)"
        Invoke-WebRequest -Uri $gitAsset.browser_download_url -OutFile $tempGit -ErrorAction Stop
        Expand-With7z -ArchiveFilePath $tempGit -DestinationPath $gitDir
        Write-Host "[OK] Git Ready." -ForegroundColor Green
    } else { Write-Host "[OK] Git is ready." -ForegroundColor Green }
}

function Install-Node {
    if (-not (Test-Path "$nodeDir\node.exe")) {
        Write-Host "Downloading Node.js..." -ForegroundColor Yellow
        $index = Invoke-RestMethod "https://nodejs.org/dist/index.json"
        $version = ($index | Where-Object { $_.lts -ne $false } | Select-Object -First 1).version
        $tempNode = "$tempDir\node-$version.zip"
        $tempExtractDir = "$tempDir\temp_node_extract"

        Invoke-WebRequest -Uri "https://nodejs.org/dist/$version/node-$version-win-x64.zip" -OutFile $tempNode -ErrorAction Stop
        if (Test-Path $tempExtractDir) { Remove-Item -Path $tempExtractDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        Expand-With7z -ArchiveFilePath $tempNode -DestinationPath $tempExtractDir
        
        $extractedFolder = Get-ChildItem -Path $tempExtractDir -Directory | Select-Object -First 1
        if ($null -ne $extractedFolder -and -not [string]::IsNullOrWhiteSpace($extractedFolder.FullName)) {
            $sourcePath = Join-Path -Path $extractedFolder.FullName -ChildPath "*"
            Move-Item -Path $sourcePath -Destination $nodeDir -Force
        } else {
            Write-Host "[ERROR] CRITICAL: Could not find extracted Node.js folder." -ForegroundColor Red; Exit
        }
        Write-Host "[OK] Node.js Ready." -ForegroundColor Green
    } else { Write-Host "[OK] Node.js is ready." -ForegroundColor Green }
}

function Clear-Temp {
    if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Show-EnvironmentStatus {
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host " Environment: Portable Tools Loaded" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " [Node.js] : $nodeDir" -ForegroundColor DarkGray
    Write-Host " [Git]     : $gitDir" -ForegroundColor DarkGray
    Write-Host " [7-Zip]   : $7zDir" -ForegroundColor DarkGray
    Write-Host "==========================================`n" -ForegroundColor Cyan
}

# ========================================================
# Logic Router (Handling Arguments)
# ========================================================

# [Option 1] Help Mode (-h)
if ($h) {
    Show-Help
    Exit
}

# [Option 2] Install Mode (-i)
if ($i) {
    $tool = $i.ToLower()
    if ($tool -notin @('git', 'node', 'all')) {
        Write-Host "[ERROR] Invalid tool: '$i'. Please use 'git', 'node', or 'all'." -ForegroundColor Red
        Exit
    }
    
    Write-Host "Starting installation for: $tool" -ForegroundColor Cyan
    Install-7Zip
    if ($tool -eq 'git' -or $tool -eq 'all') { Install-Git }
    if ($tool -eq 'node' -or $tool -eq 'all') { Install-Node }
    Clear-Temp
    
    Write-Host "`n[SUCCESS] Installation Complete!" -ForegroundColor Green
    Exit
}

# ========================================================
# Phase 4: Workspace Execution (URL or Smart Default)
# ========================================================
Install-7Zip
Install-Git
Install-Node
Clear-Temp

Show-EnvironmentStatus
# Inject PATH variables
$env:PATH = "$nodeDir;$gitDir\cmd;$7zDir;$env:PATH"

$targetDir = $null

if ($env) {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[ON] Dev Environment MODE" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "node -v : " -NoNewline -ForegroundColor Gray; node -v
    Write-Host "git -v  : " -NoNewline -ForegroundColor Gray; git --version
    
    Write-Host "7za -h  : " -NoNewline -ForegroundColor Gray
    (7za -h) | Select-Object -First 2
    Set-Location $root
    Write-Host "`nReturned to root directory: $root" -ForegroundColor DarkGray
    Exit
}

# [Option 3] URL Mode (-url)
if ($url) {
    if ($url -match '.*/([^/]+?)(?:\.git)?$') {
        $targetDir = "$workspaceDir\$($Matches[1])"
        if (-not (Test-Path $targetDir)) {
            Set-Location $workspaceDir
            Write-Host "Cloning project..." -ForegroundColor Yellow
            git clone $url
            if (-not $?) { Write-Host "[ERROR] Git clone failed!"; Exit }
        }
    } else {
        Write-Host "[ERROR] Invalid URL format." -ForegroundColor Red; Exit
    }
} 
# [Option 4] SMART DEFAULT MODE (No Arguments & Interactive Menu)
else {
    $localProjects = @(Get-ChildItem $workspaceDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "package.json") })
    
    if ($localProjects.Count -eq 0) {
        Write-Host "[INFO] No project found in 'workspace' folder." -ForegroundColor Yellow
        Show-Help
        Exit
    } 
    elseif ($localProjects.Count -eq 1) {
        $targetDir = $localProjects[0].FullName
        Write-Host "[+] Smart Default: Auto-running project [$($localProjects[0].Name)]" -ForegroundColor Green
    } 
    else {
        Write-Host "`n[+] Multiple projects found in Workspace. Please select one to run:" -ForegroundColor Cyan
        for ($idx = 0; $idx -lt $localProjects.Count; $idx++) {
            Write-Host "  [$($idx + 1)] $($localProjects[$idx].Name)" -ForegroundColor Green
        }
        Write-Host "  [0] Exit`n" -ForegroundColor Yellow
        
        $choice = Read-Host "> Enter project number"
        
        if ($choice -match '^\d+$') {
            $num = [int]$choice
            if ($num -eq 0) {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Exit
            } elseif ($num -gt 0 -and $num -le $localProjects.Count) {
                $targetDir = $localProjects[$num - 1].FullName
                Write-Host "`n[OK] Selected: $($localProjects[$num - 1].Name)" -ForegroundColor Cyan
            } else {
                Write-Host "[ERROR] Invalid selection." -ForegroundColor Red
                Exit
            }
        } else {
            Write-Host "[ERROR] Please enter a valid number." -ForegroundColor Red
            Exit
        }
    }
}

# --- Run the Project ---
Set-Location $targetDir

if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] 'package.json' not found. This project might not run." -ForegroundColor Red
    Exit
}

# 1. Run npm install
Write-Host "`nRunning npm install..." -ForegroundColor Yellow
npm install

# 2. Try/Finally block to ensure returning to root directory upon Ctrl+C
try {
    Write-Host "`nStarting Development Server (npm run dev)..." -ForegroundColor Green
    Write-Host "[NOTE] Press Ctrl + C to stop the server" -ForegroundColor DarkGray
    npm run dev
}
finally {
    Write-Host "`nReturning to root directory..." -ForegroundColor Cyan
    Write-Host "Back to root directory: $root" -ForegroundColor Green
    Set-Location $root
}