# ========================================================
# Portable Node.js Dev Environment - Ultimate Smart CLI
# Multi-Engine Downloader & Auto Workspace Management
# ========================================================
[CmdletBinding()]
param (
    [Alias("install", "i")][string]$InstallTool = "",
    [Alias("version", "v")][string]$TargetVersion = "",
    [Alias("list", "l")][string]$ListTool = "",
    [Alias("u")][string]$Url = "",
    [Alias("run", "r")][switch]$RunMode,
    [Alias("env", "e")][switch]$EnvMode,
    [Alias("force", "f")][switch]$ForceReinstall,
    [Alias("yes", "y")][switch]$AutoYes,
    [Alias("help", "h")][switch]$ShowHelp,

    # Catch remaining arguments for commands like `-r my-app`
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Stop-Process -Name "7za", "aria2c", "node", "git" -Force -ErrorAction SilentlyContinue

# ========================================================
# 1. Workspace & Variables Setup
# ========================================================
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$toolsDir     = "$root\tools"
$workspaceDir = "$root\workspace"
$tempDir      = "$root\temp_download"
$7zDir        = "$toolsDir\7zip"
$7zExe        = "$7zDir\7za.exe"
$aria2Dir     = "$toolsDir\aria2"
$aria2Exe     = "$aria2Dir\aria2c.exe"
$gitDir       = "$toolsDir\git"
$nodeDir      = "$toolsDir\node"

$folders = @($toolsDir, $workspaceDir, $tempDir, $7zDir, $aria2Dir, $gitDir, $nodeDir)
foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
}

# ========================================================
# 2. Core Functions
# ========================================================
function Show-Help {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "   Portable Node.js Dev Environment - Smart CLI Tool" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "Usage: .\setup.ps1 [Options]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, -help             Show this help message"
    Write-Host "  -l, -list <tool>      List available versions ('node')"
    Write-Host "  -i, -install <tool>   Install tools ('node', 'all') (Auto-loads 7z/Aria2/Git)"
    Write-Host "  -v, -version <ver>    Specify Node.js version branch (e.g. '18', '20')"
    Write-Host "  -u, -url <link>       Clone a GitHub repository into workspace (Download Only)"
    Write-Host "  -e, -env              Enter Dev Shell Mode (cd to workspace & inject Paths)"
    Write-Host "  -r, -run [folder]     Auto-Detect & Run project (npm install -> npm run dev)"
    Write-Host "  -y, -yes              Auto-confirm prompts (Silent mode)"
    Write-Host "  -f, -force            Force re-installation of tools"
    Write-Host "==========================================================" -ForegroundColor Cyan
}

function Expand-With7z([string]$ArchiveFilePath, [string]$DestinationPath) {
    if (Test-Path $7zExe) { & $7zExe x $ArchiveFilePath -y "-o$DestinationPath" | Out-Null } 
    else { Expand-Archive -Path $ArchiveFilePath -DestinationPath $DestinationPath -Force }
}

function Get-FileWithSmartEngine([string]$DownloadUrl, [string]$OutFilePath) {
    $outDir = Split-Path $OutFilePath -Parent
    $outFile = Split-Path $OutFilePath -Leaf

    # Prevent Aria2 from getting blocked by nodejs.org (Use 1 connection for Node)
    $isNodeUrl = $DownloadUrl -match "nodejs.org"
    $maxConn = if ($isNodeUrl) { 1 } else { 16 }

    if (Test-Path $aria2Exe) {
        try {
            Write-Host "   [INFO] Using Aria2 Downloader (Connections: $maxConn)..." -ForegroundColor DarkGray
            & $aria2Exe --console-log-level=warn --summary-interval=0 -x $maxConn -s $maxConn -j $maxConn -k 1M -d $outDir -o $outFile $DownloadUrl
            if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFilePath)) { return }
        } catch {}
    } else {
        Write-Host "   [WARN] Aria2 not found. Cascading to cURL or WebRequest..." -ForegroundColor Yellow
    }

    $curlPath = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curlPath) {
        try {
            Write-Host "   [INFO] Using Native cURL..." -ForegroundColor DarkGray
            & $curlPath.Source -L -# -f $DownloadUrl -o $OutFilePath
            if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFilePath)) { return }
        } catch {}
    }

    Write-Host "   [WARN] Using PowerShell WebRequest (Fallback)..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutFilePath -UseBasicParsing -ErrorAction Stop
}

