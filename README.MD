# PC Inicializador - Automatización de instalación para Windows

Una suite automatizada basada en **PowerShell** para inicializar un PC con Windows limpio, instalando software esencial y clonando repositorios privados de GitHub.

**Flexible y reutilizable:** Añade o quita paquetes y repositorios simplemente editando `install.json` y `repos.json`. No requiere modificar el código.

---

## 📋 Requisitos Previos

Antes de ejecutar, verifica que tu PC cumpla con estos requisitos:

### **Sistema Operativo**
- Windows 10 (versión 1809 o superior) o Windows 11
- Acceso de **administrador** en la máquina

---

## 🚀 Cómo Ejecutar

### **Opción 1: Doble Click (Más fácil)**

1.  Abre la carpeta `pc inicializador`.
2.  Haz doble click en el archivo:
    `Run-Setup.bat`
3.  Te pedirá permisos de administrador automáticamente.

### **Opción 2: PowerShell**

1.  Abre PowerShell como Administrador.
2.  Navega a la carpeta:
    ```powershell
    cd "C:\ruta\al\directorio\pc inicializador"
    ```
3.  Ejecuta el script maestro:
    ```powershell
    .\Setup-PC.ps1
    ```

### **Menú Interactivo**

Al iniciar, el script te preguntará qué **Perfil** deseas usar:
1.  **D3 (Media Server)**: Carga `install_d3.json`.
2.  **CONTROL (Operator)**: Carga `install_control.json`.

Luego verás el menú de acciones:

-   **1. Windows Updates + Winget**: Inicializa el sistema.
-   **2. Instalar Software**: Instala apps de Winget del perfil elegido.
-   **3. Sincronizar Repositorios**: Clona repos del perfil elegido.
-   **4. Open Manual Downloads**: Abre en el navegador todos los links de descarga manual (Drivers, Apps sin Winget) definidos en `links_*.json`.
-   **5. Ejecutar TODO**: Secuencia completa.
-   **7. Restart PC**: Reiniciar el equipo.

---

## 📦 Configuración por Perfiles

Cada perfil tiene sus propios archivos de configuración:

### Perfil D3
-   `install_d3.json`: Apps de Winget (Adobe, Notch, etc).
-   `repos_d3.json`: Repositorios para D3.
-   `links_d3.json`: Links de descarga manual.

### Perfil CONTROL
-   `install_control.json`: Apps de Winget (Companion tools, Node, etc).
-   `repos_control.json`: Repositorios para Control.
-   `links_control.json`: Links de descarga manual (Companion, Lightware, etc).

**Ejemplo de `links_*.json`:**
```json
[
  { "Name": "Bitfocus Companion", "Url": "https://bitfocus.io/companion" },
  { "Name": "Drivers X32", "Url": "..." }
]
```

**Nota sobre Repos Privados:**
Si tienes repositorios privados, el script te pedirá un **GitHub Personal Access Token (PAT)** si no encuentra credenciales guardadas. El token se guardará de forma segura en tus credenciales de Windows/Git.

### ¿Qué es un GitHub Personal Access Token (PAT)?
Es una contraseña segura que permite acceder a repositorios privados sin usar tu contraseña real.

### **Cómo generar un PAT:**

1. Ve a: https://github.com/settings/tokens
2. Click en "Generate new token" -> "Generate new token (classic)"
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

## 🛠️ Estructura del Proyecto

```
pc inicializador/
├── Setup-PC.ps1       (Script principal PowerShell)
├── Run-Setup.bat      (Lanzador fácil)
├── install_d3.json    (Ejemplo config D3)
├── install.log        (Log de ejecución)
└── ... (otros jsons de perfil)
```

## 📝 Logs

Todos los eventos se registran en `install.log`. Si algo falla, revisa este archivo para ver los errores detallados.
