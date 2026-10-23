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
$global:TestingMode_SkipWindowsUpdate = $true

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

# Inicializar variable global de log
$global:LogFile = $null

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

function Write-StepStart {
    param ([string]$StepName)
    Write-Log "$StepName INICIADO" "HEADER"
}

function Write-StepEnd {
    param ([string]$StepName)
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
    return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
}

function Update-SessionEnvironment {
    try {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $userPath    = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        $env:Path    = "$machinePath;$userPath"

        $gitDirs = @(
            "C:\Program Files\Git\cmd",
            "C:\Program Files\Gitin",
            "$env:LOCALAPPDATA\Programs\Git\cmd"
        )
        foreach ($gd in $gitDirs) {
            if ((Test-Path $gd) -and ($env:Path -notlike "*$gd*")) {
                $env:Path = "$gd;$env:Path"
            }
        }
    } catch {}
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
    try {
        $req = [System.Net.WebRequest]::Create("https://www.google.com")
        $req.Timeout = 3000
        $resp = $req.GetResponse()
        $resp.Close()
        return $true
    } catch {}

    if (Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        return $true
    }
    if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        return $true
    }

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

    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
            "User-Agent"    = "PowerShell-PCInitializer"
        }
        $resp = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get -TimeoutSec 8 -ErrorAction Stop
        if ($resp -and $resp.login) {
            return $resp.login
        }
    } catch {}
    return $null
}

