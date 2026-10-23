<#
.SYNOPSIS
    Guarda y cifra tu GitHub Personal Access Token (PAT) en el USB.
.DESCRIPTION
    Permite guardar el token en formato cifrado AES-256 (protegido por contrasena)
    o en texto plano (para automatizacion 100% sin preguntas).
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Configurar Token de GitHub (USB)"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$TokenEnc  = Join-Path $ScriptDir "github_token.enc"
$TokenTxt  = Join-Path $ScriptDir "github_token.txt"

function Protect-SecretAES {
    param([string]$PlainText, [string]$Password)
    $Salt = New-Object byte[] 16
    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $Rng.GetBytes($Salt)
    
    $DeriveBytes = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, 10000)
    $Key = $DeriveBytes.GetBytes(32)
    $IV = $DeriveBytes.GetBytes(16)
    
    $Aes = [System.Security.Cryptography.Aes]::Create()
    $Aes.Key = $Key
    $Aes.IV = $IV
    
    $Encryptor = $Aes.CreateEncryptor()
    $PlainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $EncryptedBytes = $Encryptor.TransformFinalBlock($PlainBytes, 0, $PlainBytes.Length)
    
    $Result = New-Object byte[] ($Salt.Length + $EncryptedBytes.Length)
    [Array]::Copy($Salt, 0, $Result, 0, $Salt.Length)
    [Array]::Copy($EncryptedBytes, 0, $Result, $Salt.Length, $EncryptedBytes.Length)
    
    return [Convert]::ToBase64String($Result)
}

function Test-GitHubToken {
    param([string]$Token)
    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
            "User-Agent"    = "PC-Inicializador-TokenSetup"
        }
        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction Stop
        if ($response -and $response.login) {
            return $response.login
        }
    } catch {
        return $null
    }
    return $null
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " CONFIGURACION DEL TOKEN DE GITHUB PARA EL USB" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este asistente guardara tu token de GitHub en el USB para que"
Write-Host "no tengas que escribirlo manualmente en cada nuevo PC."
Write-Host ""

$PlainToken = ""
while ([string]::IsNullOrWhiteSpace($PlainToken)) {
    $TokenSecure = Read-Host -Prompt "Pega tu GitHub PAT (el texto se ocultara)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TokenSecure)
    $PlainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    if ([string]::IsNullOrWhiteSpace($PlainToken)) {
        Write-Host "No has introducido nada. Intentalo de nuevo." -ForegroundColor Yellow
        continue
    }

    Write-Host "`nValidando token con la API de GitHub..." -ForegroundColor Cyan
    $ghUser = Test-GitHubToken -Token $PlainToken
    if ($ghUser) {
        Write-Host "Token valido! Autenticado correctamente como: $ghUser`n" -ForegroundColor Green
    } else {
        Write-Host "El token introducido no es valido o no tiene conexion con GitHub." -ForegroundColor Red
        $Retry = Read-Host "Deseas volver a intentar pegarlo? (Y/N) [Default: Y]"
        if ($Retry -eq "N" -or $Retry -eq "n") {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            return
        }
        $PlainToken = ""
    }
}

Write-Host "Como deseas almacenar el token en el USB?" -ForegroundColor Cyan
Write-Host "1. CIFRADO AES-256 (Recomendado): Protegido con contrasena maestra corta."
Write-Host "2. TEXTO PLANO (100% silencioso): Cero preguntas en el PC nuevo (solo para tokens de solo lectura)."
Write-Host ""
$Choice = Read-Host "Elige una opcion (1 o 2) [Default: 1]"

if ($Choice -eq "2") {
    $PlainToken.Trim() | Out-File -FilePath $TokenTxt -Encoding ascii -Force
    if (Test-Path $TokenEnc) { Remove-Item $TokenEnc -Force }
    Write-Host "`nToken guardado en texto plano en: $TokenTxt" -ForegroundColor Green
    Write-Host "En cualquier PC nuevo se leera automaticamente sin hacer preguntas." -ForegroundColor Green
} else {
    $Password = ""
    while ([string]::IsNullOrWhiteSpace($Password)) {
        $PassSecure = Read-Host -Prompt "Elige una contrasena maestra (la que te pedira en el PC nuevo)" -AsSecureString
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassSecure)
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
        if ([string]::IsNullOrWhiteSpace($Password)) {
            Write-Host "La contrasena no puede estar vacia." -ForegroundColor Yellow
        }
    }
    
    $Encrypted = Protect-SecretAES -PlainText $PlainToken.Trim() -Password $Password
    $Encrypted | Out-File -FilePath $TokenEnc -Encoding ascii -Force
    if (Test-Path $TokenTxt) { Remove-Item $TokenTxt -Force }
    Write-Host "`nToken cifrado con exito en: $TokenEnc" -ForegroundColor Green
    Write-Host "En el PC nuevo solo tendras que introducir esa contrasena maestra." -ForegroundColor Green
}

Write-Host "`nConfiguracion completada con exito." -ForegroundColor Cyan
Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
