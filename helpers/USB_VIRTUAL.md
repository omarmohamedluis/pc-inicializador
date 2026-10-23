# Guía de Uso: USB Virtual (.VHDX) en Hyper-V

Esta guía explica cómo transferir archivos y logs entre tu equipo físico (Host) y tu máquina virtual Hyper-V (`pc inicializador`) sin necesidad de activar el modo de sesión mejorada, sin configurar carpetas compartidas de red (SMB) y sin apagar la máquina virtual.

---

## ⚡ Concepto Clave: Hot-Plug SCSI
Tu máquina virtual es de **Generación 2** con controladora **SCSI**. Esto permite **conectar y desconectar discos duros virtuales (.vhdx) en caliente**, es decir, mientras la máquina virtual está funcionando.

> [!IMPORTANT]
> **Regla de oro:** Un archivo `.vhdx` no puede estar montado al mismo tiempo en el Host y en la VM (el sistema de archivos NTFS se bloquea por seguridad). El flujo consiste en alternarlo entre uno y otro según lo necesites.

---

## 🛠️ Paso 1: Crear y Formatear el USB Virtual (Solo se hace una vez)

Abre **PowerShell como Administrador** en tu equipo físico y ejecuta:

```powershell
# 1. Crear el disco virtual dinamico de 10 GB (solo ocupara en tu disco fisico lo que guardes)
New-VHD -Path "C:\USB_Virtual.vhdx" -SizeBytes 10GB -Dynamic

# 2. Montarlo en tu Windows
$disk = Mount-VHD -Path "C:\USB_Virtual.vhdx" -PassThru

# 3. Inicializar particion GPT y formatear en NTFS con la etiqueta 'USB_Virtual'
$disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "USB_Virtual"
```

Se abrirá una nueva unidad en tu Explorador de Archivos (por ejemplo `D:\` o `E:\`). 
Copia dentro de ella la carpeta de tu repositorio o los archivos que quieras pasar a la VM.

---

## 🚀 Paso 2: Conectar el USB Virtual a la Máquina Virtual

Una vez hayas copiado los archivos en la unidad virtual desde tu Host:

```powershell
# 1. Desmontar del Host fisico
Dismount-VHD -Path "C:\USB_Virtual.vhdx"

# 2. Conectar a la VM en caliente (sin reiniciarla ni apagarla)
$vm = Get-VM | Where-Object { $_.Name -like "*pc inicializador*" }
Add-VMHardDiskDrive -VM $vm -Path "C:\USB_Virtual.vhdx"
```

**Resultado:** En 1 o 2 segundos, dentro de la máquina virtual aparecerá la nueva unidad en el Explorador de Archivos con todos tus instaladores y scripts listos para usar.

---

## 📥 Paso 3: Traer el USB Virtual de vuelta al Host (Leer Logs)

Cuando la máquina virtual haya terminado de ejecutar y quieras inspeccionar los logs generados:

```powershell
# 1. Desconectar de la VM en caliente
$vm = Get-VM | Where-Object { $_.Name -like "*pc inicializador*" }
Get-VMHardDiskDrive -VM $vm | Where-Object { $_.Path -like "*USB_Virtual.vhdx*" } | Remove-VMHardDiskDrive

# 2. Montar de nuevo en tu Windows fisico
Mount-VHD -Path "C:\USB_Virtual.vhdx"
```

**Resultado:** La unidad volverá a abrirse en tu Windows real. Podrás entrar a la carpeta `logs/` y abrir los archivos generados directamente con tu editor o bloc de notas.

---

## 💡 Scripts Rápidos (Opcional)

Si deseas alternar con un solo clic sin escribir comandos, puedes guardar estos dos scripts en tu equipo:

### `Pasar-a-VM.ps1`
```powershell
Dismount-VHD -Path "C:\USB_Virtual.vhdx" -ErrorAction SilentlyContinue
$vm = Get-VM | Where-Object { $_.Name -like "*pc inicializador*" }
Add-VMHardDiskDrive -VM $vm -Path "C:\USB_Virtual.vhdx"
Write-Host "USB Virtual conectado a la VM con exito." -ForegroundColor Green
```

### `Traer-a-Host.ps1`
```powershell
$vm = Get-VM | Where-Object { $_.Name -like "*pc inicializador*" }
Get-VMHardDiskDrive -VM $vm | Where-Object { $_.Path -like "*USB_Virtual.vhdx*" } | Remove-VMHardDiskDrive -ErrorAction SilentlyContinue
Mount-VHD -Path "C:\USB_Virtual.vhdx"
Write-Host "USB Virtual montado en el Host con exito." -ForegroundColor Green
```
