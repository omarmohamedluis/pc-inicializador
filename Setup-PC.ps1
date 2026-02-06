<#
.SYNOPSIS
    PC Initializer - Master Setup Script (Multi-Profile)
.DESCRIPTION
    Automates the setup of a clean Windows PC:
    1. Windows Updates & Winget Setup
    2. Software Installation (Winget)
    3. Git Repository Cloning
    4. Manual Download Links
#>

param (
    [string]$Step = ""
)

# ==========================================
# CONFIGURATION
# ==========================================
$ScriptDir   = $PSScriptRoot
$LogFile     = Join-Path $ScriptDir "install.log"
$RepoDestDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "repositorios"

# Profile Variables (Set dynamically)
$InstallJson = ""
$ReposJson   = ""
$LinksJson   = ""
$ProfileName = ""

# Colors
$ColorTitle  = "Cyan"
$ColorError  = "Red"
$ColorSuccess= "Green"
$ColorInfo   = "Yellow"

# ==========================================
# HELPER FUNCTIONS
# ==========================================

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$Console = $true
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    $LogLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
    
    if ($Console) {
        $FColor = "White"
        switch ($Level) {
            "ERROR"   { $FColor = $ColorError }
            "SUCCESS" { $FColor = $ColorSuccess }
            "WARN"    { $FColor = $ColorInfo }
            "HEADER"  { $FColor = $ColorTitle }
        }
        Write-Host "$Message" -ForegroundColor $FColor
    }
}

function Show-Header {
    Clear-Host
    Write-Log "==========================================" "HEADER"
    Write-Log "      PC INITIALIZER - $ProfileName       " "HEADER"
    Write-Log "==========================================" "HEADER"
    Write-Host ""
}

function Ensure-Admin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Elevating permissions to Administrator..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru
        exit
    }
}

function Select-Profile {
    Clear-Host
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "   SELECT PC PROFILE     " -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. D3 (Media Server)"
    Write-Host "   - Creative Cloud, Notch, Timecode..."
    Write-Host ""
    Write-Host "2. CONTROL (Operator)"
    Write-Host "   - Companion, Lightware, Dante, X32..."
    Write-Host ""
    
    $Choice = Read-Host "Choose profile [1 or 2]"
    
    # Defaults to D3 if invalid, just to be safe, or loop? strict is better.
    if ($Choice -eq "2") {
        $global:ProfileName = "CONTROL"
        $Suffix = "control"
    } else {
        $global:ProfileName = "D3"
        $Suffix = "d3"
    }

    $global:InstallJson = Join-Path $ScriptDir "install_$Suffix.json"
    $global:ReposJson   = Join-Path $ScriptDir "repos_$Suffix.json"
    $global:LinksJson   = Join-Path $ScriptDir "links_$Suffix.json"

    Write-Host "Selected Profile: $global:ProfileName" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Test-Command ($cmd) {
    return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
}

function Check-GitToken {
    Write-Log "Checking GitHub credentials..." "INFO" -Console $false
    
    # 1. Check Internet
    if (-not (Test-Connection "github.com" -Count 1 -Quiet)) {
        Write-Log "No internet connection to GitHub." "WARN"
        return
    }

    # 2. Check if Token/Creds exist
    $envToken = $env:GITHUB_TOKEN
    $CredFile = Join-Path $env:USERPROFILE ".git-credentials"
    $HasCreds = (Test-Path $CredFile)

    if ([string]::IsNullOrWhiteSpace($envToken) -and -not $HasCreds) {
        Write-Host "NOTE: Private repositories require a Personal Access Token (PAT)." "WARN"
        
        $Choice = Read-Host "Enter GitHub PAT now? (Y/N) [Default: N]"
        if ($Choice -eq "Y") {
            $Token = Read-Host -Prompt "Paste GitHub Token (Hidden)" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
            $PlainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
            $CredPath = Join-Path $env:USERPROFILE ".git-credentials"
            $GitCredContext = "https://$PlainToken`:x-oauth-basic@github.com"
            try {
                git config --global credential.helper store
                Add-Content -Path $CredPath -Value $GitCredContext -Force
                Write-Log "Token saved." "SUCCESS"
            } catch {
                Write-Log "Failed to save token: $_" "ERROR"
            }
        }
    } else {
        Write-Log "GitHub credentials found or Token set." "SUCCESS"
    }
}

# ==========================================
# MAIN MODULES
# ==========================================

function Install-WindowsUpdates {
    Write-Log "--- STARTING STEP 1: WINDOWS UPDATES ---" "HEADER"
    
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installing PSWindowsUpdate module..." "INFO"
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop
            Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -ErrorAction Stop
        } catch {
            Write-Log "Failed to install PSWindowsUpdate module: $_" "ERROR"
            return
        }
    }

    Import-Module PSWindowsUpdate

    Write-Log "Scanning for updates (this may take a while)..." "INFO"
    try {
        $Updates = Get-WindowsUpdate -AcceptAll -Install -Verbose
        
        if ($Updates) {
            $Count = $Updates.Count
            if ($Count -eq $null) { $Count = 1 } # Handle single object case
            Write-Log "Found and installed $Count updates." "SUCCESS"
            foreach ($u in $Updates) {
                Write-Log "  -> Installed: $($u.Title)" "INFO" -Console $false
                Write-Host "  [UPDATED] $($u.Title)" -ForegroundColor Green
            }
        } else {
            Write-Log "No new Windows Updates found." "SUCCESS"
        }
    } catch {
        Write-Log "Error running Windows Update: $_" "ERROR"
    }

    Write-Log "Updating Winget Sources..." "INFO"
    try {
        $ResetProc = Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait -PassThru
        if ($ResetProc.ExitCode -ne 0) {
            Write-Log "Winget source update failed. Trying reset..." "WARN"
            Start-Process -FilePath "winget" -ArgumentList "source reset --force" -NoNewWindow -Wait
            Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait
        }
        Write-Log "Winget sources updated." "SUCCESS"
    } catch {
        Write-Log "Winget source update warning: $_" "WARN"
    }
    
    Write-Log "Step 1 Complete." "SUCCESS"
    Pause-If-Interactive
}

