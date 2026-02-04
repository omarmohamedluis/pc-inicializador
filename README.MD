# PC Inicializador - Automatización de instalación limpia en Windows

Una suite automatizada de scripts batch para inicializar un PC con Windows limpio, instalando software esencial y clonando repositorios privados de GitHub.

**Flexible y reutilizable:** Añade o quita paquetes y repositorios simplemente editando `install.json` y `repos.json`. No requiere modificar los scripts.

---

## 📋 Requisitos Previos

Antes de ejecutar el maestro, verifica que tu PC cumpla con estos requisitos:

### **Sistema Operativo**
- Windows 10 (versión 1809 o superior) o Windows 11
- Acceso de **administrador** en la máquina

### **Dependencias Críticas**

#### 1. **Git para Windows**
Necesario para clonar los repositorios privados.

**Verificar si está instalado:**
```powershell
git --version
```

**Si NO está instalado, descárgalo:**
- Ir a: https://git-scm.com/download/win
- Ejecutar el instalador `.exe`
- Seguir los pasos con opciones por defecto
- Reinicia la terminal/PowerShell después de instalar

#### 2. **Winget** (Gestor de paquetes Windows)
Incluido en Windows 11 por defecto. En Windows 10, debe instalarse:

**Verificar si está instalado:**
```powershell
winget --version
```

**Si NO está instalado en Windows 10:**
1. Ir a: https://aka.ms/getwinget
2. Descargar e instalar la **App Installer** desde Microsoft Store
3. O desde PowerShell (como admin):
```powershell
Invoke-WebRequest -Uri https://aka.ms/wingetcli -OutFile winget.msixbundle
Add-AppxPackage -Path winget.msixbundle
```

#### 3. **PowerShell 5.1 o Superior**
Incluido en Windows 10/11. Verificar:
```powershell
$PSVersionTable.PSVersion
```

---

## 🚀 Cómo Ejecutar

### **Opción 1: Línea de Comandos (Recomendado)**

1. Abre **PowerShell como Administrador**
   - Click derecho en el menú Inicio
   - Selecciona "Windows PowerShell (Admin)"

2. Navega al directorio donde descargaste los scripts:
```powershell
cd "C:\ruta\al\directorio\pc inicializador"
```

3. Ejecuta el maestro:
```batch
.\00-maestro.bat
```

### **Opción 2: Explorador de Archivos**

1. Navega a la carpeta `pc inicializador`
2. Click derecho sobre `00-maestro.bat`
3. Selecciona "Ejecutar como administrador"

### **Menú Interactivo con Validación**

El maestro presenta un menú inteligente que:
- ✅ Verifica automáticamente si Git y Winget están instalados
- ✅ Te guía si falta alguna dependencia
- ✅ Permite elegir qué ejecutar:
  - **Opción 1:** Solo Windows Update + Winget
  - **Opción 2:** Solo instalar/actualizar software
  - **Opción 3:** Solo clonar/actualizar repositorios
  - **Opción 4:** Ejecutar todos los pasos
  - **Opción 5:** Ver log de instalación
  - **Opción 0:** Salir

Esto permite **reutilizar el script** en cualquier momento. Por ejemplo, puedes ejecutarlo mensualmente para:
- Instalar nuevos paquetes
- Actualizar Windows
- Clonar/actualizar repositorios privados

---

## 📦 ¿Qué instala?

El sistema ejecuta **3 pasos principais**:

### **Paso 1: Windows Update + Winget Setup**
- Instala/actualiza Windows Update
- Configura winget como gestor de paquetes
- Duración: ~5-15 minutos

### **Paso 2: Instalación de Software**
Instala todos los paquetes desde `install.json` (actualmente **26 paquetes**):
- **Audio/DAW:** Cockos REAPER
- **Desarrollo:** Node.js 22, .NET SDK 8, Git
- **Navegadores:** Google Chrome, Microsoft Edge
- **Herramientas:** Wireshark, FFmpeg, Advanced IP Scanner, Bonjour, NDI Tools
- **Utilidades:** Windows Terminal, VNC Viewer, Raspberry Pi Imager
- **Librerías:** VCRedist (todas las versiones), UI.Xaml, VCLibs, CodeMeter

