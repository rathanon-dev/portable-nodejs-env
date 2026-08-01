# ========================================================
# SETUP v20: Unified Node.js Dev Suite (Modernized)
# Combined: Node.js, Git, TCP Proxy & Auto-Cleanup
# Strict Compatibility: Windows PowerShell 5.1 (Win 10 / 11)
# ========================================================
[CmdletBinding()]
param (
    [bool]$EnableProxy = $true,
    [string]$ProxyServerUrl = "http://192.168.1.10:8080",
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

# Enforce TLS 1.2 for all web requests (PS 5.1 Standard)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Stop-Process -Name "7za", "aria2c", "node", "git" -Force -ErrorAction SilentlyContinue

# ========================================================
# 1. Workspace & Variables Setup
# ========================================================
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$toolsDir     = "$root\tools"
$workspaceDir = "$root\workspace"
$mainTempDir  = "$root\temp"
$7zDir        = "$toolsDir\7zip"
$7zExe        = "$7zDir\7za.exe"
$aria2Dir     = "$toolsDir\aria2"
$aria2Exe     = "$aria2Dir\aria2c.exe"
$gitDir       = "$toolsDir\git"
$nodeDir      = "$toolsDir\node"

$folders = @($toolsDir, $workspaceDir, $7zDir, $aria2Dir, $gitDir, $nodeDir)
foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
}

# ========================================================
# 2. Smart Proxy & Network Engine
# ========================================================
$script:IsProxyOnline = $null

function Test-ProxyHealth {
    [CmdletBinding()]
    param ()
    if (-not $EnableProxy) { return $false }
    if ($null -ne $script:IsProxyOnline) { return $script:IsProxyOnline }

    try {
        $uri = [System.Uri]$ProxyServerUrl
        $tcp = New-Object Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($uri.Host, $uri.Port, $null, $null)
        $success = $async.AsyncWaitHandle.WaitOne(1500, $true)
        
        if ($success -and $tcp.Connected) {
            $tcp.EndConnect($async)
            $script:IsProxyOnline = $true
            Write-Host " [PROXY] Local CDN Gateway Connected ($ProxyServerUrl)" -ForegroundColor Green
        }
        else {
            $script:IsProxyOnline = $false
            Write-Host " [PROXY WARN] Gateway Timeout! Auto-switching to Direct Internet Mode." -ForegroundColor Yellow
        }
        $tcp.Close()
    }
    catch {
        $script:IsProxyOnline = $false
        Write-Host " [PROXY WARN] Gateway Unreachable! Auto-switching to Direct Internet Mode." -ForegroundColor Yellow
    }
    return $script:IsProxyOnline
}

function Get-ProxifiedUrl {
    [CmdletBinding()]
    param ([string]$OriginalUrl)
    
    if ([string]::IsNullOrWhiteSpace($OriginalUrl)) { return $OriginalUrl }
    
    $cleanProxy = $ProxyServerUrl.TrimEnd('/')
    if ($OriginalUrl.StartsWith($cleanProxy)) { return $OriginalUrl }
    
    if (Test-ProxyHealth) {
        return "$cleanProxy/$OriginalUrl"
    }
    return $OriginalUrl
}

# --------------------------------------------------------
# 2.5 I/O Seam Wrappers (Step 2)
# --------------------------------------------------------

function Invoke-SetupRestMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [hashtable]$Headers = @{},
        [string]$UserAgent = "Mozilla/5.0"
    )
    return Invoke-RestMethod -Uri $Uri -Headers $Headers -UserAgent $UserAgent -UseBasicParsing -ErrorAction Stop
}

function Invoke-SetupWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [string]$OutFile = "",
        [string]$UserAgent = "Mozilla/5.0"
    )
    if ($OutFile) {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UserAgent $UserAgent -UseBasicParsing -ErrorAction Stop
    } else {
        return Invoke-WebRequest -Uri $Uri -UserAgent $UserAgent -UseBasicParsing -ErrorAction Stop
    }
}

