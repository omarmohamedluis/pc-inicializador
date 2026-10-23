<#
.SYNOPSIS
    PC Initializer - Master Setup Script (Multi-Profile)
.DESCRIPTION
    Automates the setup of a clean Windows PC:
    1. Windows Updates (Clean Baseline)
    2. Windows Tweaks, Debloat & Winget Setup (WinUtil & Security-Only Policies)
    3. Software Installation (Winget + IDE Extensions)
    4. Git Repository Cloning & Manual Download Links
#>

param (
    [string]$Step = "",
    [string]$Profile = ""
)

# ==========================================
# CONFIGURATION
# ==========================================
$ScriptDir   = $PSScriptRoot
$RootDir     = Split-Path $ScriptDir -Parent
$RepoDestDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "repositorios"
$global:AppVersion = "1.0.0"

# Modo de pruebas rapido (Fast Testing Mode)
# Si es $true, omite la descarga e instalacion de Windows Updates en Paso 1
# para que los tests de reinicios y secuencia completa duren minutos.
# (Reactivar a $false para produccion final - ver REACTIVATE.todo)
$global:TestingMode_SkipWindowsUpdate = $false

# Directorio de logs dedicado
$global:LogDir = Join-Path $RootDir "logs"
if (-not (Test-Path $global:LogDir)) {
    New-Item -ItemType Directory -Path $global:LogDir -Force | Out-Null
}

function New-RunLogFile {
    param (
        [string]$Tag = "setup"
    )
    if (-not (Test-Path $global:LogDir)) {
        New-Item -ItemType Directory -Path $global:LogDir -Force | Out-Null
    }
    $Computer  = $env:COMPUTERNAME
    $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $FileName  = "${Tag}_${Computer}_${Timestamp}.log"
    return (Join-Path $global:LogDir $FileName)
}

function Get-LatestLogFile {
    if (Test-Path $global:LogDir) {
        $latest = Get-ChildItem -Path $global:LogDir -Filter "*.log" | Where-Object { $_.Name -notlike "error_*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { return $latest.FullName }
    }
    return $null
}

function Get-ErrorLogPath {
    param ([string]$MainLog = $global:LogFile)
    if (-not $MainLog) { return $null }
    $Dir = Split-Path $MainLog -Parent
    $Leaf = Split-Path $MainLog -Leaf
    return (Join-Path $Dir ("error_" + $Leaf))
}

# Inicializar variables globales de log y seguimiento de errores de PowerShell
$global:LogFile = $null
$global:LoggedPSErrors = @{}
$Error.Clear()

# Captura global de excepciones terminantes no controladas
trap {
    $lineNum = if ($_.InvocationInfo -and $_.InvocationInfo.ScriptLineNumber) { " (Linea $($_.InvocationInfo.ScriptLineNumber))" } else { "" }
    $errMsg  = "[EXCEPCION NO CONTROLADA$lineNum] $($_.Exception.Message)"
    try { Write-Log $errMsg "ERROR" } catch {}
    continue
}

# Forzar TLS 1.2 globalmente para descargas y modulos (PowerShell Gallery, NuGet, WinUtil, GitHub)
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Variables de perfil (se configuran dinamicamente)
$InstallJson = ""
$ReposJson   = ""
$LinksJson   = ""
$ProfileName = ""
$Suffix      = ""

# Colores para la consola
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

    if (-not $global:LogFile) {
        $global:LogFile = New-RunLogFile
    }

    if ($Level -eq "HEADER" -or $Level -eq "STEP_DONE") {
        $Border = "================================================================"
        $LogContent = "`r`n$Border`r`n[$Timestamp] $Message`r`n$Border"
        $LogContent | Out-File -FilePath $global:LogFile -Append -Encoding UTF8

        if ($Console) {
            $FColor = if ($Level -eq "STEP_DONE") { $ColorSuccess } else { $ColorTitle }
            Write-Host "`n$Border" -ForegroundColor $FColor
            Write-Host "  $Message" -ForegroundColor $FColor
            Write-Host "$Border`n" -ForegroundColor $FColor
        }
    } else {
        $LogLine = "[$Timestamp] [$Level] $Message"
        $LogLine | Out-File -FilePath $global:LogFile -Append -Encoding UTF8

        if ($Level -eq "ERROR") {
            $ErrFile = Get-ErrorLogPath
            if ($ErrFile) {
                $LogLine | Out-File -FilePath $ErrFile -Append -Encoding UTF8
            }
        }

        if ($Console) {
            $FColor = "White"
            switch ($Level) {
                "ERROR"   { $FColor = $ColorError }
                "SUCCESS" { $FColor = $ColorSuccess }
                "WARN"    { $FColor = $ColorInfo }
            }
            Write-Host "$Message" -ForegroundColor $FColor
        }
    }
}

function Sync-PowerShellErrors {
    param ([string]$Context = "PowerShell")
    if ($Error.Count -gt 0 -and $global:LogFile) {
        for ($i = $Error.Count - 1; $i -ge 0; $i--) {
            $err = $Error[$i]
            if (-not $err) { continue }
            $invLine = if ($err.InvocationInfo -and $err.InvocationInfo.Line) { $err.InvocationInfo.Line } else { "" }
            # Ignorar comprobaciones internas silenciadas intencionadamente
            if ($invLine -match 'SilentlyContinue|Test-Command|GetResponse') { continue }

            $lineNum = if ($err.InvocationInfo -and $err.InvocationInfo.ScriptLineNumber) { $err.InvocationInfo.ScriptLineNumber } else { 0 }
            $msg = if ($err.Exception) { $err.Exception.Message } else { "$err" }
            $errKey = "${lineNum}:${msg}"
            if (-not $global:LoggedPSErrors.ContainsKey($errKey)) {
                $global:LoggedPSErrors[$errKey] = $true
                $lineInfo = if ($lineNum -gt 0) { " (Linea $lineNum)" } else { "" }
                Write-Log "[$Context Error$lineInfo] $msg" "ERROR" -Console $false
            }
        }
    }
}

function Initialize-RunLog {
    param ([string]$Tag = "setup")
    $global:LogFile = New-RunLogFile -Tag $Tag
    Write-Log "PowerShell security protocols initialized: $([Net.ServicePointManager]::SecurityProtocol)" "INFO" -Console $false
    Log-SystemInfo
}

function Write-StepStart {
    param ([string]$StepName)
    Write-Log "$StepName INICIADO" "HEADER"
}

function Write-StepEnd {
    param ([string]$StepName)
    Sync-PowerShellErrors -Context $StepName
    Write-Log "$StepName FINALIZADO CON EXITO" "STEP_DONE"
}