# ========================================================
# 3. Bootstrappers (Auto-Installers)
# ========================================================
function Install-7Zip {
    if (-not $ForceReinstall -and (Test-Path $7zExe)) { return }
    Write-Host "[PROCESS] Bootstrap: 7-Zip Core Engine..." -ForegroundColor Yellow
    try {
        $nugetUrl = "https://azuresearch-usnc.nuget.org/query?q=packageid:7-Zip.CommandLine&prerelease=false"
        $latest = (Invoke-RestMethod -Uri $nugetUrl -UserAgent "Mozilla").data[0].version
        $tempZip = "$tempDir\7z_temp.zip"
        $tempExtract = "$tempDir\7z_temp_extract"
        
        # Always safe to use Get-FileWithSmartEngine (it will fallback to cURL/WebRequest)
        Get-FileWithSmartEngine -DownloadUrl "https://www.nuget.org/api/v2/package/7-Zip.CommandLine/$latest" -OutFilePath $tempZip
        
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        Move-Item -Path "$tempExtract\tools\7za.exe" -Destination $7zExe -Force
        Remove-Item -Path $tempZip, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch { Write-Host "[ERROR] Failed 7-Zip Bootstrap" -ForegroundColor Red; Exit }
}

function Install-Aria2 {
    if (-not $ForceReinstall -and (Test-Path $aria2Exe)) { return }
    Write-Host "[PROCESS] Bootstrap: Aria2 Downloader..." -ForegroundColor Yellow
    try {
        $releaseData = Invoke-RestMethod "https://api.github.com/repos/aria2/aria2/releases/latest" -UserAgent "Mozilla"
        $asset = $releaseData.assets | Where-Object { $_.name -match "win-64bit.*\.zip$" } | Select-Object -First 1
        $tempZip = "$tempDir\$($asset.name)"
        $tempExtract = "$tempDir\aria2_temp_extract"
        
        Get-FileWithSmartEngine -DownloadUrl $asset.browser_download_url -OutFilePath $tempZip
        Expand-With7z -ArchiveFilePath $tempZip -DestinationPath $tempExtract
        Move-Item -Path (Get-ChildItem $tempExtract -Filter "aria2c.exe" -Recurse).FullName -Destination $aria2Exe -Force
        Remove-Item -Path $tempZip, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch { Write-Host "[WARN] Aria2 Bootstrap failed. Using basic downloaders." -ForegroundColor Yellow }
}

function Install-Git {
    $gitBin = if (Test-Path "$gitDir\cmd\git.exe") { "$gitDir\cmd\git.exe" } else { "$gitDir\bin\git.exe" }
    if (-not $ForceReinstall -and (Test-Path $gitBin)) { return }
    Write-Host "[PROCESS] Bootstrap: Git Portable..." -ForegroundColor Yellow
    try {
        $gitAsset = (Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest" -UserAgent "Mozilla").assets | Where-Object { $_.name -match "PortableGit-.*-64-bit\.7z\.exe" } | Select-Object -First 1
        $tempGit = "$tempDir\$($gitAsset.name)"
        
        Get-FileWithSmartEngine -DownloadUrl $gitAsset.browser_download_url -OutFilePath $tempGit
        if (Test-Path $gitDir) { Remove-Item "$gitDir\*" -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-With7z -ArchiveFilePath $tempGit -DestinationPath $gitDir
        Remove-Item $tempGit -Force -ErrorAction SilentlyContinue
    } catch { Write-Host "[ERROR] Git Installation Failed" -ForegroundColor Red; Exit }
}

# Helper to run ALL Core Tools
function Ensure-CoreTools {
    Install-7Zip
    Install-Aria2
    Install-Git
}

function Install-Node([string]$ReqVer) {
    if (-not $ForceReinstall -and (Test-Path "$nodeDir\node.exe")) {
        $currVer = & "$nodeDir\node.exe" -v 2>$null
        if ([string]::IsNullOrWhiteSpace($ReqVer) -or $currVer -like "v$ReqVer*") { return }
    }
    Write-Host "[PROCESS] Installing Node.js..." -ForegroundColor Yellow
    try {
        $index = Invoke-RestMethod "https://nodejs.org/dist/index.json" -UserAgent "Mozilla"
        $selectedVer = if ($ReqVer) { ($index | Where-Object { $_.version -like "v$ReqVer*" } | Select-Object -First 1).version } 
                       else { ($index | Where-Object { $_.lts -ne $false } | Select-Object -First 1).version }
        
        if (-not $selectedVer) { Write-Host "[ERROR] Version not found." -ForegroundColor Red; Exit }
        
        $tempNode = "$tempDir\node-$selectedVer.zip"
        $tempExtractDir = "$tempDir\temp_node_extract"
        
        Get-FileWithSmartEngine -DownloadUrl "https://nodejs.org/dist/$selectedVer/node-$selectedVer-win-x64.zip" -OutFilePath $tempNode
        
        if (Test-Path $tempExtractDir) { Remove-Item $tempExtractDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        Expand-With7z -ArchiveFilePath $tempNode -DestinationPath $tempExtractDir
        
        Get-ChildItem $nodeDir -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Move-Item "$((Get-ChildItem $tempExtractDir -Directory)[0].FullName)\*" $nodeDir -Force
        Remove-Item $tempNode, $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch { Write-Host "[ERROR] Node Installation Failed" -ForegroundColor Red; Exit }
}

function Update-SessionPath {
    $resolvedGit = if (Test-Path "$gitDir\cmd\git.exe") { "$gitDir\cmd" } else { "$gitDir\bin" }
    $env:PATH = "$nodeDir;$resolvedGit;$7zDir;$aria2Dir;$env:PATH"
}

function Enter-LiveDevShell {
    Update-SessionPath
    Set-Location $workspaceDir
    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host " [ON] Dev Environment ACTIVE SHELL MODE" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " Workspace : $workspaceDir" -ForegroundColor DarkGray
    if (Get-Command "node" -ErrorAction Ignore) { Write-Host " node      : $(node -v) (npm $(npm -v))" -ForegroundColor Gray }
    if (Get-Command "git" -ErrorAction Ignore) { Write-Host " git       : $((git --version) -replace 'git version ','')" -ForegroundColor Gray }
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "[INFO] You are inside the isolated portable shell.`n" -ForegroundColor Yellow
}

# ========================================================
# 4. Main Logic Router
# ========================================================

if ($PSBoundParameters.Count -eq 0 -or $ShowHelp) { Show-Help; Exit }

# [Mode] List (-l)
if ($ListTool -eq 'node') {
    $index = Invoke-RestMethod "https://nodejs.org/dist/index.json" -UserAgent "Mozilla"
    $index | Where-Object { $_.lts -ne $false } | Group-Object { ([version]($_.version -replace '^v','')).Major } | 
    Sort-Object { [int]$_.Name } -Descending | ForEach-Object {
        $lt = $_.Group[0]; Write-Host "Node.js v$($_.Name) `t Latest: $($lt.version) `t LTS: $($lt.lts)" -ForegroundColor Green
    }
    Exit
}

# [Mode] Install (-i)
if ($InstallTool) {
    if ($InstallTool -notin @('node', 'all', 'git')) { Write-Host "[ERROR] Invalid tool." -ForegroundColor Red; Exit }
    
    Ensure-CoreTools # Automatically installs 7z -> Aria2 -> Git
    
    if ($InstallTool -in @('node', 'all')) { Install-Node -ReqVer $TargetVersion }
    
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "`n[SUCCESS] Installation Completed!" -ForegroundColor Green
    Exit
}

# [Mode] URL Clone (-url)
if ($Url) {
    if ($Url -match '.*/([^/]+?)(?:\.git)?$') {
        $targetName = $Matches[1]
        Ensure-CoreTools
        Update-SessionPath; Set-Location $workspaceDir
        if (-not (Test-Path $targetName)) {
            Write-Host "`n[PROCESS] Cloning repository $targetName..." -ForegroundColor Yellow
            git clone $Url
            Write-Host "[SUCCESS] Repository cloned into workspace\$targetName" -ForegroundColor Green
        } else { Write-Host "[SKIP] Folder '$targetName' already exists in workspace." -ForegroundColor DarkGray }
    } else { Write-Host "[ERROR] Invalid URL." -ForegroundColor Red }
    Exit
}

# [Mode] Run / Execute (-r)
if ($RunMode) {
    Ensure-CoreTools; Install-Node
    Update-SessionPath
    $targetFolder = $null

    if ($RemainingArgs.Count -gt 0) {
        $targetFolder = Join-Path $workspaceDir $RemainingArgs[0]
        if (-not (Test-Path $targetFolder)) { Write-Host "`n[ERROR] Project folder not found: $($RemainingArgs[0])" -ForegroundColor Red; $EnvMode = $true }
        elseif (-not (Test-Path "$targetFolder\package.json")) { Write-Host "`n[ERROR] package.json missing in $($RemainingArgs[0])" -ForegroundColor Red; $EnvMode = $true }
    } else {
        $validProjects = Get-ChildItem $workspaceDir -Directory | Where-Object { Test-Path "$($_.FullName)\package.json" }
        if ($validProjects.Count -eq 0) { Write-Host "`n[ERROR] No Node.js projects (with package.json) found in workspace!" -ForegroundColor Red; $EnvMode = $true }
        elseif ($validProjects.Count -eq 1) { $targetFolder = $validProjects[0].FullName; Write-Host "`n[INFO] Auto-selected: $($validProjects[0].Name)" -ForegroundColor Cyan }
        else {
            Write-Host "`n[+] Multiple Node.js projects found. Please select one:" -ForegroundColor Cyan
            for ($i=0; $i -lt $validProjects.Count; $i++) { Write-Host "  [$($i+1)] $($validProjects[$i].Name)" -ForegroundColor Green }
            Write-Host "  [0] Exit to Shell`n" -ForegroundColor Yellow
            $choice = Read-Host "> Enter project number"
            if ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $validProjects.Count) { $targetFolder = $validProjects[[int]$choice - 1].FullName }
            else { $EnvMode = $true }
        }
    }

    if (-not $EnvMode -and $targetFolder) {
        Set-Location $targetFolder
        Write-Host "`n[PROCESS] Running npm install..." -ForegroundColor Yellow
        npm install
        Write-Host "`n[PROCESS] Starting Development Server (npm run dev)..." -ForegroundColor Green
        Write-Host "[NOTE] Press Ctrl + C to stop the server" -ForegroundColor DarkGray
        try { npm run dev } finally { $EnvMode = $true }
    }
}

# [Mode] Environment Shell (-e)
if ($EnvMode) {
    # FIX: Separated Test-Path conditions to avoid PowerShell parsing errors
    $isGitMissing = (-not (Test-Path "$gitDir\cmd\git.exe") -and -not (Test-Path "$gitDir\bin\git.exe"))
    $isNodeMissing = -not (Test-Path "$nodeDir\node.exe")

    if ($isNodeMissing -or $isGitMissing) {
        Write-Host "`n[WARN] Core toolchains (Node/Git) are missing in 'tools' directory!" -ForegroundColor Yellow
        if ($AutoYes) {
            Ensure-CoreTools; Install-Node
        } else {
            $ans = Read-Host "Would you like to auto-install missing tools now? [Y/n]"
            if ($ans -notmatch "^n") { Ensure-CoreTools; Install-Node }
        }
    }
    Enter-LiveDevShell
}