function Invoke-SetupCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CommandPath,
        [string[]]$ArgumentList = @(),
        [switch]$NoOutput,
        [switch]$RedirectError,
        [switch]$AsString,
        [switch]$Parse7ZipProgress
    )
    
    if ($Parse7ZipProgress) {
        $lastPercent = -1
        & $CommandPath @ArgumentList | ForEach-Object {
            if ($_ -match '(\d+)%') {
                $percent = [int]$Matches[1]
                if ($percent -ne $lastPercent -and $percent -le 100) {
                    Write-Host -NoNewline "`r  -> Processing... $percent% Complete  "
                    $lastPercent = $percent
                }
            }
        }
        Write-Host -NoNewline "`r  -> Processing... 100% Complete  `n"
        return
    }
    
    if ($RedirectError -and $AsString) {
        $result = & $CommandPath @ArgumentList 2>&1 | Out-String
        return $result
    } elseif ($AsString) {
        $result = & $CommandPath @ArgumentList | Out-String
        return $result
    } elseif ($NoOutput) {
        & $CommandPath @ArgumentList 2>&1 | Out-Null
    } elseif ($RedirectError) {
        & $CommandPath @ArgumentList 2>&1
    } else {
        & $CommandPath @ArgumentList
    }
}

function Write-SetupStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("OK", "WARN", "ERROR", "INFO", "RAW")]
        [string]$Type = "RAW",
        [System.ConsoleColor]$Color = [System.ConsoleColor]::White,
        [switch]$NoNewLine
    )
    
    $prefix = ""
    $fgColor = $Color
    
    if ($Type -eq "OK") { $prefix = " [OK] "; $fgColor = "Green" }
    if ($Type -eq "WARN") { $prefix = " [WARN] "; $fgColor = "Yellow" }
    if ($Type -eq "ERROR") { $prefix = " [ERROR] "; $fgColor = "Red" }
    if ($Type -eq "INFO") { $prefix = " [INFO] "; $fgColor = "DarkGray" }
    
    $outMsg = "$prefix$Message"
    if ($Type -eq "RAW") { $outMsg = $Message }
    
    if ($NoNewLine) {
        Write-Host $outMsg -ForegroundColor $fgColor -NoNewline
    } else {
        Write-Host $outMsg -ForegroundColor $fgColor
    }
}

function Invoke-FallbackDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$DownloadUrl, 
        [Parameter(Mandatory=$true)][string]$OutFilePath,
        [int]$Aria2Connections = 16
    )
    
    $effectiveUrl = Get-ProxifiedUrl -OriginalUrl $DownloadUrl

    $targetDir = Split-Path $OutFilePath -Parent
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

    if (Test-Path $aria2Exe) {
        try {
            Write-SetupStatus -Message "  [DL Engine] Attempting download via Aria2 (Connections: $Aria2Connections)..." -Type INFO
            $targetDir = Split-Path $OutFilePath -Parent
            $targetFile = Split-Path $OutFilePath -Leaf
            Invoke-SetupCommand -CommandPath $aria2Exe -ArgumentList @($effectiveUrl, "-o", $targetFile, "-d", $targetDir, "-x", "$Aria2Connections", "-s", "$Aria2Connections", "--console-log-level=warn", "--summary-interval=0")
            if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFilePath)) { return }
        }
        catch {}
    }
    
    $curlCmd = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curlCmd) {
        try {
            Write-SetupStatus -Message "  [DL Engine] Attempting download via cURL..." -Type INFO
            Invoke-SetupCommand -CommandPath $curlCmd.Source -ArgumentList @("-L", "-f", "-A", "Mozilla/5.0", "-s", $effectiveUrl, "-o", $OutFilePath)
            if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFilePath)) { return }
        }
        catch {}
    }
    
    try {
        Write-SetupStatus -Message "  [DL Engine] Attempting download via PowerShell Native..." -Type INFO
        Invoke-SetupWebRequest -Uri $effectiveUrl -OutFile $OutFilePath -UserAgent "Mozilla/5.0"
        if (Test-Path $OutFilePath) { return }
    }
    catch {}
    
    Write-SetupStatus -Message "[CRITICAL ERROR] Download failed across ALL engines for URL: $DownloadUrl" -Type ERROR
    exit 1
}

# ========================================================
# 3. Bootstrappers (Auto-Installers)
# ========================================================