function Show-Header {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "         PC INITIALIZER v$global:AppVersion - $global:ProfileName" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Ensure-Admin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Elevating permissions to Administrator..." -ForegroundColor Yellow
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

function Select-Profile {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                    SELECCION DE PERFIL                         " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. DESIGNER BASICO"
    Write-Host "   - Creative Cloud, Notch, Timecode..."
    Write-Host ""
    Write-Host "2. OMAR"
    Write-Host "   - Companion, Lightware, Dante, X32..."
    Write-Host ""

    $Choice = Read-Host "Elige un perfil [1 o 2]"

    if ($Choice -eq "2") {
        $global:ProfileName = "OMAR"
        $global:Suffix = "omar"
    } else {
        $global:ProfileName = "DESIGNER BASICO"
        $global:Suffix = "designer_basico"
    }

    $global:InstallJson = Join-Path $ScriptDir "install_$global:Suffix.json"
    $global:ReposJson   = Join-Path $ScriptDir "repos_$global:Suffix.json"
    $global:LinksJson   = Join-Path $ScriptDir "links_$global:Suffix.json"

    Write-Host "Perfil seleccionado: $global:ProfileName" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Test-Command ($cmd) {
    $errBefore = $Error.Count
    $res = (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
    while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
    return $res
}

function Update-SessionEnvironment {
    try {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $userPath    = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        $env:Path    = "$machinePath;$userPath"

        $gitDirs = @(
            "C:\Program Files\Git\cmd",
            "C:\Program Files\Git\bin",
            "$env:LOCALAPPDATA\Programs\Git\cmd",
            "$env:LOCALAPPDATA\Programs\Git\bin"
        )
        foreach ($gd in $gitDirs) {
            if ((Test-Path -LiteralPath $gd -ErrorAction SilentlyContinue) -and ($env:Path -notlike "*$gd*")) {
                $env:Path = "$gd;$env:Path"
            }
        }
    } catch {
        Write-Log "Warning updating session environment: $_" "WARN" -Console $false
    }
    Sync-PowerShellErrors -Context "Update-SessionEnvironment"
}

function Configure-WingetSettings {
    Write-Log "Configuring Winget settings (Store certificate pinning bypass)..." "INFO" -Console $false
    try {
        $settingsDir = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState"
        if (-not (Test-Path $settingsDir)) {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        }
        $settingsPath = Join-Path $settingsDir "settings.json"

        $settingsObj = [ordered]@{
            "`$schema" = "https://aka.ms/winget-settings.schema.json"
            "network" = [ordered]@{
                "bypassCertificatePinningForMicrosoftStore" = $true
            }
        }

        if (Test-Path $settingsPath) {
            try {
                $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json
                if (-not $existing.network) {
                    $existing | Add-Member -NotePropertyName "network" -NotePropertyValue (New-Object PSObject) -Force
                }
                $existing.network.bypassCertificatePinningForMicrosoftStore = $true
                $jsonText = $existing | ConvertTo-Json -Depth 5
                [System.IO.File]::WriteAllText($settingsPath, $jsonText, [System.Text.Encoding]::UTF8)
            } catch {
                $jsonText = $settingsObj | ConvertTo-Json -Depth 5
                [System.IO.File]::WriteAllText($settingsPath, $jsonText, [System.Text.Encoding]::UTF8)
            }
        } else {
            $jsonText = $settingsObj | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($settingsPath, $jsonText, [System.Text.Encoding]::UTF8)
        }
        Write-Log "Winget settings configured successfully." "SUCCESS" -Console $false
    } catch {
        Write-Log "Could not configure Winget settings: $_" "WARN"
    }
}

function Update-WingetSources {
    Write-Log "Configuring and updating Winget Sources..." "INFO"
    try {
        Configure-WingetSettings
        $ResetProc = Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait -PassThru
        if ($ResetProc.ExitCode -ne 0) {
            Write-Log "Winget source update returned exit code $($ResetProc.ExitCode). Resetting sources..." "WARN"
            Start-Process -FilePath "winget" -ArgumentList "source reset --force" -NoNewWindow -Wait
            Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait
        }
        Write-Log "Winget sources updated successfully." "SUCCESS"
    } catch {
        Write-Log "Winget source update warning: $_" "WARN"
    }
}

function Set-WindowsUpdatePolicies {
    Write-Log "Configuring Windows Update policy (Chris Titus 'Security Only' mode)..." "INFO"
    try {
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

        if (-not (Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
        if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }

        # 1. No instalar drivers genericos a traves de Windows Update
        Set-ItemProperty -Path $wuPath -Name "ExcludeWUDriversInQualityUpdate" -Type DWord -Value 1

        # 2. Retrasar actualizaciones mayores de caracteristicas (Feature Updates) 365 dias
        Set-ItemProperty -Path $wuPath -Name "DeferFeatureUpdates" -Type DWord -Value 1
        Set-ItemProperty -Path $wuPath -Name "DeferFeatureUpdatesPeriodInDays" -Type DWord -Value 365

        # 3. Retrasar parches acumulativos 4 dias (evita errores de parches Dia-0)
        Set-ItemProperty -Path $wuPath -Name "DeferQualityUpdates" -Type DWord -Value 1
        Set-ItemProperty -Path $wuPath -Name "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 4

        # 4. Descargar automaticamente y avisar (no reiniciar forzosamente si hay sesion activa)
        Set-ItemProperty -Path $auPath -Name "AUOptions" -Type DWord -Value 3
        Set-ItemProperty -Path $auPath -Name "AUPowerManagement" -Type DWord -Value 0
        Set-ItemProperty -Path $auPath -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1

        Write-Log "Windows Update policies configured successfully (Security-Only Mode)." "SUCCESS"
    } catch {
        Write-Log "Failed to configure Windows Update policies: $_" "WARN"
    }
}

function Get-WingetErrorDescription ([int]$Code) {
    switch ($Code) {
        0           { return "Instalacion exitosa" }
        3010        { return "Instalacion exitosa (Reinicio requerido)" }
        1641        { return "Instalacion exitosa (Reinicio iniciado)" }
        -1978335189 { return "El paquete ya se encuentra instalado" }
        -1978335135 { return "Ya esta en la version mas reciente" }
        -1978335138 { return "Fallo de certificado SSL / Microsoft Store (0x8A15005E)" }
        -1978335215 { return "Paquete no encontrado en el repositorio (0x8A150011)" }
        -1978335216 { return "Multiples paquetes coinciden con el identificador (0x8A150010)" }
        -1978335227 { return "Error al descargar instalador / Fallo de conexion (0x8A150005)" }
        -1978335220 { return "El hash SHA256 no coincide (0x8A15000C)" }
        -1978335212 { return "El instalador devolvio un error (0x8A150014)" }
        1603        { return "Error fatal durante la instalacion (MSI 1603)" }
        1618        { return "Otra instalacion de Windows Installer en curso (MSI 1618)" }
        default     { 
            $hex = "0x" + [Convert]::ToString($Code, 16).ToUpper()
            return "Codigo de error ($hex)"
        }
    }
}

function Log-SystemInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $driveC = Get-PSDrive C -ErrorAction SilentlyContinue

        $osName = if ($os) { "$($os.Caption) (Build $($os.BuildNumber))" } else { [Environment]::OSVersion.VersionString }
        $model = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() } else { "Desconocido" }
        $cpuName = if ($cpu) { $cpu.Name.Trim() } else { "Desconocido" }
        $ramGb = if ($cs -and $cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { "N/A" }
        $diskFreeGb = if ($driveC) { [math]::Round($driveC.Free / 1GB, 1) } else { "N/A" }
        $diskTotalGb = if ($driveC) { [math]::Round(($driveC.Used + $driveC.Free) / 1GB, 1) } else { "N/A" }
        $psVer = $PSVersionTable.PSVersion.ToString()
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        Write-Log "DATOS DEL SISTEMA" "HEADER" -Console $false
        Write-Log "  Version:      v$global:AppVersion" "INFO" -Console $false
        Write-Log "  Equipo:       $env:COMPUTERNAME" "INFO" -Console $false
        Write-Log "  OS:           $osName" "INFO" -Console $false
        Write-Log "  Hardware:     $model" "INFO" -Console $false
        Write-Log "  CPU:          $cpuName" "INFO" -Console $false
        Write-Log "  RAM Total:    $ramGb GB" "INFO" -Console $false
        Write-Log "  Disco C:      $diskFreeGb GB libres de $diskTotalGb GB" "INFO" -Console $false
        Write-Log "  Usuario:      $env:USERDOMAIN\$env:USERNAME (Admin: $isAdmin)" "INFO" -Console $false
        Write-Log "  PowerShell:   v$psVer" "INFO" -Console $false
    } catch {
        Write-Log "No se pudo recopilar informacion detallada del sistema: $_" "WARN" -Console $false
    }
}

function Test-Internet {
    # Verificar conectividad DNS + HTTPS real (evita falsos positivos de ping IP cuando el DNS aun no ha levantado tras reiniciar)
    $errBefore = $Error.Count
    $testUrls = @(
        "https://github.com",
        "https://www.microsoft.com",
        "https://www.google.com"
    )
    foreach ($url in $testUrls) {
        try {
            $req = [System.Net.WebRequest]::Create($url)
            $req.Method = "HEAD"
            $req.Timeout = 4000
            $resp = $req.GetResponse()
            $resp.Close()
            while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
            return $true
        } catch {}
    }

    while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
    return $false
}

function Wait-ForInternet {
    param (
        [int]$MaxRetries = 4,
        [int]$WaitSeconds = 5
    )
    
    Write-Log "Comprobando conexion a Internet..." "INFO"
    for ($i = 1; $i -le $MaxRetries; $i++) {
        if (Test-Internet) {
            Write-Log "Conexion a Internet confirmada." "SUCCESS"
            return $true
        }
        
        if ($i -lt $MaxRetries) {
            Write-Log "Sin conexion a Internet (intento $i de $MaxRetries). Reintentando en $WaitSeconds segundos..." "WARN"
            Start-Sleep -Seconds $WaitSeconds
        }
    }
    
    Write-Log "No hay internet, intentelo con internet." "ERROR"
    return $false
}

function Assert-Internet {
    param (
        [int]$MaxRetries = 6,
        [int]$WaitSeconds = 5
    )
    if (-not (Wait-ForInternet -MaxRetries $MaxRetries -WaitSeconds $WaitSeconds)) {
        Write-Log "ERROR CRITICO: Sin conexion a Internet. Deteniendo ejecucion del script." "ERROR"
        Write-Host "`n========================================================" -ForegroundColor Red
        Write-Host " ERROR CRITICO: NO HAY CONEXION A INTERNET" -ForegroundColor Red
        Write-Host "========================================================" -ForegroundColor Red
        Write-Host "El script se ha detenido porque se requiere conexion de red activa." -ForegroundColor Yellow
        Write-Host "Comprueba tu conexion / ejecuta 'ipconfig /renew' y vuelve a iniciar." -ForegroundColor Yellow
        Write-Host "========================================================`n" -ForegroundColor Red
        Write-Host "Presiona cualquier tecla para cerrar la ventana..." -ForegroundColor Yellow
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 15
        }
        exit 1
    }
}

function Unprotect-SecretAES {
    param(
        [string]$Base64Cipher,
        [string]$Password
    )
    try {
        $AllBytes = [Convert]::FromBase64String($Base64Cipher)
        if ($AllBytes.Length -le 16) { return $null }
        
        $Salt = New-Object byte[] 16
        [Array]::Copy($AllBytes, 0, $Salt, 0, 16)
        
        $EncryptedBytes = New-Object byte[] ($AllBytes.Length - 16)
        [Array]::Copy($AllBytes, 16, $EncryptedBytes, 0, $EncryptedBytes.Length)
        
        $DeriveBytes = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, 10000)
        $Key = $DeriveBytes.GetBytes(32)
        $IV = $DeriveBytes.GetBytes(16)
        
        $Aes = [System.Security.Cryptography.Aes]::Create()
        $Aes.Key = $Key
        $Aes.IV = $IV
        
        $Decryptor = $Aes.CreateDecryptor()
        $PlainBytes = $Decryptor.TransformFinalBlock($EncryptedBytes, 0, $EncryptedBytes.Length)
        
        return [System.Text.Encoding]::UTF8.GetString($PlainBytes)
    } catch {
        return $null
    }
}

function Test-GitHubToken {
    param (
        [string]$Token
    )
    if ([string]::IsNullOrWhiteSpace($Token)) { return $null }

    $errBefore = $Error.Count
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $headers = @{
                "Authorization" = "Bearer $Token"
                "User-Agent"    = "PowerShell-PCInitializer"
            }
            $resp = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
            if ($resp -and $resp.login) {
                while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
                return $resp.login
            }
        } catch {
            if ($attempt -lt 2) { Start-Sleep -Seconds 2 }
        }
    }
    while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
    return $null
}