function Install-Software {
    Write-Log "--- STARTING STEP 2: SOFTWARE INSTALLATION ($ProfileName) ---" "HEADER"

    if (-not (Test-Path $InstallJson)) {
        Write-Log "Config file not found: $InstallJson" "ERROR"
        return
    }

    if (-not (Test-Command "winget")) {
        Write-Log "Winget command not found. Please run Step 1." "ERROR"
        return
    }

    Write-Host "Refreshing Winget sources..." -ForegroundColor Cyan
    Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait | Out-Null

    try {
        $JsonContent = Get-Content $InstallJson -Raw | ConvertFrom-Json
        $Packages = $JsonContent.Sources[0].Packages
    } catch {
        Write-Log "Failed to parse json: $_" "ERROR"
        return
    }

    $Total = $Packages.Count
    $Current = 0
    $Success = 0
    $Fail = 0

    foreach ($Pkg in $Packages) {
        $Current++
        $Id = $Pkg.PackageIdentifier
        Write-Host "`n[$Current/$Total] Installing: $Id" -ForegroundColor Cyan
        
        $Proc = Start-Process -FilePath "winget" -ArgumentList "install -e --id $Id --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait -PassThru
        
        if ($Proc.ExitCode -eq 0) {
            Write-Log "Successfully installed/updated: $Id" "SUCCESS" -Console $false
            Write-Host "  [OK] Installed/Updated" -ForegroundColor Green
            $Success++
        } elseif ($Proc.ExitCode -eq -1978335189 -or $Proc.ExitCode -eq -1978335135) { 
             Write-Log "Already up to date: $Id" "INFO" -Console $false
             Write-Host "  [OK] Already up to date" -ForegroundColor Yellow
             $Success++
        } else {
            Write-Log "Failed to install: $Id (Code: $($Proc.ExitCode))" "ERROR"
            Write-Host "  [ERROR] Failed" -ForegroundColor Red
            $Fail++
        }
    }

    Write-Log "Software Summary: Success=$Success, Failed=$Fail" "HEADER"
    Pause-If-Interactive
}

