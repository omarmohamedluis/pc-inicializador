# Requires Administrator privileges
$ErrorActionPreference = 'Stop'

$vhdPath = "C:\USB_Virtual.vhdx"
if (-not (Test-Path $vhdPath)) {
    Write-Host "[ERROR] No se encuentra el archivo $vhdPath" -ForegroundColor Red
    return
}

# 1. Buscar la maquina virtual
$vm = Get-VM | Where-Object { $_.Name -match "inicializador" }
if (-not $vm) {
    Write-Host "[ERROR] No se encontro la maquina virtual de Hyper-V ('pc inicializador')." -ForegroundColor Red
    return
}

# 2. Comprobar si el disco esta conectado a la VM
$hddInVM = Get-VMHardDiskDrive -VM $vm | Where-Object { $_.Path -like "*USB_Virtual.vhdx*" }

# 3. Comprobar si esta montado en el Host
$diskImg = Get-DiskImage -ImagePath $vhdPath

if ($hddInVM) {
    # --- ESTA EN LA VM -> PASAR AL HOST ---
    Write-Host "`n[FLIP] Detectado en la MAQUINA VIRTUAL." -ForegroundColor Cyan
    Write-Host "  -> Desconectando de la VM..." -ForegroundColor Yellow
    $hddInVM | Remove-VMHardDiskDrive
    Start-Sleep -Seconds 1
    
    Write-Host "  -> Montando en el Host fisico..." -ForegroundColor Yellow
    Mount-DiskImage -ImagePath $vhdPath | Out-Null
    Start-Sleep -Seconds 1
    
    $part = Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | Where-Object DriveLetter | Select-Object -First 1
    $drive = $part.DriveLetter + ":"
    Write-Host "`n>>> [LISTO EN HOST] El USB Virtual ahora esta disponible en tu PC fisico en la unidad: $drive <<<" -ForegroundColor Green
}
else {
    # --- ESTA EN EL HOST (O SUELTO) -> PASAR A LA VM ---
    Write-Host "`n[FLIP] Detectado en el HOST (o desconectado)." -ForegroundColor Cyan
    if ($diskImg.Attached) {
        Write-Host "  -> Desmontando del Host fisico..." -ForegroundColor Yellow
        Dismount-DiskImage -ImagePath $vhdPath | Out-Null
        Start-Sleep -Seconds 1
    }
    
    Write-Host "  -> Conectando a la VM '$($vm.Name)' en caliente..." -ForegroundColor Yellow
    Add-VMHardDiskDrive -VM $vm -Path $vhdPath
    Write-Host "`n>>> [LISTO EN VM] El USB Virtual ahora esta conectado dentro de tu Maquina Virtual! <<<" -ForegroundColor Green
}