function Save-GitCredentials {
    param (
        [string]$Token,
        [string]$User
    )
    $global:GitHubToken = $Token
    $global:GitHubUser  = $User
    $env:GITHUB_TOKEN   = $Token
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "never"
    [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", $Token, [EnvironmentVariableTarget]::User)
    
    $CredFile = Join-Path $env:USERPROFILE ".git-credentials"
    if (Test-Command "git") {
        git config --global credential.helper store 2>$null
        git config --global credential.interactive never 2>$null
    }
    $lines = @(
        "https://${User}:${Token}@github.com",
        "https://${Token}@github.com",
        "https://${Token}:x-oauth-basic@github.com"
    )
    $existing = if (Test-Path $CredFile) {
        @(Get-Content $CredFile -ErrorAction SilentlyContinue | Where-Object { $_ -and $_ -notmatch '@github\.com' })
    } else {
        @()
    }
    $newContent = $existing + $lines
    $newContent | Set-Content -Path $CredFile -Encoding ascii -Force
}

function Check-GitToken {
    Write-Log "Checking GitHub credentials..." "INFO" -Console $false
    
    # Si ya tenemos credenciales validadas (en la sesion actual o restauradas desde Paso 0 via .setup_state),
    # aplicar configuracion en git (por si Git se acaba de instalar en el Paso 3) y continuar sin preguntar.
    if ($global:GitHubToken -and $global:GitHubUser) {
        Save-GitCredentials -Token $global:GitHubToken -User $global:GitHubUser
        Write-Log "GitHub ya autenticado desde el inicio de la secuencia como: $global:GitHubUser" "SUCCESS"
        return
    }

    if (-not (Wait-ForInternet -MaxRetries 4 -WaitSeconds 5)) {
        Write-Host "`nNo hay internet, intentelo con internet." -ForegroundColor Red
        return
    }

    $CredFile = Join-Path $env:USERPROFILE ".git-credentials"
    $TokenTxt = Join-Path $ScriptDir "github_token.txt"
    $TokenEnc = Join-Path $ScriptDir "github_token.enc"

    # PRIORIDAD 1: Credenciales ya configuradas en Windows ($env:GITHUB_TOKEN o ~/.git-credentials)
    # Permite que tras reinicios el Paso 4 no vuelva a preguntar nada.
    $envToken = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "User")
    if (-not $envToken) { $envToken = $env:GITHUB_TOKEN }
    $SavedToken = $null

    if (-not [string]::IsNullOrWhiteSpace($envToken)) {
        $SavedToken = $envToken.Trim()
    } elseif (Test-Path $CredFile) {
        $content = Get-Content $CredFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'https://[^:]+:([a-zA-Z0-9_]+)@github\.com') {
            $SavedToken = $matches[1].Trim()
        } elseif ($content -match 'https://([a-zA-Z0-9_]+)@github\.com') {
            $SavedToken = $matches[1].Trim()
        }
    }

    if ($SavedToken) {
        $ghUser = Test-GitHubToken -Token $SavedToken
        if ($ghUser) {
            Write-Log "Credenciales de GitHub verificadas automaticamente para '$ghUser'." "SUCCESS"
            Write-Host "GitHub autenticado automaticamente como: $ghUser" -ForegroundColor Green
            Save-GitCredentials -Token $SavedToken -User $ghUser
            return
        }
    }

    # PRIORIDAD 2: Token en texto plano en el USB (github_token.txt) -> 100% automatico y silencioso
    if (Test-Path $TokenTxt) {
        $RawToken = (Get-Content $TokenTxt -Raw -ErrorAction SilentlyContinue).Trim()
        if (-not [string]::IsNullOrWhiteSpace($RawToken)) {
            Write-Host "Detectado archivo de token local en USB (github_token.txt)..." -ForegroundColor Cyan
            $ghUser = Test-GitHubToken -Token $RawToken
            if ($ghUser) {
                Write-Log "Token de GitHub cargado automaticamente desde $TokenTxt (Usuario: $ghUser)." "SUCCESS"
                Write-Host "GitHub autenticado automaticamente como: $ghUser" -ForegroundColor Green
                Save-GitCredentials -Token $RawToken -User $ghUser
                return
            } else {
                Write-Log "El token en $TokenTxt fue rechazado por la API de GitHub." "WARN"
                Write-Host "[AVISO] El token en github_token.txt no es valido o caduco." -ForegroundColor Yellow
            }
        }
    }

    # PRIORIDAD 3: Token cifrado en el USB (github_token.enc) -> Clave maestra o token directo
    if (Test-Path $TokenEnc) {
        $Cipher = (Get-Content $TokenEnc -Raw -ErrorAction SilentlyContinue).Trim()
        if (-not [string]::IsNullOrWhiteSpace($Cipher)) {
            Write-Host "`n========================================================" -ForegroundColor Cyan
            Write-Host " [SEGURIDAD] Token de GitHub cifrado detectado en el USB" -ForegroundColor Cyan
            Write-Host "========================================================" -ForegroundColor Cyan
            
            try {
                $curLang = (Get-WinUserLanguageList)[0].LanguageTag
                Write-Host "Teclado activo de Windows en este sistema: $curLang" -ForegroundColor Gray
            } catch {}

            Write-Host "Introduce la clave que pusiste al cifrar github_token.enc," -ForegroundColor Gray
            Write-Host "o pega directamente tu Personal Access Token (PAT que empieza por ghp_):" -ForegroundColor Gray
            
            $Attempts = 0
            while ($Attempts -lt 3) {
                $Attempts++
                $PassSecure = Read-Host -Prompt "Clave de descifrado o Token PAT (Intento $Attempts/3)" -AsSecureString
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassSecure)
                $InputVal = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                
                if ([string]::IsNullOrWhiteSpace($InputVal)) {
                    Write-Host "No has introducido ninguna clave." -ForegroundColor Yellow
                    continue
                }

                # Caso A: El usuario pego directamente un token PAT (ghp_..., github_pat_...)
                if ($InputVal.StartsWith("ghp_") -or $InputVal.StartsWith("github_pat_") -or $InputVal.StartsWith("gho_")) {
                    $ghUser = Test-GitHubToken -Token $InputVal
                    if ($ghUser) {
                        Write-Log "Token PAT directo verificado con exito para '$ghUser'." "SUCCESS"
                        Write-Host "Token PAT valido! Conectado como: $ghUser" -ForegroundColor Green
                        Save-GitCredentials -Token $InputVal -User $ghUser
                        return
                    } else {
                        Write-Host "El token PAT introducido fue rechazado por GitHub o no hay conexion." -ForegroundColor Red
                        continue
                    }
                }

                # Caso B: Descifrar el archivo cifrado usando la clave introducida
                $Decrypted = Unprotect-SecretAES -Base64Cipher $Cipher -Password $InputVal
                if ($Decrypted) {
                    Write-Host "  -> Clave correcta! Descifrado OK. Validando con GitHub..." -ForegroundColor Cyan
                    $ghUser = Test-GitHubToken -Token $Decrypted
                    if ($ghUser) {
                        Write-Log "Token de GitHub descifrado y validado con exito para '$ghUser'." "SUCCESS"
                        Write-Host "Token descifrado correctamente! Conectado como: $ghUser" -ForegroundColor Green
                        Save-GitCredentials -Token $Decrypted -User $ghUser
                        return
                    } else {
                        Write-Host "  [AVISO] La clave es CORRECTA, pero GitHub rechazo el token guardado." -ForegroundColor Yellow
                        Write-Host "  Es posible que el token haya caducado en GitHub o no haya conexion." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Clave incorrecta (no coincide con el cifrado de este archivo)." -ForegroundColor Red
                    if ($Attempts -eq 1) {
                        Write-Host "  [PISTA] Comprueba si la VM tiene el teclado en Ingles (EN) o mayusculas activadas." -ForegroundColor Yellow
                    }
                }
            }
            Write-Log "Fallo al autenticar token de GitHub tras 3 intentos." "WARN"
            Write-Host "No se pudo autenticar el token del USB tras 3 intentos." -ForegroundColor Yellow
        }
    }

    # PRIORIDAD 4: Entrada manual interactiva como fallback
    Write-Host "`nNOTA: Los repositorios privados requieren un Personal Access Token (PAT)." -ForegroundColor Yellow
    Write-Host "Generalo en GitHub -> Settings -> Developer Settings -> Personal access tokens." -ForegroundColor Gray
    $Choice = Read-Host "Quieres introducir un GitHub PAT ahora? (Y/N) [Default: N]"
    if ($Choice -ne "Y" -and $Choice -ne "y") {
        Write-Log "Paso de token de GitHub omitido." "INFO"
        return
    }

    do {
        $Token = Read-Host -Prompt "Pega tu GitHub PAT (ej: ghp_..., se ocultara)" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
        $PlainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        
        if ([string]::IsNullOrWhiteSpace($PlainToken)) {
            Write-Host "No has introducido ningun token." -ForegroundColor Yellow
            $Retry = Read-Host "Quieres volver a intentarlo? (Y/N) [Default: Y]"
            if ($Retry -eq "N" -or $Retry -eq "n") {
                Write-Log "Configuracion de token cancelada por el usuario." "WARN"
                return
            }
            continue
        }

        Write-Host "Validando token con la API de GitHub..." -ForegroundColor Cyan
        $ghUser = Test-GitHubToken -Token $PlainToken
        
        if ($ghUser) {
            Write-Log "Token de GitHub validado con exito para el usuario '$ghUser'." "SUCCESS"
            Write-Host "Token valido! Conectado como: $ghUser" -ForegroundColor Green
            Save-GitCredentials -Token $PlainToken -User $ghUser
            break
        } else {
            Write-Log "El token de GitHub introducido no es valido o fue rechazado por la API." "ERROR"
            Write-Host "`n[ERROR] El token introducido NO es valido (GitHub devolvio error de autenticacion)." -ForegroundColor Red
            $Retry = Read-Host "Quieres volver a intentarlo? (Y/N) [Default: Y]"
            if ($Retry -eq "N" -or $Retry -eq "n") {
                Write-Log "Configuracion de token cancelada tras fallo de validacion." "WARN"
                return
            }
        }
    } while ($true)
}