function Sync-Repositories {
    Write-Log "--- STARTING STEP 3: REPOSITORY CLONING ($ProfileName) ---" "HEADER"

    if (-not (Test-Path $ReposJson)) {
        Write-Log "Config file not found: $ReposJson" "ERROR"
        return
    }

    if (-not (Test-Command "git")) {
        Write-Log "Git command not found. Install Git first." "ERROR"
        return
    }

    if (-not (Test-Connection "github.com" -Count 1 -Quiet)) {
        Write-Log "No internet connection to GitHub." "ERROR"
        return
    }
    
    # Check-GitToken logic is handled upstream or interactively if run standalone

    try {
        $JsonContent = Get-Content $ReposJson -Raw | ConvertFrom-Json
        $Repos = $JsonContent.repositories
    } catch {
        Write-Log "Failed to parse repos json: $_" "ERROR"
        return
    }

    if (-not (Test-Path $RepoDestDir)) {
        New-Item -ItemType Directory -Path $RepoDestDir -Force | Out-Null
    }

    foreach ($Repo in $Repos) {
        $Url = $Repo.url.Trim()
        $Name = $Repo.name.Trim()
        
        if (-not $Url.EndsWith(".git")) { $Url += ".git" }
        $TargetDir = Join-Path $RepoDestDir $Name

        Write-Host "`nProcessing: $Name" -ForegroundColor Cyan
        
        if (Test-Path $TargetDir) {
            Write-Log "Updating repo: $Name" "INFO" -Console $false
            Push-Location $TargetDir
            try {
                git pull | Out-Null
                Write-Host "  [OK] Updated" -ForegroundColor Green
            } catch {
                Write-Host "  [ERROR] Pull failed" -ForegroundColor Red
            }
            Pop-Location
        } else {
            Write-Log "Cloning repo: $Name" "INFO" -Console $false
            try {
                git clone $Url $TargetDir | Out-Null
                if ($LASTEXITCODE -eq 0) {
                     Write-Host "  [OK] Cloned" -ForegroundColor Green
                } else {
                     Write-Host "  [ERROR] Clone failed" -ForegroundColor Red
                }
            } catch {
                Write-Host "  [ERROR] Clone Exception: $_" -ForegroundColor Red
            }
        }
    }
    
    Write-Log "Repository Sync Complete." "SUCCESS"
    Pause-If-Interactive
}

function Open-ManualLinks {
    Write-Log "--- STARTING STEP 4: MANUAL LINKS ($ProfileName) ---" "HEADER"
    
    if (-not (Test-Path $LinksJson)) {
        Write-Log "No manual links file found: $LinksJson" "WARN"
        return
    }

    try {
        $Links = Get-Content $LinksJson -Raw | ConvertFrom-Json
    } catch {
        Write-Log "Failed to parse manual links json." "ERROR"
        return
    }
    
    Write-Host "Opening download pages in default browser..." -ForegroundColor Cyan
    Write-Host "Please download and install these manually." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($Link in $Links) {
        $Name = $Link.Name
        $Url  = $Link.Url
        
        Write-Host "Opening: $Name" -ForegroundColor Cyan
        try {
            Start-Process $Url
            Start-Sleep -Milliseconds 500
        } catch {
            Write-Host "  [ERROR] Could not open $Url" -ForegroundColor Red
        }
    }
    
    Write-Log "All manual links opened." "SUCCESS"
    Pause-If-Interactive
}