function Install-7Zip {
    if (-not $ForceReinstall -and (Test-Path $7zExe)) { return }
    Write-SetupStatus -Message "[BOOTSTRAP] Setting up 7-Zip Core Engine..." -Type WARN
    try {
        $nugetUrl = Get-ProxifiedUrl -OriginalUrl "https://azuresearch-usnc.nuget.org/query?q=packageid:7-Zip.CommandLine&prerelease=false"
        $latest = (Invoke-SetupRestMethod -Uri $nugetUrl).data[0].version
        $tempZip = Join-Path $mainTempDir "7z_temp.zip"
        $tempExtract = Join-Path $mainTempDir "7z_temp_extract"
        
        Invoke-FallbackDownload -DownloadUrl "https://www.nuget.org/api/v2/package/7-Zip.CommandLine/$latest" -OutFilePath $tempZip
        
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        Move-Item -Path "$tempExtract\tools\7za.exe" -Destination $7zExe -Force
        Remove-Item -Path $tempZip, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-SetupStatus -Message "[OK] 7-Zip Engine Deployed." -Type OK
    } catch { Write-SetupStatus -Message "[ERROR] Failed 7-Zip Bootstrap" -Type ERROR; Exit }
}

function Install-Aria2 {
    if (-not $ForceReinstall -and (Test-Path $aria2Exe)) { return }
    Write-SetupStatus -Message "[BOOTSTRAP] Setting up Aria2 Downloader..." -Type WARN
    try {
        $apiUrl = Get-ProxifiedUrl -OriginalUrl "https://api.github.com/repos/aria2/aria2/releases/latest"
        $releaseData = Invoke-SetupRestMethod -Uri $apiUrl
        $asset = $releaseData.assets | Where-Object { $_.name -match "win-64bit.*\.zip$" } | Select-Object -First 1
        $tempZip = Join-Path $mainTempDir "$($asset.name)"
        $tempExtract = Join-Path $mainTempDir "aria2_temp_extract"
        
        Invoke-FallbackDownload -DownloadUrl $asset.browser_download_url -OutFilePath $tempZip
        if (Test-Path $7zExe) { 
            Invoke-SetupCommand -CommandPath $7zExe -ArgumentList @("x", $tempZip, "-y", "-o$tempExtract", "-bsp1", "-bso0") -Parse7ZipProgress
        } else {
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        }
        
        Move-Item -Path (Get-ChildItem $tempExtract -Filter "aria2c.exe" -Recurse).FullName -Destination $aria2Exe -Force
        Remove-Item -Path $tempZip, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-SetupStatus -Message "[OK] Aria2 Engine Deployed." -Type OK
    } catch { Write-SetupStatus -Message "Aria2 Bootstrap failed. Using basic downloaders." -Type WARN }
}