function Check-GitToken {
    Write-Log "Checking GitHub credentials..." "INFO" -Console $false
    
    if (-not (Wait-ForInternet -MaxRetries 4 -WaitSeconds 5)) {
        Write-Host "`nNo hay internet, intentelo con internet." -ForegroundColor Red
        return
    }

    $CredFile = Join-Path $env:USERPROFILE ".git-credentials"
    $TokenTxt = Join-Path $ScriptDir "github_token.txt"
    $TokenEnc = Join-Path $ScriptDir "github_token.enc"

    # PRIORIDAD 1: Token en texto plano en el USB (github_token.txt) -> 100% automatico y silencioso
    if (Test-Path $TokenTxt) {
        $RawToken = (Get-Content $TokenTxt -Raw -ErrorAction SilentlyContinue).Trim()
        if (-not [string]::IsNullOrWhiteSpace($RawToken)) {
            Write-Host "Detectado archivo de token local en USB (github_token.txt)..." -ForegroundColor Cyan
            $ghUser = Test-GitHubToken -Token $RawToken
            if ($ghUser) {
                Write-Log "Token de GitHub cargado automaticamente desde $TokenTxt (Usuario: $ghUser)." "SUCCESS"
                Write-Host "GitHub autenticado automaticamente como: $ghUser" -ForegroundColor Green
                git config --global credential.helper store
                "https://${RawToken}:x-oauth-basic@github.com" | Out-File -FilePath $CredFile -Append -Encoding ascii
                $env:GITHUB_TOKEN = $RawToken
                [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", $RawToken, [EnvironmentVariableTarget]::User)
                return
            } else {
                Write-Log "El token en $TokenTxt fue rechazado por la API de GitHub." "WARN"
                Write-Host "[AVISO] El token en github_token.txt no es valido o caduco." -ForegroundColor Yellow
            }
        }
    }

    # PRIORIDAD 2: Token cifrado en el USB (github_token.enc) -> Pide contrasena maestra
    if (Test-Path $TokenEnc) {
        $Cipher = (Get-Content $TokenEnc -Raw -ErrorAction SilentlyContinue).Trim()
        if (-not [string]::IsNullOrWhiteSpace($Cipher)) {
            Write-Host "`n========================================================" -ForegroundColor Cyan
            Write-Host " [SEGURIDAD] Token de GitHub cifrado detectado en el USB" -ForegroundColor Cyan
            Write-Host "========================================================" -ForegroundColor Cyan
            $Attempts = 0
            while ($Attempts -lt 3) {
                $Attempts++
                $PassSecure = Read-Host -Prompt "Introduce tu contrasena maestra de GitHub (Intento $Attempts/3)" -AsSecureString
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassSecure)
                $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                
                $Decrypted = Unprotect-SecretAES -Base64Cipher $Cipher -Password $Password
                if ($Decrypted) {
                    $ghUser = Test-GitHubToken -Token $Decrypted
                    if ($ghUser) {
                        Write-Log "Token de GitHub descifrado y validado con exito para el usuario '$ghUser'." "SUCCESS"
                        Write-Host "Token descifrado correctamente! Conectado como: $ghUser" -ForegroundColor Green
                        git config --global credential.helper store
                        "https://${Decrypted}:x-oauth-basic@github.com" | Out-File -FilePath $CredFile -Append -Encoding ascii
                        $env:GITHUB_TOKEN = $Decrypted
                        [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", $Decrypted, [EnvironmentVariableTarget]::User)
                        return
                    }
                }
                Write-Host "Contrasena maestra incorrecta o token invalido." -ForegroundColor Red
            }
            Write-Log "Fallo al descifrar el token de GitHub tras 3 intentos con contrasena." "WARN"
            Write-Host "No se pudo descifrar el token del USB tras 3 intentos." -ForegroundColor Yellow
        }
    }

    # PRIORIDAD 3: Credenciales existentes en el sistema ($env:GITHUB_TOKEN o ~/.git-credentials)
    $envToken = $env:GITHUB_TOKEN
    $SavedToken = $null
    if (-not [string]::IsNullOrWhiteSpace($envToken)) {
        $SavedToken = $envToken.Trim()
    } elseif (Test-Path $CredFile) {
        $content = Get-Content $CredFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'https://([^:]+):x-oauth-basic@github\.com') {
            $SavedToken = $matches[1].Trim()
        } elseif ($content -match 'https://[^:]+:([^@]+)@github\.com') {
            $SavedToken = $matches[1].Trim()
        }
    }

    if ($SavedToken) {
        Write-Host "Verificando credenciales de GitHub existentes en el sistema..." -ForegroundColor Cyan
        $ghUser = Test-GitHubToken -Token $SavedToken
        if ($ghUser) {
            Write-Log "Credenciales de GitHub verificadas para el usuario '$ghUser'." "SUCCESS"
            Write-Host "GitHub autenticado correctamente como: $ghUser" -ForegroundColor Green
            return
        } else {
            Write-Log "Las credenciales existentes de GitHub (.git-credentials) no son validas o han expirado." "WARN"
            Write-Host "`n[AVISO] Las credenciales guardadas de GitHub NO son validas o caducaron." -ForegroundColor Yellow
            $Update = Read-Host "Deseas corregir/introducir un nuevo GitHub PAT? (Y/N) [Default: Y]"
            if ($Update -eq "N" -or $Update -eq "n") {
                return
            }
        }
    } else {
        Write-Host "NOTA: Los repositorios privados requieren un Personal Access Token (PAT)." -ForegroundColor Yellow
        $Choice = Read-Host "Quieres introducir un GitHub PAT ahora? (Y/N) [Default: N]"
        if ($Choice -ne "Y" -and $Choice -ne "y") {
            Write-Log "Paso de token de GitHub omitido." "INFO"
            return
        }
    }

    # PRIORIDAD 4: Entrada manual interactiva como fallback
    do {
        $Token = Read-Host -Prompt "Pega tu GitHub PAT (se ocultara)" -AsSecureString
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
            
            git config --global credential.helper store
            $credLine = "https://${PlainToken}:x-oauth-basic@github.com"
            $credLine | Out-File -FilePath $CredFile -Append -Encoding ascii
            
            $env:GITHUB_TOKEN = $PlainToken
            [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", $PlainToken, [EnvironmentVariableTarget]::User)
            Write-Log "Credenciales de GitHub guardadas localmente." "INFO"
            break
        } else {
            Write-Log "El token de GitHub introducido no es valido o fue rechazado por la API." "ERROR"
            Write-Host "`n[ERROR] El token introducido NO es valido (GitHub devolvio error de autenticacion)." -ForegroundColor Red
            $Retry = Read-Host "Quieres volver a intentarlo? (Y/N) [Default: Y]"
            if ($Retry -eq "N" -or $Retry -eq "n") {
                Write-Log "Configuracion de token cancelada tras fallo de validacion." "WARN"
                if (Test-Path $CredFile) {
                    Write-Host "Borrando credenciales no validas..." -ForegroundColor Yellow
                    Remove-Item $CredFile -Force
                }
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

    if (-not (Wait-ForInternet -MaxRetries 4 -WaitSeconds 5)) {
        Write-Log "No se detecta conexion a Internet para buscar actualizaciones." "ERROR"
        Write-StepEnd "PASO 1 - ACTUALIZACIONES DE WINDOWS"
        Pause-If-Interactive
        return
    }

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

function Invoke-WinUtilTweaks {
    Write-StepStart "PASO 2 - TWEAKS, DEBLOAT Y CONFIGURACION DE WINGET"

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
        Write-Host "Applying Windows tweaks in headless mode..." -ForegroundColor Cyan
        try {
            & ([scriptblock]::Create((irm "https://christitus.com/win"))) -Config $ConfigFile
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
                    irm "https://christitus.com/win" | iex
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

    $IdeCmd = $null
    if (Test-Command "antigravity-ide") {
        $IdeCmd = "antigravity-ide"
    } elseif (Test-Path "$env:LOCALAPPDATA\Programs\Antigravity IDEinntigravity-ide.cmd") {
        $IdeCmd = "$env:LOCALAPPDATA\Programs\Antigravity IDEinntigravity-ide.cmd"
    } elseif (Test-Command "code") {
        $IdeCmd = "code"
    } elseif (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Codein\code.cmd") {
        $IdeCmd = "$env:LOCALAPPDATA\Programs\Microsoft VS Codein\code.cmd"
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
    Write-Log "IDE Extensions installation complete." "SUCCESS"
}

function Install-Software {
    Write-StepStart "PASO 3 - INSTALACION DE SOFTWARE ($global:ProfileName)"

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

    # Verificar credenciales de GitHub antes de clonar
    Check-GitToken

    if (-not (Test-Path $RepoDestDir)) {
        Write-Log "Creating repositories folder: $RepoDestDir" "INFO"
        New-Item -Path $RepoDestDir -ItemType Directory -Force | Out-Null
    }

    $Repos = Get-Content $global:ReposJson -Raw | ConvertFrom-Json
    $Total = $Repos.Count
    $Current = 0

    foreach ($repo in $Repos) {
        $Current++
        $Url = $repo.url
        $Folder = $repo.folder
        $TargetDir = Join-Path $RepoDestDir $Folder

        Write-Host "`n[$Current/$Total] Checking repository: $Folder..." -ForegroundColor Cyan

        if (Test-Path (Join-Path $TargetDir ".git")) {
            Write-Host "  Repository exists. Updating (git pull)..." -ForegroundColor Yellow
            Write-Log "Pulling latest changes for $Folder..." "INFO" -Console $false
            
            $PullProcess = Start-Process -FilePath "git" -ArgumentList "-C `"$TargetDir`" pull --rebase" -NoNewWindow -Wait -PassThru
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

            $CloneProcess = Start-Process -FilePath "git" -ArgumentList "clone $Url `"$TargetDir`"" -NoNewWindow -Wait -PassThru
            if ($CloneProcess.ExitCode -eq 0) {
                Write-Log "Repository $Folder cloned successfully." "SUCCESS"
                Write-Host "  [OK] Cloned successfully." -ForegroundColor Green
            } else {
                Write-Log "Failed to clone repository $Folder (Exit code: $($CloneProcess.ExitCode))" "ERROR"
                Write-Host "  [FAIL] Clone failed. Check token / repository permissions." -ForegroundColor Red
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
        if (Test-Path $cp) {
            $ChromePath = $cp
            break
        }
    }
    if (-not $ChromePath -and (Test-Command "chrome")) {
        $ChromePath = "chrome"
    }

    # Si es interactivo y Chrome esta instalado, permitir iniciar sesion en Google antes de abrir las descargas
    if (-not $Script:NonInteractive -and $ChromePath) {
        Write-Host "`n[Aviso Navegador]" -ForegroundColor Cyan
        Write-Host "Se van a abrir $(($Links.Count)) enlaces de descarga manual." -ForegroundColor Yellow
        Write-Host "Deseas abrir Chrome ahora para iniciar sesion con tu cuenta de Google antes de cargar las paginas? (Y/N) [Default: Y]" -ForegroundColor Cyan
        $LoginChoice = Read-Host
        if ($LoginChoice -ne "N" -and $LoginChoice -ne "n") {
            Write-Host "Abriendo Chrome. Inicia sesion o configura tu perfil de Google..." -ForegroundColor Green
            Start-Process -FilePath $ChromePath
            Write-Host "`nCuando hayas iniciado sesion en Chrome, presiona cualquier tecla aqui para abrir las descargas..." -ForegroundColor Yellow
            [void][System.Console]::ReadKey($true)
        }
    }

    Write-Log "Opening $(($Links.Count)) manual download link(s)..." "INFO"

    foreach ($item in $Links) {
        $Name = $item.name
        $Url = $item.url

        Write-Host "Opening: $Name ($Url)" -ForegroundColor Cyan
        Write-Log "Opened manual link: $Name ($Url)" "INFO" -Console $false

        if ($ChromePath) {
            Start-Process -FilePath $ChromePath -ArgumentList "`"$Url`""
        } else {
            Start-Process $Url
        }
        Start-Sleep -Milliseconds 600
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
        Profile = $Profile
        Step    = $NextStep
        LogFile = $LogFile
    }
    $State | ConvertTo-Json | Set-Content $StateFile -Force
    (Get-Item $StateFile).Attributes = "Hidden"
}

function Remove-SetupState {
    if (Test-Path $StateFile) { Remove-Item $StateFile -Force }
}

function Set-RegistryAutoRun {
    $LauncherPath = Join-Path $RootDir "Run-Setup.bat"
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
    $global:Suffix = if ($global:ProfileName -eq "OMAR" -or $global:ProfileName -eq "CONTROL") { "omar" } else { "designer_basico" }
    
    # Reload Profile Context
    $global:InstallJson = Join-Path $ScriptDir "install_$global:Suffix.json"
    $global:ReposJson   = Join-Path $ScriptDir "repos_$global:Suffix.json"
    $global:LinksJson   = Join-Path $ScriptDir "links_$global:Suffix.json"
    
    # Restaurar archivo de log de esta maquina
    if ($State.LogFile) {
        $global:LogFile = $State.LogFile
    } else {
        $global:LogFile = New-RunLogFile -Tag "ALL"
    }
    
    Write-Log "================================================================" "HEADER"
    Write-Log "REANUDANDO SECUENCIA AUTOMATICA (v$global:AppVersion)" "HEADER"
    Write-Log "PERFIL: $global:ProfileName | SIGUIENTE PASO: $($State.Step)" "HEADER"
    Write-Log "LOG: $global:LogFile" "HEADER"
    Write-Log "================================================================" "HEADER"
    Start-Sleep -Seconds 2
    
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
            Remove-SetupState
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
Write-Log "PowerShell security protocols initialized: $([Net.ServicePointManager]::SecurityProtocol)" "INFO" -Console $false

# 1. CHECK FOR RESUME STATE
$State = Get-SetupState
if ($State) {
    Resume-AutoSequence -State $State
} else {
    Log-SystemInfo
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
            $global:LogFile = New-RunLogFile -Tag "winupdate"
            Install-WindowsUpdates 
        }
        "2" { 
            $global:LogFile = New-RunLogFile -Tag "tweaks"
            Invoke-WinUtilTweaks 
        }
        "3" { 
            $global:LogFile = New-RunLogFile -Tag "install"
            Install-Software 
        }
        "4" { 
            $global:LogFile = New-RunLogFile -Tag "repos"
            Sync-Repositories 
        }
        "5" { 
            $global:LogFile = New-RunLogFile -Tag "links"
            Open-ManualLinks 
        }
        "ALL" { 
            $global:LogFile = New-RunLogFile -Tag "ALL"
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
            $global:LogFile = New-RunLogFile -Tag "winupdate"
            Install-WindowsUpdates 
        }
        "2" { 
            $global:LogFile = New-RunLogFile -Tag "tweaks"
            Invoke-WinUtilTweaks 
        }
        "3" { 
            $global:LogFile = New-RunLogFile -Tag "install"
            Install-Software 
        }
        "4" { 
            $global:LogFile = New-RunLogFile -Tag "repos"
            Sync-Repositories 
        }
        "5" { 
            $global:LogFile = New-RunLogFile -Tag "links"
            Open-ManualLinks 
        }
        "6" { 
            Write-Host "`n[Modo Secuencia Automatica]" -ForegroundColor Cyan
            $Reboot = Read-Host "Deseas REINICIAR entre cada paso? (Recomendado para instalaciones limpias) Y/N [Default: Y]"
            
            if ($Reboot -ne "N" -and $Reboot -ne "n") {
                Check-GitToken
                
                # Generar archivo de log dedicado para todo el proceso completo (ALL)
                $global:LogFile = New-RunLogFile -Tag "ALL"
                Write-Log "INICIALIZANDO SECUENCIA AUTOMATICA (ALL) v$global:AppVersion - $global:ProfileName" "HEADER"
                Write-Log "MAQUINA: $env:COMPUTERNAME | FECHA: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
                Write-Log "LOG: $global:LogFile" "INFO"
                
                Write-Host "Configurando inicio automatico tras reinicio..." -ForegroundColor Yellow
                Set-RegistryAutoRun
                Save-SetupState -Profile $global:ProfileName -NextStep 1 -LogFile $global:LogFile
                
                # Iniciar directamente el Paso 1
                $InitialState = [PSCustomObject]@{
                    Profile = $global:ProfileName
                    Step    = 1
                    LogFile = $global:LogFile
                }
                Resume-AutoSequence -State $InitialState
            } else {
                # Ejecucion secuencial sin reinicios
                Check-GitToken
                $global:LogFile = New-RunLogFile -Tag "ALL"
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