function Pause-If-Interactive {
    if (-not $Script:NonInteractive) {
        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# ==========================================
# STATE MANAGEMENT (AUTO-REBOOT)
# ==========================================
$StateFile = Join-Path $ScriptDir ".setup_state"
$RegPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RegName   = "PCInitializerSetup"

function Get-SetupState {
    if (Test-Path $StateFile) {
        try {
            return Get-Content $StateFile -Raw | ConvertFrom-Json
        } catch {
            Write-Log "Corrupt state file found. Ignoring." "WARN"
            return $null
        }
    }
    return $null
}

function Save-SetupState {
    param (
        [string]$Profile,
        [int]$NextStep
    )
    $State = @{
        Profile = $Profile
        Step    = $NextStep
    }
    $State | ConvertTo-Json | Set-Content $StateFile -Force
    # Hide the file to keep desktop clean
    (Get-Item $StateFile).Attributes = "Hidden"
}

function Remove-SetupState {
    if (Test-Path $StateFile) { Remove-Item $StateFile -Force }
}

function Set-RegistryAutoRun {
    # We point to the BAT launcher to ensure Admin rights are requested on login
    $LauncherPath = Join-Path $ScriptDir "Run-Setup.bat"
    Set-ItemProperty -Path $RegPath -Name $RegName -Value "`"$LauncherPath`""
}

function Remove-RegistryAutoRun {
    if (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $RegPath -Name $RegName
    }
}

function Resume-AutoSequence {
    param ([PSCustomObject]$State)
    
    $global:ProfileName = $State.Profile
    $Suffix = if ($global:ProfileName -eq "CONTROL") { "control" } else { "d3" }
    
    # Reload Profile Context
    $global:InstallJson = Join-Path $ScriptDir "install_$Suffix.json"
    $global:ReposJson   = Join-Path $ScriptDir "repos_$Suffix.json"
    $global:LinksJson   = Join-Path $ScriptDir "links_$Suffix.json"
    
    Write-Log "--- RESUMING AUTO-SEQUENCE (Profile: $global:ProfileName, Step: $($State.Step)) ---" "HEADER"
    Start-Sleep -Seconds 2
    
    switch ($State.Step) {
        1 {
            Install-WindowsUpdates
            Save-SetupState -Profile $global:ProfileName -NextStep 2
            Write-Log "Step 1 Done. Rebooting..." "WARN"
            Start-Sleep -Seconds 3
            Restart-Computer -Force
            exit
        }
        2 {
            Install-Software
            Save-SetupState -Profile $global:ProfileName -NextStep 3
            Write-Log "Step 2 Done. Rebooting..." "WARN"
            Start-Sleep -Seconds 3
            Restart-Computer -Force
            exit
        }
        3 {
            Sync-Repositories
            Save-SetupState -Profile $global:ProfileName -NextStep 4
            Write-Log "Step 3 Done. Rebooting..." "WARN"
            Start-Sleep -Seconds 3
            Restart-Computer -Force
            exit
        }
        4 {
            Open-ManualLinks
            Remove-RegistryAutoRun
            Remove-SetupState
            Write-Log "AUTO-SEQUENCE COMPLETE!" "SUCCESS"
            Write-Host "`nALL STEPS FINISHED SUCCESSFULLY." -ForegroundColor Green
            Pause-If-Interactive
            exit
        }
    }
}

# ==========================================
# MAIN EXECUTION FLOW
# ==========================================

Ensure-Admin

# 1. CHECK FOR RESUME STATE
$State = Get-SetupState
if ($State) {
    Resume-AutoSequence -State $State
}

# 2. NORMAL STARTUP
Select-Profile

if ($Step) {
    # Non-interactive CLI mode
    $Script:NonInteractive = $true
    switch ($Step) {
        "1" { Install-WindowsUpdates }
        "2" { Install-Software }
        "3" { Sync-Repositories }
        "4" { Open-ManualLinks }
        "ALL" { 
            Install-WindowsUpdates
            Install-Software
            Sync-Repositories
            Open-ManualLinks
        }
    }
    exit
}

# 3. INTERACTIVE MENU
$Script:NonInteractive = $false

do {
    Show-Header
    Write-Host "1. Windows Updates + Winget Setup"
    Write-Host "2. Install Software ($ProfileName)"
    Write-Host "3. Sync Repositories ($ProfileName)"
    Write-Host "4. Open Manual Downloads ($ProfileName)"
    Write-Host "5. Execute ALL Steps"
    Write-Host "6. View Log"
    Write-Host "7. Restart PC"
    Write-Host "Q. Quit"
    Write-Host ""
    $Selection = Read-Host "Select an option"

    switch ($Selection) {
        "1" { Install-WindowsUpdates }
        "2" { Install-Software }
        "3" { Sync-Repositories }
        "4" { Open-ManualLinks }
        "5" { 
            Write-Host "`n[Auto-Reboot Mode]" -ForegroundColor Cyan
            $Reboot = Read-Host "Do you want to REBOOT between steps? (Recommended for clean installs) Y/N"
            
            if ($Reboot -eq "Y" -or $Reboot -eq "y") {
                Check-GitToken
                
                Write-Host "Initializing Auto-Sequence..." -ForegroundColor Yellow
                Set-RegistryAutoRun
                Save-SetupState -Profile $global:ProfileName -NextStep 1
                Write-Host "Starting Sequence. System will reboot now." -ForegroundColor Red
                Start-Sleep -Seconds 3
                Restart-Computer -Force
                exit
            } else {
                # Traditional sequential execution without reboots
                Check-GitToken
                Install-WindowsUpdates
                Install-Software
                Sync-Repositories
                Open-ManualLinks
            }
        }
        "6" { Invoke-Item $LogFile }
        "7" { 
            $Ans = Read-Host "Restart PC now? (Y/N)"
            if ($Ans -eq "Y") { Restart-Computer }
        }
        "Q" { exit }
        default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($true)