function Install-WindowsUpdates {
    Write-StepStart "PASO 1 - ACTUALIZACIONES DE WINDOWS"

    if ($global:TestingMode_SkipWindowsUpdate) {
        Write-Log "[MODO TEST RAPIDO ACTIVO] Busqueda de Windows Updates omitida temporalmente." "WARN"
        Write-Log "Reactivar en REACTIVATE.todo cambiando `$global:TestingMode_SkipWindowsUpdate = `$false" "INFO"
        Write-StepEnd "PASO 1 - ACTUALIZACIONES DE WINDOWS"
        Pause-If-Interactive
        return
    }

    Assert-Internet -MaxRetries 6 -WaitSeconds 5

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installing PSWindowsUpdate module..." "INFO"
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop
            Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -ErrorAction Stop
        } catch {
            Write-Log "Failed to install PSWindowsUpdate module: $_" "ERROR"
            Write-StepEnd "PASO 1 - ACTUALIZACIONES DE WINDOWS"
            Pause-If-Interactive
            return
        }
    }

    Import-Module PSWindowsUpdate

    Write-Log "Scanning for Windows updates (this may take a while)..." "INFO"
    try {
        $Updates = Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Verbose
        
        if ($Updates) {
            $Count = $Updates.Count
            if ($Count -eq $null) { $Count = 1 }
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

    Write-StepEnd "PASO 1 - ACTUALIZACIONES DE WINDOWS"
    Pause-If-Interactive
}

function Get-WinUtilScriptContent {
    $LocalWinUtil = Join-Path $ScriptDir "winutil.ps1"
    $WinUtilUrls = @(
        "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1",
        "https://christitus.com/win"
    )

    foreach ($url in $WinUtilUrls) {
        try {
            Write-Log "Downloading WinUtil from $url..." "INFO" -Console $false
            $raw = Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop
            if ($raw -and $raw.Length -gt 10000) {
                Write-Log "WinUtil downloaded successfully from $url ($($raw.Length) chars)." "SUCCESS" -Console $false
                try {
                    [System.IO.File]::WriteAllText($LocalWinUtil, $raw, [System.Text.Encoding]::UTF8)
                } catch {}
                return $raw
            }
        } catch {
            Write-Log "Could not download WinUtil from ${url}: $($_.Exception.Message)" "WARN" -Console $false
        }
    }

    if (Test-Path -LiteralPath $LocalWinUtil -ErrorAction SilentlyContinue) {
        Write-Log "Using cached local WinUtil copy from USB ($LocalWinUtil)..." "INFO"
        return (Get-Content -LiteralPath $LocalWinUtil -Raw -Encoding UTF8 -ErrorAction Stop)
    }

    throw "No se pudo descargar WinUtil ni se encontro copia local en $LocalWinUtil"
}

function Invoke-WinUtilTweaks {
    Write-StepStart "PASO 2 - TWEAKS, DEBLOAT Y CONFIGURACION DE WINGET"
    Assert-Internet -MaxRetries 6 -WaitSeconds 5

    # 1. Configurar Winget y actualizar fuentes primero
    Update-WingetSources

    # 2. Configurar directivas de actualizacion de Windows (Modo Security Only)
    Set-WindowsUpdatePolicies

    # 3. Aplicar tweaks con WinUtil en modo headless
    $ConfigFile = Join-Path $ScriptDir "winutil_config.json"
    if ($global:Suffix) {
        $ProfileConfigFile = Join-Path $ScriptDir "winutil_$global:Suffix.json"
        if (Test-Path $ProfileConfigFile) {
            $ConfigFile = $ProfileConfigFile
        }
    }

    if (Test-Path $ConfigFile) {
        Write-Log "Found WinUtil config file: $ConfigFile" "INFO"
        Write-Host "Applying Windows tweaks in headless mode (capturing full live stream)..." -ForegroundColor Cyan
        try {
            $winUtilRaw = Get-WinUtilScriptContent
            $winUtilScript = [scriptblock]::Create($winUtilRaw)
            $lastWinUtilLine = ""
            & $winUtilScript -Config $ConfigFile *>&1 | ForEach-Object {
                $cleanLine = ("$_" -replace "`r", "").Trim()
                if ($cleanLine -ne "" -and $cleanLine -ne $lastWinUtilLine) {
                    $lastWinUtilLine = $cleanLine
                    if ($_ -is [System.Management.Automation.ErrorRecord]) {
                        Write-Host "  [WinUtil ERROR] $cleanLine" -ForegroundColor Red
                        Write-Log "[WinUtil ERROR] $cleanLine" "ERROR" -Console $false
                    } else {
                        Write-Host "  [WinUtil] $cleanLine" -ForegroundColor DarkCyan
                        Write-Log "[WinUtil] $cleanLine" "INFO" -Console $false
                    }
                }
            }
            $Host.UI.RawUI.WindowTitle = "PC Initializer v$global:AppVersion - $global:ProfileName"

            # Copiar el log interno de WinUtil a la carpeta logs/ del USB para inspeccion detallada
            try {
                $wuLogDir = Join-Path $env:LOCALAPPDATA "winutil\logs"
                if (Test-Path $wuLogDir) {
                    $latestWuLog = Get-ChildItem -Path $wuLogDir -Filter "winutil_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if ($latestWuLog) {
                        $destWuLog = Join-Path $global:LogDir ("winutil_" + $env:COMPUTERNAME + "_" + $latestWuLog.Name.Replace("winutil_", ""))
                        Copy-Item -LiteralPath $latestWuLog.FullName -Destination $destWuLog -Force -ErrorAction SilentlyContinue
                        Write-Log "WinUtil detailed log copied to: $destWuLog" "INFO" -Console $false
                    }
                }
            } catch {}

            Write-Log "WinUtil tweaks applied successfully." "SUCCESS"
        } catch {
            Write-Log "Error applying WinUtil tweaks: $_" "ERROR"
        }
    } else {
        Write-Log "No WinUtil config file found at $ConfigFile." "WARN"
        if (-not $Script:NonInteractive) {
            Write-Host "`nNo se ha encontrado el archivo de configuracion ($ConfigFile)." -ForegroundColor Yellow
            Write-Host "Deseas abrir WinUtil ahora de forma interactiva para configurarlo? (Y/N) [Default: N]" -ForegroundColor Cyan
            $Choice = Read-Host
            if ($Choice -eq "Y" -or $Choice -eq "y") {
                try {
                    $winUtilRaw = Get-WinUtilScriptContent
                    Invoke-Expression $winUtilRaw
                    Write-Log "WinUtil interactive session finished." "SUCCESS"
                } catch {
                    Write-Log "Failed to launch WinUtil: $_" "ERROR"
                }
            } else {
                Write-Log "Skipped WinUtil tweaks." "INFO"
            }
        } else {
            Write-Log "Running non-interactively without config. Skipping WinUtil." "INFO"
        }
    }

    Write-StepEnd "PASO 2 - TWEAKS, DEBLOAT Y CONFIGURACION DE WINGET"
    Pause-If-Interactive
}

function Install-IDEExtensions {
    Write-Log "--- INSTALLING IDE EXTENSIONS ---" "HEADER"
    $ExtJson = Join-Path $ScriptDir "extensions.json"
    if (-not (Test-Path $ExtJson)) {
        Write-Log "extensions.json not found. Skipping extensions installation." "WARN"
        return
    }

    try {
        $ExtList = Get-Content $ExtJson -Raw | ConvertFrom-Json
    } catch {
        Write-Log "Failed to parse extensions.json: $_" "ERROR"
        return
    }

    $agyCmdPath  = Join-Path $env:LOCALAPPDATA "Programs\Antigravity IDE\bin\antigravity-ide.cmd"
    $codeCmdPath = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"

    $IdeCmd = $null
    if (Test-Command "antigravity-ide") {
        $IdeCmd = "antigravity-ide"
    } elseif (Test-Path -LiteralPath $agyCmdPath -ErrorAction SilentlyContinue) {
        $IdeCmd = $agyCmdPath
    } elseif (Test-Command "code") {
        $IdeCmd = "code"
    } elseif (Test-Path -LiteralPath $codeCmdPath -ErrorAction SilentlyContinue) {
        $IdeCmd = $codeCmdPath
    }

    if (-not $IdeCmd) {
        Write-Log "Neither Antigravity IDE nor VS Code CLI found. Skipping extensions installation." "WARN"
        return
    }

    Write-Host "`nFound editor CLI: $IdeCmd" -ForegroundColor Cyan
    $ExtCount = $ExtList.Count
    $Current = 0
    foreach ($Ext in $ExtList) {
        $Current++
        $ExtId = if ($Ext -is [string]) { $Ext.Trim() } else { $Ext.id.Trim() }
        Write-Host "[$Current/$ExtCount] Installing extension: $ExtId" -ForegroundColor Cyan
        try {
            $Proc = Start-Process -FilePath $IdeCmd -ArgumentList "--install-extension $ExtId" -NoNewWindow -Wait -PassThru
            if ($Proc.ExitCode -eq 0) {
                Write-Log "Extension installed/ready: $ExtId" "SUCCESS" -Console $false
                Write-Host "  [OK] Installed/Ready" -ForegroundColor Green
            } else {
                Write-Log "Failed to install extension: $ExtId (Code: $($Proc.ExitCode))" "WARN"
                Write-Host "  [WARN] Failed" -ForegroundColor Yellow
            }
        } catch {
            Write-Log "Error installing extension ${ExtId}: $_" "ERROR"
            Write-Host "  [ERROR] $_" -ForegroundColor Red
        }
    }
    Sync-PowerShellErrors -Context "Install-IDEExtensions"
    Write-Log "IDE Extensions installation complete." "SUCCESS"
}