**Feedback visual:** 
- Muestra el progreso en tiempo real: `[5/26] Instalando Node.js...`
- Output completo de winget visible (sin silenciamiento)
- Indicador de éxito/error para cada paquete

**Flexible:** Añade/quita paquetes directamente en `install.json` sin modificar scripts.

Duración: ~10-30 minutos (depende del ancho de banda)

### **Paso 3: Clonar Repositorios GitHub**
Descarga/actualiza repositorios privados desde `repos.json` (actualmente **5 repositorios**):
- `acciones-reaper`
- `omi_reaper_lirycs`
- `agent`
- `companionconfigs`
- `disguise_omiweb_layer`

**Feedback visual:**
- Muestra progreso: `[2/5] Actualizando: omi_reaper_lirycs`
- Distingue entre clonar (nuevo) y actualizar (existente)
- Indicador de éxito/error para cada repo

**Nota:** Se pedirá un **GitHub Personal Access Token** (PAT)
- Los repos se descargarán a: `C:\Users\{Usuario}\Desktop\repositorios\`

**Flexible:** Añade/quita repositorios directamente en `repos.json` sin modificar scripts.

Duración: ~1-5 minutos

## 📊 Mejoras de Experiencia de Usuario

### **Validación Automática de Dependencias**
- El maestro verifica Git y Winget al inicio
- Te guía automáticamente si algo falta
- Evita errores confusos más adelante

### **Feedback Visual Mejorado**
- Contadores de progreso: `[5/26] Instalando...`
- Separadores visuales claros (===)
- Indicadores de estado: `[OK]`, `[!]`, `[ERROR]`
- Output de winget mostrado en tiempo real (sin silenciamiento)

### **Mejor Manejo de Errores**
- Los scripts validan dependencias ANTES de ejecutar
- Muestra claramente qué falta y cómo solucionarlo
- Distingue entre advertencias y errores críticos

### **Resúmenes Informativos**
- Al final de cada paso: resumen de éxitos/fallos
- Ratio de paquetes instalados/repositorios clonados
- Links al log para revisar detalles

---

A diferencia de scripts desechables, **este sistema está diseñado para reutilizarse indefinidamente**:

### **Modificar Paquetes a Instalar**
Abre `install.json` y busca la sección `"Packages"`:
```json
{
    "PackageIdentifier": "NombrePaquete.ID"
}
```
- **Añadir:** Añade una nueva entrada JSON
- **Quitar:** Elimina la entrada del paquete
- **Actualizar:** Modifica el nombre del paquete

Los scripts leerán automáticamente la nueva lista.

### **Modificar Repositorios a Clonar**
Abre `repos.json` y busca la sección `"repositories"`:
```json
{
    "url": "https://github.com/usuario/repo.git",
    "name": "nombre-local",
    "private": true
}
```
- **Añadir:** Añade un nuevo repositorio
- **Quitar:** Elimina la entrada del repo
- **Actualizar:** Modifica la URL o nombre

Los scripts leerán automáticamente la nueva lista.

### **Casos de Uso Recurrentes**
Puedes ejecutar el maestro mensualmente o cuando necesites:
- ✅ **Windows Updates:** Solo opción 1
- ✅ **Nuevos paquetes:** Modifica `install.json` → Opción 2
- ✅ **Actualizar repos:** Solo opción 3
- ✅ **Mantenimiento completo:** Opción 4 (todos los pasos)

---

### ¿Qué es un GitHub Personal Access Token (PAT)?
Es una contraseña segura que permite acceder a repositorios privados sin usar tu contraseña real.

### **Cómo generar un PAT:**

1. Ve a: https://github.com/settings/tokens
2. Click en "Generate new token" → "Generate new token (classic)"
3. Dale un nombre: `PC Inicializador`
4. Marca estos permisos:
   - ✅ `repo` (acceso a repositorios)
   - ✅ `read:user` (leer información de usuario)
5. Click en "Generate token"
6. **Copia el token** (aparece solo una vez)

### **Usar el token:**
Cuando el script pida el token, pégalo y presiona Enter.
- Requisito mínimo: **20 caracteres**
- Se almacena de forma segura en: `C:\Users\{Usuario}\.git-credentials`

---

## 📊 Archivos Generados

Después de ejecutar `00-maestro.bat`:

| Archivo | Descripción |
|---------|-------------|
| `install.log` | Registro completo de todas las operaciones |
| `C:\Users\{Usuario}\Desktop\repositorios\` | Directorio con los 4 repos clonados |
| `.git-credentials` | Credenciales seguras de Git (en perfil de usuario) |

---

## ⚠️ Notas Importantes

### **Limpieza Manual (Ya No Automática)**
Los scripts **NO se auto-eliminan** para permitir reutilización. Si deseas limpiar después:
```powershell
# Eliminar los scripts
Remove-Item "00-maestro.bat", "01-*.bat", "02-*.bat", "03-*.bat"

