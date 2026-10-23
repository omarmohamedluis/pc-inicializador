# PC Inicializador - Automatización de instalación para Windows

Una suite automatizada basada en **PowerShell** y **Batch** para inicializar un PC con Windows 10/11 limpio desde cero, optimizando el sistema operativo, instalando software esencial y clonando repositorios privados de GitHub de forma desatendida.

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

## 🔄 Fases de la Secuencia de Instalación (Opción 6 - ALL)

El inicializador divide el proceso en 4 etapas con soporte de **Auto-Logon** y **Tarea Programada elevada (`HIGHEST`)** para reiniciar entre pasos sin pedir contraseña de Windows ni confirmación UAC:

1. **Paso 0 (Preparación Inicial):**
   - Valida o descifra tu token de GitHub (`src/github_token.enc` o `src/github_token.txt`) una única vez al principio y lo persiste para el Paso 4.
   - Configura temporalmente el Auto-Logon de Windows para los reinicios intermedios.
2. **Paso 1: Windows Updates:**
   - Busca e instala actualizaciones de Windows con `PSWindowsUpdate` (utilizando el flag `-IgnoreReboot` para un control total del ciclo de reinicio).
3. **Paso 2: Windows Tweaks, Debloat & Winget Setup (WinUtil):**
   - Configura y refresca las fuentes de Winget y añade el bypass de certificados Store.
   - Aplica las directivas recomendadas de Chris Titus (modo *Solo Seguridad*): bloquea drivers por Windows Update, aplaza updates mayores 365 días y parches de calidad 4 días, y desactiva reinicios automáticos con usuarios conectados.
   - Ejecuta CTT WinUtil en modo silencioso (*headless*) aplicando tu configuración de `src/winutil_config.json` (descargando desde el release oficial de GitHub con respaldo offline automático en `src/winutil.ps1`).
4. **Paso 3: Instalar Software & Extensiones:**
   - Instala las aplicaciones de Winget definidas en `install_<perfil>.json`.
   - Instala automáticamente las extensiones de Antigravity IDE / VS Code definidas en `src/extensions.json`.
5. **Paso 4: Repositorios Git + Enlaces Manuales + Fin:**
   - Clona o actualiza los repositorios de GitHub en el Escritorio (`%USERPROFILE%\Desktop\repositorios`) de forma 100% silenciosa (sin popups de *Git Credential Manager*).
   - Abre en Google Chrome las páginas de descargas manuales (permitiendo iniciar sesión en Google previamente).
   - Limpia las credenciales de Auto-Logon y la tarea de autoarranque, y muestra la ventana gráfica de finalización con botones directos para **"Ver Log"** y **"Ver Errores"** (si hubo algún aviso).

---

## 🔐 Repositorios Privados y GitHub Token (PAT)

Puedes preconfigurar tu token en el USB ejecutando `helpers\Configurar-Token-GitHub.bat` (que invoca `src\Set-GitHubToken.ps1`):
- **Opción 1 (Recomendada - Cifrado AES-256):** Genera `src/github_token.enc` protegido con una contraseña maestra corta que solo tendrás que introducir en el Paso 0.
- **Opción 2 (Texto plano 100% silencioso):** Genera `src/github_token.txt` para no hacer ninguna pregunta.

---

## 🛠️ Estructura del Proyecto

```text
pc-inicializador/
├── Run-Setup.bat                       (Lanzador principal con elevación UAC)
├── README.MD                           (Documentación del sistema)
├── .gitignore                          (Ignora logs/, estados y tokens)
├── logs/                               (Registros detallados y logs de errores por sesión)
├── helpers/
│   ├── Configurar-Token-GitHub.bat     (Asistente para cifrar el PAT de GitHub en el USB)
│   ├── Flip-USB-Virtual.bat / .ps1     (Conmutador en caliente del VHDX entre Host y VM Hyper-V)
│   ├── USB_VIRTUAL.md                  (Guía del disco virtual USB en Hyper-V)
│   ├── REACTIVATE.todo                 (Lista maestra de elementos a reactivar para producción)
│   └── TODO                            (Historial de tareas y mejoras)
└── src/
    ├── Setup-PC.ps1                    (Motor orquestador principal de PowerShell)
    ├── Set-GitHubToken.ps1             (Cifrador AES-256 del token de GitHub)
    ├── winutil.ps1                     (Copia local de respaldo de CTT WinUtil)
    ├── extensions.json                 (Lista común de extensiones de IDE)
    ├── winutil_config.json / .full.json(Configuración de tweaks de Windows)
    ├── install_omar.json / .full.json  (Apps Winget - Perfil Omar)
    ├── install_designer_basico.json    (Apps Winget - Perfil Designer)
    ├── repos_omar.json / .full.json    (Repos Git - Perfil Omar)
    ├── repos_designer_basico.json      (Repos Git - Perfil Designer)
    ├── links_omar.json                 (Links manuales - Perfil Omar)
    └── links_designer_basico.json      (Links manuales - Perfil Designer)
```