function Configure-TaskbarLayout {
    Write-Log "Configuring Windows 11 Taskbar layout (hiding Task View, removing Edge/Store/Outlook, pinning Chrome)..." "INFO"
    $errBefore = $Error.Count
    try {
        # 1. Ocultar boton de Vista de Tareas (Task View) y Widgets en la barra de tareas
        $AdvKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if (Test-Path $AdvKey) {
            Set-ItemProperty -Path $AdvKey -Name "ShowTaskViewButton" -Type DWord -Value 0 -ErrorAction SilentlyContinue
        }

        # 2. Asegurar desinstalacion de Outlook (New) por si seguia anclado
        Get-AppxPackage -Name "*OutlookForWindows*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

        # 3. Preparar carpeta User Pinned\TaskBar con SOLO File Explorer.lnk y Google Chrome.lnk
        $PinnedDir = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
        if (-not (Test-Path -LiteralPath $PinnedDir)) {
            New-Item -Path $PinnedDir -ItemType Directory -Force | Out-Null
        }

        # Eliminar accesos directos no deseados (Microsoft Edge, etc.)
        Get-ChildItem -LiteralPath $PinnedDir -Filter "*.lnk" -Force -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -ne "File Explorer.lnk" -and $_.Name -ne "Google Chrome.lnk"
        } | Remove-Item -Force -ErrorAction SilentlyContinue

        # Asegurar File Explorer.lnk
        $feLnk = Join-Path $PinnedDir "File Explorer.lnk"
        if (-not (Test-Path -LiteralPath $feLnk)) {
            $feB64 = "TAAAAAEUAgAAAAAAwAAAAAAAAEbFAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAABYAFAAfgNhfIFL7XX1EgBrQtS8ug+EAACkAQAAlAFMAeQBzAHQAZQBtAFIAbwBvAHQAJQBcAHMAeQBzAHQAZQBtADMAMgBcAFMAaABlAGwAbAAzADIALgBkAGwAbAAsAC0AMgAyADUANwA5ABUAJQB3AGkAbgBkAGkAcgAlAFwAZQB4AHAAbABvAHIAZQByAC4AZQB4AGUArwAAAAkAAKAtAAAAMVNQU+KKWEa8TDhDu/wTkyaYbc4RAAAAAAAAAAATAAAAAAAAAAAAAAB2AAAAMVNQU1UoTJ95nzlLqNDh1C3h1fNJAAAABQAAAAAfAAAAGwAAAE0AaQBjAHIAbwBzAG8AZgB0AC4AVwBpAG4AZABvAHcAcwAuAEUAeABwAGwAbwByAGUAcgAAAAAAEQAAABIAAAAAEwAAAAEAAAAAAAAAAAAAAAAAAAA="
            [System.IO.File]::WriteAllBytes($feLnk, [Convert]::FromBase64String($feB64))
        }

        # Copiar Google Chrome.lnk desde el Menu Inicio (con su AppUserModelID 'Chrome')
        $chromeDestLnk = Join-Path $PinnedDir "Google Chrome.lnk"
        $chromeStartCandidates = @(
            "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk",
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk",
            "C:\Users\Public\Desktop\Google Chrome.lnk"
        )
        $copiedChromeLnk = $false
        foreach ($cand in $chromeStartCandidates) {
            if (Test-Path -LiteralPath $cand -ErrorAction SilentlyContinue) {
                Copy-Item -LiteralPath $cand -Destination $chromeDestLnk -Force -ErrorAction SilentlyContinue
                $copiedChromeLnk = $true
                break
            }
        }
        if (-not $copiedChromeLnk -and (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
            $wsh = New-Object -ComObject WScript.Shell
            $sc = $wsh.CreateShortcut($chromeDestLnk)
            $sc.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
            $sc.Save()
        }

        # 4. Detener Explorer brevemente para que no sobrescriba Taskband al cerrarse, escribir el layout limpio y relanzarlo
        $tbKey  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        $auxKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins"
        $favB64 = "AKADAAA6AB9JRxoDWXI/p0SJxVWV/msw7iYAAQAmAO++EAAAAAXVBNdvxNsBbwgV7H8/3AEbD47yfz/cARQAggB0ABwAQ0ZTRhYAMQAAAAAArlrrCxIAQXBwRGF0YQAAAHQaWV6W39NIjWcXM7zuKLrFzfrfn2dWQYlHxcdrwLZ/QAAJAAQA776uWt0LUVuEfC4AAAAIlyIAAAALAAAAAAAAAAAAAAAAAAAAnsrmAEEAcABwAEQAYQB0AGEAAABCAFYAMQAAAAAAPlsSsBAAUm9hbWluZwBAAAkABADvvq5a3QtRW0Z9LgAAAAmXIgAAAAsAAAAAAAAAAAAAAAAAAADc6nEAUgBvAGEAbQBpAG4AZwAAABYAXAAxAAAAAACuWicMFABNSUNST1N+MQAARAAJAAQA776uWt0LUVuJey4AAAAKlyIAAAALAAAAAAAAAAAAAAAAAAAAg2IPAE0AaQBjAHIAbwBzAG8AZgB0AAAAGABsADEAAAAAAK5aKgwQAElOVEVSTn4xAABUAAkABADvvsVWiGlRW3t8LgAAABqXIgAAAAsAAAAAAAAAAAAAAAAAAADocBkASQBuAHQAZQByAG4AZQB0ACAARQB4AHAAbABvAHIAZQByAAAAGABiADEAAAAAAEhbNn4RAFFVSUNLTH4xAABKAAkABADvvsVWiGlRW8CALgAAABuXIgAAAAsAAAAAAAAAAAAAAAAAAABBjKsAUQB1AGkAYwBrACAATABhAHUAbgBjAGgAAAAYAGAAMQAAAAAArlouDBIAVVNFUlBJfjEAAEgACQAEAO++xVbVaVFbOmkuAAAAvqEiAAAACwAAAAAAAAAAAAAAAAAAAL2SGgBVAHMAZQByACAAUABpAG4AbgBlAGQAAAAYAFYAMQAAAAAAAAAAABAAVGFza0JhcgBAAAkABADvvgAAAAAAAAAALgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVABhAHMAawBCAGEAcgAAABYArAAyAK4FAABRWwOBIABHT09HTEV+MS5MTksAAFQACQAEAO++xVaFbFFbA4EuAAAAUJEAAAAAEQAAAAAAAAAAAAAAAAAAABfuAAFHAG8AbwBnAGwAZQAgAEMAaAByAG8AbQBlAC4AbABuAGsAAAAcABoAAAAdAO++AgBDAGgAcgBvAG0AZQAAABwAIgAAAB4A774CAFUAcwBlAHIAUABpAG4AbgBlAGQAAAAcAAAAAKQBAAA6AB+AyCc0HxBcEEKqAy7kUofWaCYAAQAmAO++EgAAAFZsya+vl9kBHht+2q+X2QGSSYXar5fZARQAVgAxAAAAAADFVvtpEQBUYXNrQmFyAEAACQAEAO++xVb7acVW+2kuAAAAFLUBAAAAAQAAAAAAAAAAAAAAAAAAAG4X3wBUAGEAcwBrAEIAYQByAAAAFgASATIAlwEAAKdUZiogAEZJTEVFWH4xLkxOSwAAfAAJAAQA777FVvtpxVb7aS4AAAAWtQEAAAABAAAAAAAAAAAAUgAAAAAApBOiAEYAaQBsAGUAIABFAHgAcABsAG8AcgBlAHIALgBsAG4AawAAAEAAcwBoAGUAbABsADMAMgAuAGQAbABsACwALQAyADIAMAA2ADcAAAAcABIAAAArAO++kkmF2q+X2QEcAEIAAAAdAO++AgBNAGkAYwByAG8AcwBvAGYAdAAuAFcAaQBuAGQAbwB3AHMALgBFAHgAcABsAG8AcgBlAHIAAAAcACYAAAAeAO++AgBTAHkAcwB0AGUAbQBQAGkAbgBuAGUAZAAAABwAAAD/"
        $favBytes = [Convert]::FromBase64String($favB64)

        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800

        if (-not (Test-Path $tbKey)) { New-Item -Path $tbKey -Force | Out-Null }
        if (Get-ItemProperty -Path $tbKey -Name "FavoritesResolve" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $tbKey -Name "FavoritesResolve" -ErrorAction SilentlyContinue
        }
        Set-ItemProperty -Path $tbKey -Name "Favorites" -Type Binary -Value $favBytes -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tbKey -Name "FavoritesVersion" -Type DWord -Value 3 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tbKey -Name "FavoritesChanges" -Type DWord -Value 20 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tbKey -Name "FavoritesRemovedChanges" -Type DWord -Value 61 -ErrorAction SilentlyContinue

        if (-not (Test-Path $auxKey)) { New-Item -Path $auxKey -Force | Out-Null }
        Set-ItemProperty -Path $auxKey -Name "MailPin" -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $auxKey -Name "CopilotPWAPin" -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $auxKey -Name "TFLPin" -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $auxKey -Name "RecallPin" -Type DWord -Value 1 -ErrorAction SilentlyContinue

        if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
            Start-Process "explorer.exe"
        }
        Write-Log "Taskbar layout configured successfully (File Explorer + Google Chrome)." "SUCCESS"
    } catch {
        Write-Log "Could not fully configure Taskbar layout: $_" "WARN"
        if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
            Start-Process "explorer.exe"
        }
    }
    while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
}

function Install-Software {
    Write-StepStart "PASO 3 - INSTALACION DE SOFTWARE ($global:ProfileName)"
    Assert-Internet -MaxRetries 6 -WaitSeconds 5

    if (-not (Test-Path $global:InstallJson)) {
        Write-Log "Config file not found: $global:InstallJson" "ERROR"
        Write-StepEnd "PASO 3 - INSTALACION DE SOFTWARE ($global:ProfileName)"
        Pause-If-Interactive
        return
    }

    Update-SessionEnvironment
    if (-not (Test-Command "winget")) {
        Write-Log "Winget command not found. Please run Step 2 first." "ERROR"
        Write-StepEnd "PASO 3 - INSTALACION DE SOFTWARE ($global:ProfileName)"
        Pause-If-Interactive
        return
    }

    Write-Host "Refreshing Winget sources..." -ForegroundColor Cyan
    Configure-WingetSettings
    Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait

    $RawJson = Get-Content $global:InstallJson -Raw | ConvertFrom-Json
    $Packages = if ($RawJson.Sources -and $RawJson.Sources[0].Packages) { 
        $RawJson.Sources[0].Packages 
    } else { 
        $RawJson 
    }
    $Total = $Packages.Count
    $Current = 0

    $FailedPkgs = @()
    $InstalledPkgs = @()

    foreach ($pkg in $Packages) {
        $Current++
        $Id = if ($pkg.PackageIdentifier) { $pkg.PackageIdentifier } elseif ($pkg.id) { $pkg.id } else { $pkg }
        $Name = if ($pkg.name) { $pkg.name } else { $Id }

        Write-Host "`n[$Current/$Total] Checking/Installing $Name ($Id)..." -ForegroundColor Cyan
        
        $SourceOpt = if ($Id -match '^[A-Z0-9]{12,14}$') { "--source msstore" } else { "--source winget" }
        $Args = "install --id `"$Id`" --exact $SourceOpt --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
        
        $MaxRetries = 2
        $Attempt = 0
        $Success = $false
        $LastExitCode = -1

        while ($Attempt -lt $MaxRetries -and -not $Success) {
            $Attempt++
            if ($Attempt -gt 1) {
                Write-Host "  Retrying installation (Attempt $Attempt of $MaxRetries)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }

            $Process = Start-Process -FilePath "winget" -ArgumentList $Args -NoNewWindow -Wait -PassThru
            $LastExitCode = $Process.ExitCode

            if ($LastExitCode -eq 0 -or $LastExitCode -eq 3010 -or $LastExitCode -eq -1978335189 -or $LastExitCode -eq -1978335135) {
                $Success = $true
            } elseif ($LastExitCode -eq -1978335215 -and $SourceOpt -ne "") {
                Write-Log "Package $Id not found in $SourceOpt. Retrying without source filter..." "WARN"
                $SourceOpt = ""
                $Args = "install --id `"$Id`" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
            } elseif ($LastExitCode -eq -1978335227) {
                Write-Log "Network error downloading $Name ($Id). Retrying..." "WARN"
            }
        }

        if ($Success) {
            $Desc = Get-WingetErrorDescription $LastExitCode
            Write-Log "$Name ($Id): $Desc." "SUCCESS"
            Write-Host "  [OK] $Name ($Desc)" -ForegroundColor Green
            $InstalledPkgs += $Name
        } else {
            $Desc = Get-WingetErrorDescription $LastExitCode
            Write-Log "Failed to install $Name ($Id): $Desc (Exit code $LastExitCode)" "ERROR"
            Write-Host "  [FAIL] ${Name}: $Desc" -ForegroundColor Red
            $FailedPkgs += "$Name ($Id)"
        }
    }

    Update-SessionEnvironment

    # Install IDE extensions if Antigravity IDE or VS Code was installed
    Install-IDEExtensions

    # Configurar la Barra de Tareas (ocultar Vista de Tareas, quitar Edge/Store/Outlook y anclar Chrome + Explorador)
    Configure-TaskbarLayout

    Write-Log "Software installation finished. Installed: $($InstalledPkgs.Count), Failed: $($FailedPkgs.Count)" "INFO"
    if ($FailedPkgs.Count -gt 0) {
        Write-Host "`nThe following packages failed to install:" -ForegroundColor Red
        foreach ($f in $FailedPkgs) {
            Write-Host " - $f" -ForegroundColor Red
        }
    }

    Write-StepEnd "PASO 3 - INSTALACION DE SOFTWARE ($global:ProfileName)"
    Pause-If-Interactive
}