# Eliminar el estado
Remove-Item "estado.txt"

# O eliminar todo el directorio
Remove-Item . -Recurse
```

### **Reinicioss Automáticos**
- Windows Update puede requerir uno o más reinicios
- **NO es necesario esperar** el reinicio automático
- Puedes ejecutar de nuevo el maestro en cualquier momento

### **Conexión a Internet**
- Requerida durante toda la ejecución
- Especialmente importante para descargar paquetes de software

### **Tiempo Total Esperado**
- Con conexión de 50+ Mbps: **30-60 minutos**
- Con conexión más lenta: **1-2 horas**

### **En Caso de Errores**
Si un paso falla:
1. Revisa `install.log` (en Desktop) para detalles
2. Corrige el problema (ej: conexión a internet, permisos)
3. **Vuelve a ejecutar `00-maestro.bat`** - los scripts son idempotentes y pueden re-ejecutarse sin problemas

---

## 🛠️ Estructura del Proyecto

```
pc inicializador/
├── 00-maestro.bat                    (Script principal orquestador)
├── 01-windows-update-y-winget.bat    (Windows Update + Winget)
├── 02-instalar-software.bat          (Instalación de 26 paquetes)
├── 03-descargar-repositorios.bat     (Clonar repos privados)
├── install.json                      (Lista de paquetes winget)
├── repos.json                        (Metadata de repositorios)
├── README.MD                         (Este archivo)
└── estado.txt                        (Generado en ejecución - rastreo de progreso)
```

---

## ✅ Validación Post-Instalación

Después de completar la ejecución, verifica:

```powershell
# Verificar software instalado
winget list

# Verificar repositorios descargados
Get-ChildItem $env:USERPROFILE\Desktop\repositorios

# Verificar Token de Git almacenado
cat $env:USERPROFILE\.git-credentials
```

---

## 🔒 Seguridad

- Los scripts **NO** requieren conexión a servidores externos (excepto GitHub y winget)
- Todos los tokens se almacenan **localmente** en `.git-credentials`
- Los scripts son **autoautoLimpiable**: se eliminan a sí mismos después de completar
- Se ejecutan con permisos de **administrador** necesarios solo para instalaciones del sistema

---

## 📝 Logs y Debugging

Todos los eventos se registran en `install.log`:

```
[2026-02-04 10:15:30] === EJECUTANDO PASO 1 ===
[2026-02-04 10:15:35] Instalando PSWindowsUpdate...
[2026-02-04 10:20:15] Windows Update completado
[2026-02-04 10:20:20] === EJECUTANDO PASO 2 ===
...
```

Para revisar el log después:
```powershell
notepad install.log
```

---

## 🤝 Soporte

Si encuentras problemas:
1. **Lee `install.log`** para detalles del error
2. **Verifica requisitos previos** (Git, Winget, admin)
3. **Revisa la conexión a internet**
4. **Ejecuta nuevamente** - el script continuará desde el último paso completado

---

## 📄 Licencia

Scripts de automatización para configuración de PC limpio en Windows.

---

**Última actualización:** Febrero 2026  
**Versión:** 2.0 - Flexible y Reutilizable
