# PC Inicializador - Automatización de instalación para Windows

Una suite automatizada basada en **PowerShell** y **Batch** para inicializar un PC con Windows 10/11 limpio desde cero, optimizando el sistema operativo, instalando software esencial y clonando repositorios privados de GitHub.

**Flexible y modular:** Todo se gestiona mediante perfiles y archivos JSON configurables dentro de la carpeta `src/`. No requiere modificar el código.

---

## 📋 Requisitos Previos

Antes de ejecutar, verifica que tu PC cumpla con estos requisitos:

### **Sistema Operativo**
- Windows 10 (versión 1809 o superior) o Windows 11
- Acceso de **administrador** en la máquina
- Conexión a Internet

---

## 🚀 Cómo Ejecutar

### **Opción 1: Doble Click (Más fácil)**
1. Abre la carpeta `pc-inicializador`.
2. Haz doble click en el archivo:
   `Run-Setup.bat`
3. Te pedirá permisos de administrador automáticamente vía UAC.

### **Opción 2: PowerShell**
1. Abre PowerShell como Administrador.
2. Navega a la carpeta del repositorio:
   ```powershell
   cd "C:\ruta\al\repositorio\pc-inicializador"
   ```
3. Ejecuta el lanzador:
   ```powershell
   .\Run-Setup.bat
   # O directamente el script:
   .\src\Setup-PC.ps1
   ```

---

## 🔄 Fases de la Secuencia de Instalación

El inicializador divide el proceso en 4 grandes etapas:

1. **Paso 1: Windows Updates:**
   - Busca e instala actualizaciones de Windows con `PSWindowsUpdate` (utilizando el flag `-IgnoreReboot` para un control total del ciclo de reinicio).
2. **Paso 2: Windows Tweaks, Debloat & Winget Setup (WinUtil):**
   - Configura y refresca las fuentes de Winget y añade el bypass de certificados Store.
   - Aplica las directivas recomendadas de Chris Titus (modo *Solo Seguridad*): bloquea drivers por Windows Update, aplaza updates mayores 365 días y parches de calidad 4 días para evitar actualizaciones Día-0 defectuosas, y desactiva reinicios automáticos con usuarios conectados.
   - Ejecuta CTT WinUtil en modo silencioso (*headless*) aplicando tu configuración de `src/winutil_config.json` (eliminación de telemetría, Copilot/AI, OneDrive, optimizaciones de explorador, activación de .NET 3.5, etc.).
3. **Paso 3: Instalar Software & Extensiones:**
   - Instala las aplicaciones de Winget definidas en `install_<perfil>.json`.
   - Instala automáticamente las extensiones de Antigravity IDE / VS Code definidas en `src/extensions.json` (Todo+, Python, clangd, etc.).
4. **Paso 4: Repositorios Git + Enlaces Manuales + Fin:**
   - Clona o actualiza los repositorios de GitHub en el Escritorio (`%USERPROFILE%\Desktop\repositorios`).
   - Abre en el navegador predeterminado las páginas de descargas manuales (drivers de audio/red, software propietario sin Winget).
   - Abre la ventana gráfica **"¡COMPLETADO CON ÉXITO!"** con acceso directo para inspeccionar el archivo de log.

---

## 📦 Configuración por Perfiles

Dentro de `src/`, cada perfil tiene sus propios archivos de configuración:

### Perfil Designer Básico
- `src/install_designer_basico.json`: Apps de Winget (Creative Cloud, Antigravity, QuickLook, RaiDrive, etc.).
- `src/repos_designer_basico.json`: Repositorios para Designer Básico (`d3_player`, `windows_tools`, etc.).
- `src/links_designer_basico.json`: Links de descarga manual (Notch LC, Timecode Monitor, FreeFileSync, etc.).

### Perfil Omar
- `src/install_omar.json`: Apps de Winget (Companion, Reaper, Node.js, Python, Packet Sender, NDI, etc.).
- `src/repos_omar.json`: Repositorios para Omar (`omi_reaper_lirycs`, `acciones-reaper`, `agent`, etc.).
- `src/links_omar.json`: Links de descarga manual (Dante Controller, Lightware, Netgear Engage, X32 Edit, etc.).

### Configuraciones Comunes:
- `src/extensions.json`: Extensiones de editor para ambos perfiles.
- `src/winutil_config.json`: Tweaks y debloat de Windows comunes.

---

## 🔐 Repositorios Privados y GitHub Token (PAT)

Si tienes repositorios privados, el script te pedirá un **GitHub Personal Access Token (PAT)** si no encuentra credenciales guardadas en Windows:
- Se almacena de forma segura en: `C:\Users\{Usuario}\.git-credentials` mediante `git config --global credential.helper store`.
- Solo te lo pedirá una vez.

---

## 🛠️ Estructura del Proyecto

```text
pc-inicializador/
├── Run-Setup.bat                  (Lanzador principal con elevación UAC)
├── README.MD                      (Documentación del sistema)
├── TODO                           (Hoja de ruta personal de tareas)
├── .gitignore                     (Ignora install.log y archivos temporales)
├── install.log                    (Registro de eventos generado en ejecución)
└── src/
    ├── Setup-PC.ps1               (Motor orquestador de PowerShell)
    ├── extensions.json            (Lista común de extensiones de IDE)
    ├── winutil_config.json        (Configuración de tweaks de Windows)
    ├── install_omar.json          (Apps Winget - Perfil Omar)
    ├── install_designer_basico.json (Apps Winget - Perfil Designer)
    ├── repos_omar.json            (Repos Git - Perfil Omar)
    ├── repos_designer_basico.json (Repos Git - Perfil Designer)
    ├── links_omar.json            (Links manuales - Perfil Omar)
    └── links_designer_basico.json (Links manuales - Perfil Designer)
```

## 📝 Logs

Todos los eventos se registran en tiempo real en `install.log` en la raíz del proyecto. Si algún paquete o repositorio falla, consulta este archivo para ver el detalle y códigos de error.