function Sync-Repositories {
    Write-StepStart "PASO 4 - CLONACION DE REPOSITORIOS ($global:ProfileName)"
    Assert-Internet -MaxRetries 6 -WaitSeconds 5

    Update-SessionEnvironment

    if (-not (Test-Command "git")) {
        Write-Log "Git command not found in PATH. Skipping repository sync." "ERROR"
        Write-Host "Git no esta disponible en el entorno actual." -ForegroundColor Red
        Write-StepEnd "PASO 4 - CLONACION DE REPOSITORIOS ($global:ProfileName)"
        Pause-If-Interactive
        return
    }

    if (-not (Test-Path $global:ReposJson)) {
        Write-Log "Repos config file not found: $global:ReposJson" "WARN"
        Write-StepEnd "PASO 4 - CLONACION DE REPOSITORIOS ($global:ProfileName)"
        Pause-If-Interactive
        return
    }

    # Desactivar cualquier popup grafico de Git Credential Manager (GCM)
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "never"
    git config --global credential.helper store 2>$null
    git config --global credential.interactive never 2>$null

    # Verificar credenciales de GitHub antes de clonar
    Check-GitToken

    if (-not (Test-Path $RepoDestDir)) {
        Write-Log "Creating repositories folder: $RepoDestDir" "INFO"
        New-Item -Path $RepoDestDir -ItemType Directory -Force | Out-Null
    }

    $RawRepos = Get-Content $global:ReposJson -Raw | ConvertFrom-Json
    $Repos = if ($RawRepos.repositories) { $RawRepos.repositories } else { $RawRepos }
    $Total = @($Repos).Count
    $Current = 0

    foreach ($repo in $Repos) {
        $Current++
        $Url = $repo.url
        $Folder = if ($repo.name) { $repo.name } elseif ($repo.folder) { $repo.folder } else { Split-Path $Url -LeafBase }
        $TargetDir = Join-Path $RepoDestDir $Folder

        Write-Host "`n[$Current/$Total] Checking repository: $Folder..." -ForegroundColor Cyan

        $AuthUrl = $Url
        if ($repo.private -and $global:GitHubToken -and $global:GitHubUser) {
            $AuthUrl = $Url -replace 'https://', "https://$($global:GitHubUser):$($global:GitHubToken)@"
        }
        $GitNoPopupArgs = "-c credential.helper=`"`" -c credential.helper=store -c credential.interactive=never -c core.askPass=`"`" -c core.longpaths=true -c http.postBuffer=524288000 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60"

        if (Test-Path (Join-Path $TargetDir ".git")) {
            Write-Host "  Repository exists. Updating (git pull)..." -ForegroundColor Yellow
            Write-Log "Pulling latest changes for $Folder..." "INFO" -Console $false
            
            if ($AuthUrl -ne $Url) {
                Start-Process -FilePath "git" -ArgumentList "-C `"$TargetDir`" remote set-url origin `"$AuthUrl`"" -NoNewWindow -Wait | Out-Null
            }
            $PullProcess = Start-Process -FilePath "git" -ArgumentList "$GitNoPopupArgs -C `"$TargetDir`" pull --rebase" -NoNewWindow -Wait -PassThru
            if ($AuthUrl -ne $Url) {
                Start-Process -FilePath "git" -ArgumentList "-C `"$TargetDir`" remote set-url origin `"$Url`"" -NoNewWindow -Wait | Out-Null
            }

            if ($PullProcess.ExitCode -eq 0) {
                Write-Log "Repository $Folder updated successfully." "SUCCESS"
                Write-Host "  [OK] Pulled successfully." -ForegroundColor Green
            } else {
                Write-Log "Failed to pull repository $Folder (Exit code: $($PullProcess.ExitCode))" "WARN"
                Write-Host "  [WARN] Pull failed. Check local changes or network." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Cloning repository..." -ForegroundColor Yellow
            Write-Log "Cloning $Url to $TargetDir..." "INFO" -Console $false

            $CloneSuccess = $false
            $errCode = -1
            $lastGitErr = ""
            for ($attempt = 1; $attempt -le 3; $attempt++) {
                if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
                if ($attempt -gt 1) {
                    Write-Host "  Reintentando clonacion de $Folder (Intento $attempt/3)..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                }
                $gitErrFile = Join-Path $env:TEMP "git_clone_err_$PID.txt"
                if (Test-Path $gitErrFile) { Remove-Item $gitErrFile -Force -ErrorAction SilentlyContinue }
                $CloneProcess = Start-Process -FilePath "git" -ArgumentList "$GitNoPopupArgs clone `"$AuthUrl`" `"$TargetDir`"" -NoNewWindow -Wait -PassThru -RedirectStandardError $gitErrFile
                $errCode = $CloneProcess.ExitCode
                if (Test-Path $gitErrFile) {
                    $rawErr = (Get-Content $gitErrFile -Raw -ErrorAction SilentlyContinue)
                    if ($rawErr) {
                        # Ocultar token en caso de que aparezca en la URL dentro del mensaje de error
                        $lastGitErr = ($rawErr -replace 'https://[^@]+@', 'https://***@').Trim()
                    }
                    Remove-Item $gitErrFile -Force -ErrorAction SilentlyContinue
                }
                if ($errCode -eq 0) {
                    $CloneSuccess = $true
                    break
                } else {
                    Write-Log "Clone attempt $attempt/3 for $Folder exited with code $errCode. Details: $lastGitErr" "WARN" -Console $false
                }
            }

            if ($CloneSuccess) {
                if ($AuthUrl -ne $Url) {
                    Start-Process -FilePath "git" -ArgumentList "-C `"$TargetDir`" remote set-url origin `"$Url`"" -NoNewWindow -Wait | Out-Null
                }
                Write-Log "Repository $Folder cloned successfully." "SUCCESS"
                Write-Host "  [OK] Cloned successfully." -ForegroundColor Green
            } else {
                $detailMsg = if ($lastGitErr) { " | Git: $lastGitErr" } else { "" }
                Write-Log "Failed to clone repository $Folder from $Url (Exit code: $errCode)$detailMsg" "ERROR"
                Write-Host "  [ERROR] Clone failed with exit code $errCode$detailMsg" -ForegroundColor Red
            }
        }
    }

    Write-StepEnd "PASO 4 - CLONACION DE REPOSITORIOS ($global:ProfileName)"
    Pause-If-Interactive
}

function Open-ManualLinks {
    Write-StepStart "PASO 4 - ENLACES DE DESCARGA MANUAL ($global:ProfileName)"

    if (-not (Test-Path $global:LinksJson)) {
        Write-Log "Links config file not found: $global:LinksJson" "WARN"
        Write-StepEnd "PASO 4 - ENLACES DE DESCARGA MANUAL ($global:ProfileName)"
        Pause-If-Interactive
        return
    }

    $Links = Get-Content $global:LinksJson -Raw | ConvertFrom-Json
    if (-not $Links -or $Links.Count -eq 0) {
        Write-Log "No hay enlaces en $global:LinksJson." "INFO"
        Write-StepEnd "PASO 4 - ENLACES DE DESCARGA MANUAL ($global:ProfileName)"
        Pause-If-Interactive
        return
    }

    # Detectar Google Chrome para abrir los links directamente sin popups de Windows
    $ChromePath = $null
    $CandidatePaths = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($cp in $CandidatePaths) {
        if (Test-Path -LiteralPath $cp -ErrorAction SilentlyContinue) {
            $ChromePath = $cp
            break
        }
    }
    if (-not $ChromePath -and (Test-Command "chrome")) {
        $ChromePath = "chrome"
    }

    # Si es interactivo (Paso 5 manual) y Chrome esta instalado, permitir iniciar sesion en Google antes de abrir las descargas
    if (-not $Script:NonInteractive -and $ChromePath) {
        Write-Host "`n[Aviso Navegador]" -ForegroundColor Cyan
        Write-Host "Se van a abrir $(($Links.Count)) enlaces de descarga manual." -ForegroundColor Yellow
        Write-Host "Deseas abrir Chrome ahora para iniciar sesion con tu cuenta de Google antes de cargar las paginas? (Y/N) [Default: Y]" -ForegroundColor Cyan
        $LoginChoice = Read-Host
        if ($LoginChoice -ne "N" -and $LoginChoice -ne "n") {
            Write-Host "Abriendo Chrome. Inicia sesion o configura tu perfil de Google..." -ForegroundColor Green
            Start-Process -FilePath $ChromePath -ArgumentList "--no-first-run --no-default-browser-check"
            Write-Host "`nCuando hayas iniciado sesion en Chrome, presiona cualquier tecla aqui para abrir las descargas..." -ForegroundColor Yellow
            [void][System.Console]::ReadKey($true)
        }
    }

    Write-Log "Opening $(($Links.Count)) manual download link(s)..." "INFO"

    if ($ChromePath) {
        # Asegurar archivo centinela 'First Run' de Chrome para que no bloquee las pestanas con el asistente de bienvenida en un PC virgen
        try {
            $ChromeUserData = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"
            if (-not (Test-Path $ChromeUserData)) {
                New-Item -Path $ChromeUserData -ItemType Directory -Force | Out-Null
            }
            $FirstRunFile = Join-Path $ChromeUserData "First Run"
            if (-not (Test-Path $FirstRunFile)) {
                New-Item -Path $FirstRunFile -ItemType File -Force | Out-Null
            }
        } catch {}

        $QuotedUrls = @()
        foreach ($item in $Links) {
            $Name = $item.name
            $Url  = $item.url
            Write-Host "Opening: $Name ($Url)" -ForegroundColor Cyan
            Write-Log "Opened manual link: $Name ($Url)" "INFO" -Console $false
            $QuotedUrls += "`"$Url`""
        }

        # Abrir todas las URLs en una sola invocacion de Chrome para evitar que el bloqueo de inicio descarte pestanas
        $ChromeArgs = "--no-first-run --no-default-browser-check --new-window " + ($QuotedUrls -join " ")
        Start-Process -FilePath $ChromePath -ArgumentList $ChromeArgs
    } else {
        foreach ($item in $Links) {
            $Name = $item.name
            $Url  = $item.url
            Write-Host "Opening: $Name ($Url)" -ForegroundColor Cyan
            Write-Log "Opened manual link: $Name ($Url)" "INFO" -Console $false
            Start-Process $Url
            Start-Sleep -Milliseconds 600
        }
    }

    Write-StepEnd "PASO 4 - ENLACES DE DESCARGA MANUAL ($global:ProfileName)"
    Pause-If-Interactive
}

function Pause-If-Interactive {
    if (-not $Script:NonInteractive) {
        Write-Host "`nPresiona cualquier tecla para continuar..." -ForegroundColor Gray
        [void][System.Console]::ReadKey($true)
    }
}

function Show-CompletionDialog {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "PC Inicializador v$global:AppVersion - Finalizado"
        $form.Size = New-Object System.Drawing.Size(480, 250)
        $form.StartPosition = "CenterScreen"
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.TopMost = $true
        $form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)

        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = "COMPLETADO CON EXITO!"
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
        $lblTitle.Size = New-Object System.Drawing.Size(440, 35)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 25)
        $lblTitle.TextAlign = "MiddleCenter"
        $form.Controls.Add($lblTitle)

        $lblMsg = New-Object System.Windows.Forms.Label
        $lblMsg.Text = "Todos los pasos de optimizacion, instalacion de software y repositorios han finalizado correctamente para el perfil $global:ProfileName."
        $lblMsg.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $lblMsg.ForeColor = [System.Drawing.Color]::WhiteSmoke
        $lblMsg.Size = New-Object System.Drawing.Size(420, 50)
        $lblMsg.Location = New-Object System.Drawing.Point(30, 70)
        $lblMsg.TextAlign = "MiddleCenter"
        $form.Controls.Add($lblMsg)

        # Boton Ver Log
        $btnLog = New-Object System.Windows.Forms.Button
        $btnLog.Text = "Ver Log"
        $btnLog.Size = New-Object System.Drawing.Size(130, 38)
        $btnLog.Location = New-Object System.Drawing.Point(85, 145)
        $btnLog.FlatStyle = "Flat"
        $btnLog.BackColor = [System.Drawing.Color]::FromArgb(41, 128, 185)
        $btnLog.ForeColor = [System.Drawing.Color]::White
        $btnLog.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $btnLog.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnLog.Add_Click({
            $TargetLog = if ($global:LogFile -and (Test-Path $global:LogFile)) { $global:LogFile } else { Get-LatestLogFile }
            if ($TargetLog -and (Test-Path $TargetLog)) { Invoke-Item $TargetLog }
        })
        $form.Controls.Add($btnLog)

        # Boton Aceptar
        $btnOk = New-Object System.Windows.Forms.Button
        $btnOk.Text = "Aceptar"
        $btnOk.Size = New-Object System.Drawing.Size(130, 38)
        $btnOk.Location = New-Object System.Drawing.Point(245, 145)
        $btnOk.FlatStyle = "Flat"
        $btnOk.BackColor = [System.Drawing.Color]::FromArgb(39, 174, 96)
        $btnOk.ForeColor = [System.Drawing.Color]::White
        $btnOk.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $btnOk.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnOk.Add_Click({
            $form.Close()
        })
        $form.Controls.Add($btnOk)

        $ErrFile = Get-ErrorLogPath
        $HasErrors = ($ErrFile -and (Test-Path $ErrFile) -and ((Get-Item $ErrFile).Length -gt 0))

        if ($HasErrors) {
            $form.Size = New-Object System.Drawing.Size(530, 250)
            $lblTitle.Text = "FINALIZADO CON AVISOS"
            $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(230, 126, 34)
            $lblMsg.Text = "La instalacion ha finalizado pero se han registrado algunos avisos o errores. Puedes consultarlos en el boton 'Ver Errores'."
            $lblTitle.Size = New-Object System.Drawing.Size(490, 35)
            $lblMsg.Size = New-Object System.Drawing.Size(470, 50)
            $lblMsg.Location = New-Object System.Drawing.Point(30, 70)

            # Ajustar posiciones para 3 botones
            $btnLog.Location = New-Object System.Drawing.Point(35, 145)

            $btnErr = New-Object System.Windows.Forms.Button
            $btnErr.Text = "Ver Errores"
            $btnErr.Size = New-Object System.Drawing.Size(130, 38)
            $btnErr.Location = New-Object System.Drawing.Point(190, 145)
            $btnErr.FlatStyle = "Flat"
            $btnErr.BackColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
            $btnErr.ForeColor = [System.Drawing.Color]::White
            $btnErr.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            $btnErr.Cursor = [System.Windows.Forms.Cursors]::Hand
            $btnErr.Add_Click({
                if (Test-Path $ErrFile) { Invoke-Item $ErrFile }
            })
            $form.Controls.Add($btnErr)

            $btnOk.Location = New-Object System.Drawing.Point(345, 145)
        }

        [void]$form.ShowDialog()
    } catch {
        Write-Log "Could not display GUI dialog: $_" "WARN"
        Write-Host "`n================================================================" -ForegroundColor Green
        Write-Host "                    COMPLETADO CON EXITO!                       " -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
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
        [int]$NextStep,
        [string]$LogFile = $global:LogFile
    )
    $State = @{
        Profile       = $Profile
        Step          = $NextStep
        LogFile       = $LogFile
        GitHubUser    = $global:GitHubUser
        GitHubToken   = $global:GitHubToken
        KeepAutoLogon = [bool]$global:KeepAutoLogon
    }
    if (Test-Path $StateFile) {
        (Get-Item $StateFile -Force).Attributes = "Normal"
    }
    $State | ConvertTo-Json | Set-Content $StateFile -Force
    (Get-Item $StateFile -Force).Attributes = "Hidden"
}