function Install-Git {
    $gitBin = if (Test-Path "$gitDir\cmd\git.exe") { "$gitDir\cmd\git.exe" } else { "$gitDir\bin\git.exe" }
    if (-not $ForceReinstall -and (Test-Path $gitBin)) { return }
    Write-SetupStatus -Message "[BOOTSTRAP] Setting up Git Portable..." -Type WARN
    try {
        $gitApiUrl = Get-ProxifiedUrl -OriginalUrl "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $gitAsset = (Invoke-SetupRestMethod -Uri $gitApiUrl).assets | Where-Object { $_.name -match "PortableGit-.*-64-bit\.7z\.exe" } | Select-Object -First 1
        $tempGit = Join-Path $mainTempDir "$($gitAsset.name)"
        
        Invoke-FallbackDownload -DownloadUrl $gitAsset.browser_download_url -OutFilePath $tempGit
        if (Test-Path $gitDir) { Remove-Item "$gitDir\*" -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $7zExe) { 
            Invoke-SetupCommand -CommandPath $7zExe -ArgumentList @("x", $tempGit, "-y", "-o$gitDir", "-bsp1", "-bso0") -Parse7ZipProgress 
        }
        Remove-Item $tempGit -Force -ErrorAction SilentlyContinue
        Write-SetupStatus -Message "[OK] Git Portable Deployed." -Type OK
    } catch { Write-SetupStatus -Message "Git Installation Failed" -Type ERROR; Exit }
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
    Write-SetupStatus -Message "`n[PROCESS] Fetching Portable Node.js..." -Type WARN
    try {
        $indexUrl = Get-ProxifiedUrl -OriginalUrl "https://nodejs.org/dist/index.json"
        $index = Invoke-SetupRestMethod -Uri $indexUrl
        $selectedVer = if ($ReqVer) { ($index | Where-Object { $_.version -like "v$ReqVer*" } | Select-Object -First 1).version } 
                       else { ($index | Where-Object { $_.lts -ne $false } | Select-Object -First 1).version }
        
        if (-not $selectedVer) { Write-SetupStatus -Message "Version not found." -Type ERROR; Exit }
        
        $tempNode = Join-Path $mainTempDir "node-$selectedVer.zip"
        $tempExtractDir = Join-Path $mainTempDir "temp_node_extract"
        
        # Note: Node.js download can sometimes fail on many connections, limiting to 1 connection
        Invoke-FallbackDownload -DownloadUrl "https://nodejs.org/dist/$selectedVer/node-$selectedVer-win-x64.zip" -OutFilePath $tempNode -Aria2Connections 1
        
        Write-SetupStatus -Message "[EXTRACT] Unpacking Node.js Payload using 7-Zip..." -Type WARN
        if (Test-Path $tempExtractDir) { Remove-Item $tempExtractDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        
        Invoke-SetupCommand -CommandPath $7zExe -ArgumentList @("x", $tempNode, "-y", "-o$tempExtractDir", "-bsp1", "-bso0") -Parse7ZipProgress
        
        Get-ChildItem $nodeDir -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Move-Item "$((Get-ChildItem $tempExtractDir -Directory)[0].FullName)\*" $nodeDir -Force
        Remove-Item $tempNode, $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue

        Write-SetupStatus -Message "`n========================================================" -Type RAW -Color Green
        Write-SetupStatus -Message "[SUCCESS] Node.js $selectedVer Deployed Successfully!" -Type RAW -Color Green
        Write-SetupStatus -Message "Target: $nodeDir" -Type RAW -Color Yellow
        Write-SetupStatus -Message "========================================================" -Type RAW -Color Green
    } catch { Write-SetupStatus -Message "Node Installation Failed" -Type ERROR; Exit }
}

function Update-SessionPath {
    $resolvedGit = if (Test-Path "$gitDir\cmd\git.exe") { "$gitDir\cmd" } else { "$gitDir\bin" }
    $env:PATH = "$nodeDir;$resolvedGit;$7zDir;$aria2Dir;$env:PATH"
}

function Configure-NpmProxy {
    if (Get-Command "npm" -ErrorAction Ignore) {
        if (Test-ProxyHealth) {
            Write-SetupStatus -Message "[PROXY] Auto-configuring npm to use OmniProxy Gateway..." -Type INFO
            npm config set registry "$ProxyServerUrl/npm/"
        } else {
            npm config delete registry 2>$null
        }
    }
}

function Enter-LiveDevShell {
    Update-SessionPath
    Configure-NpmProxy
    Set-Location $workspaceDir
    Write-SetupStatus -Message "`n==========================================================" -Type RAW -Color Cyan
    Write-SetupStatus -Message " [ON] Node.js Dev Environment ACTIVE SHELL MODE" -Type RAW -Color Green
    Write-SetupStatus -Message "==========================================================" -Type RAW -Color Cyan
    Write-SetupStatus -Message " Workspace : $workspaceDir" -Type RAW -Color DarkGray
    if (Get-Command "node" -ErrorAction Ignore) { Write-SetupStatus -Message " node      : $(node -v) (npm $(npm -v))" -Type RAW -Color Gray }
    if (Get-Command "git" -ErrorAction Ignore) { Write-SetupStatus -Message " git       : $((git --version) -replace 'git version ','')" -Type RAW -Color Gray }
    Write-SetupStatus -Message "==========================================================" -Type RAW -Color Cyan
    Write-SetupStatus -Message "[INFO] You are inside the isolated portable shell.`n" -Type INFO
}

function Show-Help {
    Write-SetupStatus -Message "==========================================================" -Type RAW -Color Cyan
    Write-SetupStatus -Message ":: PORTABLE NODE.JS DEV SUITE :: COMMAND REFERENCE" -Type RAW -Color Cyan
    Write-SetupStatus -Message "==========================================================" -Type RAW -Color Cyan
    Write-SetupStatus -Message "[USAGE]" -Type RAW -Color Yellow
    Write-SetupStatus -Message "   .\setup.ps1 [OPTIONS]" -Type RAW -Color White
    Write-SetupStatus -Message "[OPTIONS]" -Type RAW -Color Yellow
    Write-SetupStatus -Message "  -h, --help            Show this help manual" -Type RAW -Color White
    Write-SetupStatus -Message "  -l, --list <tool>     List available versions ('node')" -Type RAW -Color White
    Write-SetupStatus -Message "  -i, --install <tool>  Install tools ('node', 'all', 'git')" -Type RAW -Color White
    Write-SetupStatus -Message "  -v, --version <ver>   Specify target version (e.g., -v 18, -v 20)" -Type RAW -Color White
    Write-SetupStatus -Message "  -u, --url <link>      Clone a GitHub repo into workspace (e.g., -u https://...)" -Type RAW -Color White
    Write-SetupStatus -Message "  -f, --force           Force re-download and overwrite existing tools" -Type RAW -Color White
    Write-SetupStatus -Message "  -y, --yes             Auto-confirm all prompts (Silent Mode)" -Type RAW -Color White
    Write-SetupStatus -Message "  -e, --env             Enter Live Shell environment directly (cd workspace)" -Type RAW -Color White
    Write-SetupStatus -Message "  -r, --run [folder]    Auto-Detect & Run project (npm install -> dev)" -Type RAW -Color White
    Write-SetupStatus -Message "[EXAMPLES]" -Type RAW -Color Yellow
    Write-SetupStatus -Message "   .\setup.ps1 -i all -y" -Type RAW -Color White
    Write-SetupStatus -Message "   .\setup.ps1 -u https://github.com/user/repo" -Type RAW -Color White
    Write-SetupStatus -Message "==========================================================" -Type RAW -Color Cyan
}

# ========================================================
# 4. Main Logic Router
# ========================================================

if ($PSBoundParameters.Count -eq 0 -or $ShowHelp) { Show-Help; Exit }

# [Mode] List (-l)
if ($ListTool -eq 'node') {
    $indexUrl = Get-ProxifiedUrl -OriginalUrl "https://nodejs.org/dist/index.json"
    $index = Invoke-SetupRestMethod -Uri $indexUrl
    $index | Where-Object { $_.lts -ne $false } | Group-Object { ([version]($_.version -replace '^v','')).Major } | 
    Sort-Object { [int]$_.Name } -Descending | ForEach-Object {
        $lt = $_.Group[0]; 
        Write-SetupStatus -Message "Node.js v$($_.Name) `t Latest: $($lt.version) `t LTS: $($lt.lts)" -Type RAW -Color Green
    }
    Exit
}

# [Mode] Install (-i)
if ($InstallTool) {
    if ($InstallTool -notin @('node', 'all', 'git')) { Write-SetupStatus -Message "Invalid tool." -Type ERROR; Exit }
    
    Ensure-CoreTools # Automatically installs 7z -> Aria2 -> Git
    
    if ($InstallTool -in @('node', 'all')) { Install-Node -ReqVer $TargetVersion }
    
    if (Test-Path $mainTempDir) { Remove-Item $mainTempDir -Recurse -Force -ErrorAction SilentlyContinue }
    Write-SetupStatus -Message "`n[SUCCESS] Installation Completed!" -Type OK
    Exit
}

# [Mode] URL Clone (-url)
if ($Url) {
    if ($Url -match '.*/([^/]+?)(?:\.git)?$') {
        $targetName = $Matches[1]
        Ensure-CoreTools
        if (Test-Path $mainTempDir) { Remove-Item $mainTempDir -Recurse -Force -ErrorAction SilentlyContinue }
        Update-SessionPath; Set-Location $workspaceDir
        if (-not (Test-Path $targetName)) {
            Write-SetupStatus -Message "Cloning repository $targetName..." -Type WARN
            Invoke-SetupCommand -CommandPath "git" -ArgumentList @("clone", $Url)
            Write-SetupStatus -Message "Repository cloned into workspace\$targetName" -Type OK
        } else { Write-SetupStatus -Message "Folder '$targetName' already exists in workspace." -Type INFO }
        
        if ($RunMode) {
            # Bridge to Run Mode: Override target folder to the newly cloned one
            $RemainingArgs = @($targetName)
        } else {
            Exit
        }
    } else { Write-SetupStatus -Message "Invalid URL." -Type ERROR; Exit }
}

# [Mode] Run / Execute (-r)
if ($RunMode) {
    Ensure-CoreTools; Install-Node
    if (Test-Path $mainTempDir) { Remove-Item $mainTempDir -Recurse -Force -ErrorAction SilentlyContinue }
    Update-SessionPath
    Configure-NpmProxy
    $targetFolder = $null

    if ($RemainingArgs.Count -gt 0) {
        $targetFolder = Join-Path $workspaceDir $RemainingArgs[0]
        if (-not (Test-Path $targetFolder)) { Write-SetupStatus -Message "Project folder not found: $($RemainingArgs[0])" -Type ERROR; $EnvMode = $true }
        elseif (-not (Test-Path "$targetFolder\package.json")) { Write-SetupStatus -Message "package.json missing in $($RemainingArgs[0])" -Type ERROR; $EnvMode = $true }
    } else {
        $validProjects = Get-ChildItem $workspaceDir -Directory | Where-Object { Test-Path "$($_.FullName)\package.json" }
        if ($validProjects.Count -eq 0) { Write-SetupStatus -Message "No Node.js projects (with package.json) found in workspace!" -Type ERROR; $EnvMode = $true }
        elseif ($validProjects.Count -eq 1) { $targetFolder = $validProjects[0].FullName; Write-SetupStatus -Message "Auto-selected: $($validProjects[0].Name)" -Type INFO }
        else {
            Write-SetupStatus -Message "`n[+] Multiple Node.js projects found. Please select one:" -Type RAW -Color Cyan
            for ($i=0; $i -lt $validProjects.Count; $i++) { Write-SetupStatus -Message "  [$($i+1)] $($validProjects[$i].Name)" -Type RAW -Color Green }
            Write-SetupStatus -Message "  [0] Exit to Shell`n" -Type RAW -Color Yellow
            $choice = Read-Host "> Enter project number"
            if ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $validProjects.Count) { $targetFolder = $validProjects[[int]$choice - 1].FullName }
            else { $EnvMode = $true }
        }
    }

    if (-not $EnvMode -and $targetFolder) {
        Set-Location $targetFolder
        Write-SetupStatus -Message "Running npm install..." -Type WARN
        npm install
        Write-SetupStatus -Message "Starting Development Server (npm run dev)..." -Type OK
        Write-SetupStatus -Message "Press Ctrl + C to stop the server" -Type INFO
        try { 
            npm run dev 
        } finally { 
            Write-SetupStatus -Message "[CLEANUP] Terminating background Node.js processes..." -Type INFO
            Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
            $EnvMode = $true 
        }
    }
}

# [Mode] Environment Shell (-e)
if ($EnvMode) {
    # FIX: Separated Test-Path conditions to avoid PowerShell parsing errors
    $isGitMissing = (-not (Test-Path "$gitDir\cmd\git.exe") -and -not (Test-Path "$gitDir\bin\git.exe"))
    $isNodeMissing = -not (Test-Path "$nodeDir\node.exe")

    if ($isNodeMissing -or $isGitMissing) {
        Write-SetupStatus -Message "`n[WARN] Core toolchains (Node/Git) are missing in 'tools' directory!" -Type WARN
        if ($AutoYes) {
            Ensure-CoreTools; Install-Node
            if (Test-Path $mainTempDir) { Remove-Item $mainTempDir -Recurse -Force -ErrorAction SilentlyContinue }
        } else {
            $ans = Read-Host "Would you like to auto-install missing tools now? [Y/n]"
            if ($ans -notmatch "^n") { 
                Ensure-CoreTools; Install-Node 
                if (Test-Path $mainTempDir) { Remove-Item $mainTempDir -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }
    Enter-LiveDevShell
}