function Remove-SetupState {
    if (Test-Path $StateFile -ErrorAction SilentlyContinue) {
        Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    }
}

function Enable-AutoLogon {
    param (
        [string]$Username = $env:USERNAME,
        [string]$Password = ""
    )
    
    $WinLogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    
    # 1. Asegurar que Windows Hello / PIN no bloquee el AutoLogon en Windows 10/11
    $PasswordLessKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
    if (Test-Path $PasswordLessKey) {
        Set-ItemProperty -Path $PasswordLessKey -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }

    # 2. Desactivar pantalla de bloqueo (Lock Screen) para pasar directamente al escritorio
    $PersKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    if (-not (Test-Path $PersKey)) { New-Item -Path $PersKey -Force | Out-Null }
    Set-ItemProperty -Path $PersKey -Name "NoLockScreen" -Value 1 -Type DWord -ErrorAction SilentlyContinue

    # 3. Configurar credenciales y forzar AutoLogon directo
    Set-ItemProperty -Path $WinLogonKey -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $WinLogonKey -Name "ForceAutoLogon" -Value "1" -Type String
    Set-ItemProperty -Path $WinLogonKey -Name "DefaultUserName" -Value $Username -Type String
    Set-ItemProperty -Path $WinLogonKey -Name "DefaultDomainName" -Value $env:USERDOMAIN -Type String
    
    # Windows exige que DefaultPassword exista (aunque sea vacio) para omitir la pantalla de inicio de sesion
    if (-not [string]::IsNullOrEmpty($Password)) {
        Set-ItemProperty -Path $WinLogonKey -Name "DefaultPassword" -Value $Password -Type String
    } else {
        Set-ItemProperty -Path $WinLogonKey -Name "DefaultPassword" -Value "" -Type String
    }

    # 4. Asegurar que no se exija pulsar Ctrl+Alt+Supr ni confirmaciones
    $SysPolKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (Test-Path $SysPolKey) {
        Set-ItemProperty -Path $SysPolKey -Name "DisableCAD" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $SysPolKey -Name "dontdisplaylastusername" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }

    Write-Log "Auto-Logon configurado y pantalla de bloqueo desactivada para el usuario '$Username'." "SUCCESS"
}

function Disable-AutoLogon {
    $errBefore = $Error.Count
    $WinLogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $WinLogonKey -Name "AutoAdminLogon" -Value "0" -Type String
    if (Get-ItemProperty -Path $WinLogonKey -Name "ForceAutoLogon" -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $WinLogonKey -Name "ForceAutoLogon" -ErrorAction SilentlyContinue
    }
    if (Get-ItemProperty -Path $WinLogonKey -Name "DefaultPassword" -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $WinLogonKey -Name "DefaultPassword" -ErrorAction SilentlyContinue
    }
    
    # Restaurar pantalla de bloqueo
    $PersKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    if (Get-ItemProperty -Path $PersKey -Name "NoLockScreen" -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $PersKey -Name "NoLockScreen" -ErrorAction SilentlyContinue
    }
    while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
    Write-Log "Auto-Logon de Windows desactivado y credenciales limpiadas." "INFO"
}

function Set-RegistryAutoRun {
    $LauncherPath = Join-Path $RootDir "Run-Setup.bat"
    
    # 1. Tarea programada con privilegios maximos (omite ventana UAC completamente tras el reinicio)
    $TaskCmd = "schtasks /Create /TN `"$RegName`" /TR `"`"$LauncherPath`"`" /SC ONLOGON /RL HIGHEST /F"
    cmd.exe /c $TaskCmd 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Tarea programada de autoarranque elevada ($RegName) registrada con exito." "INFO"
    } else {
        # Fallback al registro clasico si schtasks devuelve error
        Set-ItemProperty -Path $RegPath -Name $RegName -Value "`"$LauncherPath`"" -ErrorAction SilentlyContinue
        Write-Log "Autoarranque registrado en HKCU Run (fallback)." "INFO"
    }
}

function Remove-RegistryAutoRun {
    $errBefore = $Error.Count
    try {
        cmd.exe /c "schtasks /Delete /TN `"$RegName`" /F" 2>$null | Out-Null
    } catch {}
    if (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue
    }
    while ($Error.Count -gt $errBefore) { $Error.RemoveAt(0) }
}

function Resume-AutoSequence {
    param ([PSCustomObject]$State)
    $Script:NonInteractive = $true
    
    $global:ProfileName = $State.Profile
    $global:Suffix = if ($global:ProfileName -eq "OMAR" -or $global:ProfileName -eq "CONTROL") { "omar" } else { "designer_basico" }
    
    # Restaurar credenciales de GitHub y preferencia de AutoLogon validadas en el Paso 0
    if ($State.GitHubUser -and $State.GitHubToken) {
        $global:GitHubUser  = $State.GitHubUser
        $global:GitHubToken = $State.GitHubToken
    }
    if ($null -ne $State.KeepAutoLogon) {
        $global:KeepAutoLogon = [bool]$State.KeepAutoLogon
    }

    # Reload Profile Context
    $global:InstallJson = Join-Path $ScriptDir "install_$global:Suffix.json"
    $global:ReposJson   = Join-Path $ScriptDir "repos_$global:Suffix.json"
    $global:LinksJson   = Join-Path $ScriptDir "links_$global:Suffix.json"
    
    # Restaurar archivo de log de esta maquina
    if ($State.LogFile) {
        $global:LogFile = $State.LogFile
    } else {
        Initialize-RunLog -Tag "ALL"
    }
    
    Write-Log "REANUDANDO SECUENCIA AUTOMATICA (v$global:AppVersion) | PERFIL: $global:ProfileName | PASO: $($State.Step)" "HEADER"
    Write-Log "LOG: $global:LogFile" "INFO"
    Start-Sleep -Seconds 2
    
    # Verificar conexion tras reinicio antes de arrancar el siguiente paso
    Assert-Internet -MaxRetries 8 -WaitSeconds 5
    
    switch ($State.Step) {
        1 {
            Install-WindowsUpdates
            Save-SetupState -Profile $global:ProfileName -NextStep 2 -LogFile $global:LogFile
            Write-Log "Paso 1 completado. Reiniciando equipo en 3 segundos..." "WARN"
            Start-Sleep -Seconds 3
            Restart-Computer -Force
            exit
        }
        2 {
            Invoke-WinUtilTweaks
            Save-SetupState -Profile $global:ProfileName -NextStep 3 -LogFile $global:LogFile
            Write-Log "Paso 2 completado. Reiniciando equipo en 3 segundos..." "WARN"
            Start-Sleep -Seconds 3
            Restart-Computer -Force
            exit
        }
        3 {
            Install-Software
            Save-SetupState -Profile $global:ProfileName -NextStep 4 -LogFile $global:LogFile
            Write-Log "Paso 3 completado. Reiniciando equipo en 3 segundos..." "WARN"
            Start-Sleep -Seconds 3
            Restart-Computer -Force
            exit
        }
        4 {
            Sync-Repositories
            Open-ManualLinks
            Remove-RegistryAutoRun
            if ($global:KeepAutoLogon) {
                Write-Log "Auto-Logon mantenido activo permanentemente por eleccion del usuario." "INFO"
            } else {
                Disable-AutoLogon
            }
            Remove-SetupState
            Sync-PowerShellErrors -Context "Final"
            Write-Log "SECUENCIA AUTOMATICA COMPLETADA CON EXITO" "STEP_DONE"
            Write-Host "`nALL STEPS FINISHED SUCCESSFULLY." -ForegroundColor Green
            Show-CompletionDialog
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
    if ($State.LogFile) {
        $global:LogFile = $State.LogFile
    }
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " SECUENCIA PREVIA DETECTADA (SIGUIENTE: PASO $($State.Step))" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "Perfil guardado: $($State.Profile)" -ForegroundColor Gray
    Write-Host "Archivo de log:  $($State.LogFile)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Reanudando automaticamente en 4 segundos..." -ForegroundColor Yellow
    Write-Host "Si deseas CANCELAR y volver al menu inicial, pulsa 'C' ahora." -ForegroundColor Yellow
    Write-Host ""
    
    $Cancel = $false
    for ($i = 4; $i -gt 0; $i--) {
        Write-Host -NoNewline "`rReanudando en $i segundo(s)... [Pulsa 'C' para cancelar] "
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'c' -or $key.KeyChar -eq 'C') {
                $Cancel = $true
                break
            }
        }
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    
    if ($Cancel) {
        Write-Host "`n[CANCELADO] Secuencia previa descartada. Iniciando desde cero..." -ForegroundColor Green
        $global:LogFile = $null
        Remove-SetupState
        Remove-RegistryAutoRun
        Disable-AutoLogon
        Start-Sleep -Seconds 1
    } else {
        Resume-AutoSequence -State $State
    }
}

# 2. PROFILE CONFIGURATION
if ($Profile -eq "2" -or $Profile -eq "OMAR") {
    $global:ProfileName = "OMAR"
    $global:Suffix = "omar"
} elseif ($Profile -eq "1" -or $Profile -eq "DESIGNER BASICO" -or $Profile -eq "DESIGNER_BASICO") {
    $global:ProfileName = "DESIGNER BASICO"
    $global:Suffix = "designer_basico"
} elseif ($Step) {
    $global:ProfileName = "DESIGNER BASICO"
    $global:Suffix = "designer_basico"
} else {
    Select-Profile
}

$global:InstallJson = Join-Path $ScriptDir "install_$global:Suffix.json"
$global:ReposJson   = Join-Path $ScriptDir "repos_$global:Suffix.json"
$global:LinksJson   = Join-Path $ScriptDir "links_$global:Suffix.json"

if ($Step) {
    # Non-interactive CLI mode
    $Script:NonInteractive = $true
    switch ($Step) {
        "1" { 
            Initialize-RunLog -Tag "winupdate"
            Install-WindowsUpdates 
        }
        "2" { 
            Initialize-RunLog -Tag "tweaks"
            Invoke-WinUtilTweaks 
        }
        "3" { 
            Initialize-RunLog -Tag "install"
            Install-Software 
        }
        "4" { 
            Initialize-RunLog -Tag "repos"
            Sync-Repositories 
        }
        "5" { 
            Initialize-RunLog -Tag "links"
            Open-ManualLinks 
        }
        "ALL" { 
            Initialize-RunLog -Tag "ALL"
            Install-WindowsUpdates
            Invoke-WinUtilTweaks
            Install-Software
            Sync-Repositories
            Open-ManualLinks
            Show-CompletionDialog
        }
    }
    exit
}

# 3. INTERACTIVE MENU
$Script:NonInteractive = $false

do {
    Show-Header
    Write-Host "1. Windows Updates (Paso 1)"
    Write-Host "2. Windows Tweaks, Debloat & Winget Setup (Paso 2)"
    Write-Host "3. Install Software ($global:ProfileName) (Paso 3)"
    Write-Host "4. Sync Repositories ($global:ProfileName) (Paso 4)"
    Write-Host "5. Open Manual Downloads ($global:ProfileName)"
    Write-Host "6. Execute ALL Steps (Secuencia Automatica con reinicios)"
    Write-Host "7. View Log"
    Write-Host "8. Restart PC"
    Write-Host "Q. Quit"
    Write-Host ""
    $Selection = Read-Host "Elige una opcion"

    switch ($Selection) {
        "1" { 
            Initialize-RunLog -Tag "winupdate"
            Install-WindowsUpdates 
        }
        "2" { 
            Initialize-RunLog -Tag "tweaks"
            Invoke-WinUtilTweaks 
        }
        "3" { 
            Initialize-RunLog -Tag "install"
            Install-Software 
        }
        "4" { 
            Initialize-RunLog -Tag "repos"
            Sync-Repositories 
        }
        "5" { 
            Initialize-RunLog -Tag "links"
            Open-ManualLinks 
        }
        "6" { 
            $Script:NonInteractive = $true
            Write-Host "`n[Modo Secuencia Automatica]" -ForegroundColor Cyan
            $Reboot = Read-Host "Deseas REINICIAR entre cada paso? (Recomendado para instalaciones limpias) Y/N [Default: Y]"
            
            # Inicializar el archivo de log unico para toda la secuencia antes de pedir credenciales
            Initialize-RunLog -Tag "ALL"
            
            if ($Reboot -ne "N" -and $Reboot -ne "n") {
                Check-GitToken
                
                # Preguntar contrasena de Windows para AutoLogon (iniciar sesion sin pantalla de login)
                Write-Host "`nPara que Windows inicie sesion solo tras cada reinicio sin pedir PIN ni contrasena:" -ForegroundColor Gray
                $HasPass = Read-Host "Tu cuenta de Windows ($env:USERNAME) tiene contrasena? (Y/N) [Default: N]"
                $UserPass = ""
                if ($HasPass -eq "Y" -or $HasPass -eq "y") {
                    $SecurePass = Read-Host -Prompt "Introduce la contrasena de Windows (se ocultara)" -AsSecureString
                    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
                    $UserPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                }
                
                $KeepAL = Read-Host "Deseas MANTENER el inicio de sesion automatico (Auto-Logon) activo permanentemente al terminar todo el proceso? (Y/N) [Default: N]"
                $global:KeepAutoLogon = ($KeepAL -eq "Y" -or $KeepAL -eq "y")
                
                Write-Host "Configurando inicio de sesion automatico (AutoLogon)..." -ForegroundColor Yellow
                Enable-AutoLogon -Username $env:USERNAME -Password $UserPass
                if ($global:KeepAutoLogon) {
                    Write-Log "Preferencia de Auto-Logon al finalizar: MANTENER ACTIVO permanentemente." "INFO"
                } else {
                    Write-Log "Preferencia de Auto-Logon al finalizar: DESACTIVAR al terminar el proceso." "INFO"
                }
                
                Write-Log "INICIALIZANDO SECUENCIA AUTOMATICA (ALL) v$global:AppVersion - $global:ProfileName" "HEADER"
                Write-Log "MAQUINA: $env:COMPUTERNAME | FECHA: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
                Write-Log "LOG: $global:LogFile" "INFO"
                
                Write-Host "Configurando tarea programada de inicio automatico tras reinicio..." -ForegroundColor Yellow
                Set-RegistryAutoRun
                Save-SetupState -Profile $global:ProfileName -NextStep 1 -LogFile $global:LogFile
                
                # Iniciar directamente el Paso 1
                $InitialState = [PSCustomObject]@{
                    Profile       = $global:ProfileName
                    Step          = 1
                    LogFile       = $global:LogFile
                    GitHubUser    = $global:GitHubUser
                    GitHubToken   = $global:GitHubToken
                    KeepAutoLogon = $global:KeepAutoLogon
                }
                Resume-AutoSequence -State $InitialState
            } else {
                # Ejecucion secuencial sin reinicios
                Check-GitToken
                Write-Log "INICIALIZANDO EJECUCION SECUENCIAL SIN REINICIOS (ALL) v$global:AppVersion - $global:ProfileName" "HEADER"
                Install-WindowsUpdates
                Invoke-WinUtilTweaks
                Install-Software
                Sync-Repositories
                Open-ManualLinks
                Show-CompletionDialog
            }
        }
        "7" { 
            $TargetLog = if ($global:LogFile -and (Test-Path $global:LogFile)) { $global:LogFile } else { Get-LatestLogFile }
            if ($TargetLog -and (Test-Path $TargetLog)) {
                Write-Host "Abriendo archivo de log: $TargetLog" -ForegroundColor Cyan
                Invoke-Item $TargetLog
            } else {
                Write-Host "No se ha encontrado ningun archivo de log en $global:LogDir" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
        "8" { 
            $Ans = Read-Host "Reiniciar PC ahora? (Y/N) [Default: Y]"
            if ($Ans -ne "N" -and $Ans -ne "n") { Restart-Computer -Force }
        }
        "Q" { exit }
        default { Write-Host "Opcion invalida" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($true)
