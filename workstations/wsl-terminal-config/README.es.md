# Configuración del Terminal WSL

[![Language: English](https://img.shields.io/badge/Language-English-blue.svg)](README.md)
[![Estado: Verificado](https://img.shields.io/badge/Estado-Verificado-brightgreen.svg)](#verificación-y-pruebas-automatizadas)

Una configuración visual portable y estética para **Windows Terminal + WSL Ubuntu + Zsh**. Proporciona un entorno elegante con la paleta de colores **Catppuccin Mocha** y un prompt minimalista de Starship en dos líneas (directorio actual, rama y estado de Git, y carácter de entrada).

---

## Índice

1. [Características](#características)
2. [Qué es automático y qué debe hacerse manual](#qué-es-automático-y-qué-debe-hacerse-manual)
3. [Inicio Rápido (Instalación Automática)](#inicio-rápido-instalación-automática)
4. [Guía Paso a Paso (Instalación Manual para principiantes)](#guía-paso-a-paso-instalación-manual-para-principiantes)
   - [Paso 1: Paquetes y prerrequisitos en Ubuntu / WSL](#paso-1-paquetes-y-prerrequisitos-en-ubuntu--wsl)
   - [Paso 2: Descargar e instalar las fuentes Nerd Font en Windows](#paso-2-descargar-e-instalar-las-fuentes-nerd-font-en-windows)
   - [Paso 3: Instalar Starship en WSL](#paso-3-instalar-starship-en-wsl)
   - [Paso 4: Copiar la configuración del prompt](#paso-4-copiar-la-configuración-del-prompt)
   - [Paso 5: Configurar Oh My Zsh y ~/.zshrc](#paso-5-configurar-oh-my-zsh-y-zshrc)
   - [Paso 6: Configurar Windows Terminal](#paso-6-configurar-windows-terminal)
   - [Paso 7: Establecer Zsh como shell predeterminada](#paso-7-establecer-zsh-como-shell-predeterminada)
5. [Verificación y pruebas automatizadas](#verificación-y-pruebas-automatizadas)
6. [Resolución de problemas y Preguntas Frecuentes](#resolución-de-problemas-y-preguntas-frecuentes)
7. [Estructura del directorio](#estructura-del-directorio)

---

## Características

- **Prompt**: Formato minimalista de Starship en 2 líneas con la paleta Catppuccin Mocha.
- **Integración con Git**: Muestra el nombre de la rama, el glifo (``) y el estado del árbol de trabajo (cambios sin confirmar, por delante, por detrás).
- **Tipografía**: Fuente CaskaydiaCove Nerd Font Mono (Cascadia Code con iconos y glifos para desarrolladores).
- **Windows Terminal**: Paleta completa Catppuccin Mocha, cursor tipo barra, padding cómodo, transparencia acrílica (95%) y pestaña con acento de color aplicados tanto a Ubuntu como a Windows PowerShell.
- **Sincronización con PowerShell**: Soporte y sincronización integral para Windows PowerShell (5.1) y PowerShell 7 Core usando la misma configuración de Starship, fuente y tema Catppuccin.
- **Compatibilidad**: Integración total con Oh My Zsh y migración limpia de variables y alias existentes de `.bashrc`.

---

## Qué es automático y qué debe hacerse manual

Debido a que Windows y WSL son dos entornos con límites de permisos y seguridad separados, hay pasos que un script puede hacer automáticamente y otros que Windows exige realizar manualmente:

| Paso / Componente | ¿Automatizado por `scripts/install.sh`? | ¿Acción manual requerida? | Detalles y permisos |
| :--- | :---: | :---: | :--- |
| **Prerrequisitos** (`zsh`, `curl`, `tar`, `git`) | **Sí** | Introducir contraseña sudo | Si falta algún paquete en Ubuntu, el script pedirá tu clave de `sudo`. |
| **Starship CLI** | **Sí** | Ninguna | Se instala en espacio de usuario (`~/.local/bin/starship`, sin root). |
| **Configuración del Prompt** (`starship.toml`) | **Sí** | Ninguna | Se copia automáticamente a `~/.config/starship.toml`. |
| **Oh My Zsh y `.zshrc`** | **Sí** | Ninguna | Clona OMZ, crea un respaldo `~/.zshrc.bak`, aplica `ZSH_THEME=""` e importa alias. |
| **Descarga de Fuentes Nerd Font** | **Sí** | Ninguna | Descarga v3.5.1 y extrae los 4 archivos TTF en `Descargas\CascadiaCode-NerdFont` de Windows. |
| **Instalar fuentes en Windows** | **No** | **Sí (1 clic)** | Por seguridad de Windows, debes hacer clic derecho sobre los 4 `.ttf` y pulsar **Instalar**. |
| **Ajustes de Windows Terminal** | **Sí** | Ninguna | Localiza tu `settings.json`, genera respaldo y aplica el tema y perfil a Ubuntu y PowerShell. |
| **Sincronización con PowerShell** | **Sí** | Ninguna | Sincroniza el prompt en `%USERPROFILE%\.config\starship.toml`, crea el perfil `ps1` e instala `starship.exe` en `%USERPROFILE%\bin`. |
| **Zsh como shell por defecto** | **Guiado** | **Sí (1 comando)** | Ejecutar `chsh -s $(which zsh)` para cambiar tu shell de login de bash a zsh. |
| **Reinicio de Terminal** | **No** | **Sí** | Cerrar y volver a abrir Windows Terminal para que cargue la nueva fuente. |

---

## Inicio Rápido (Instalación Automática)

Si estás en WSL Ubuntu, ejecuta el instalador automatizado desde esta carpeta:

```bash
cd workstations/wsl-terminal-config
./scripts/install.sh
```

El script se encargará de:
1. Comprobar e instalar con `sudo apt` los paquetes que falten (`curl`, `tar`, `git`, `zsh`).
2. Instalar Starship en `~/.local/bin/starship`.
3. Aplicar `starship.toml` en `~/.config/starship.toml`.
4. Instalar Oh My Zsh y generar tu `~/.zshrc` preparado y con tus alias.
5. Descargar y descomprimir las 4 fuentes en tu carpeta `Descargas\CascadiaCode-NerdFont` de Windows.
6. Actualizar de forma segura el archivo `settings.json` de Windows Terminal con el tema Catppuccin Mocha y los estilos del perfil Ubuntu.

### Pasos manuales restantes tras ejecutar el script:
1. **Instalar fuentes en Windows**: Abre el Explorador de Windows en `Descargas\CascadiaCode-NerdFont`, selecciona los 4 ficheros `.ttf`, haz clic derecho y pulsa **Instalar**.
2. **Definir Zsh como shell predeterminada** (si no lo has hecho ya):
   ```bash
   chsh -s $(which zsh)
   ```
3. **Reiniciar Windows Terminal**: Cierra completamente la ventana de Windows Terminal y ábrela de nuevo.

Para verificar que todo está correctamente instalado, ejecuta:
```bash
./scripts/verify.sh
```

---

## Guía Paso a Paso (Instalación Manual para principiantes)

Si prefieres realizar el proceso paso a paso o necesitas entender cada detalle:

### Paso 1: Paquetes y prerrequisitos en Ubuntu / WSL

Abre tu terminal en WSL y asegúrate de tener instaladas las herramientas básicas:

```bash
sudo apt update
sudo apt install -y zsh curl tar git
```

### Paso 2: Descargar e instalar las fuentes Nerd Font en Windows

Windows Terminal se ejecuta en Windows, por lo que las fuentes deben residir en el **sistema anfitrión de Windows**:

1. Descarga el paquete `CascadiaCode.tar.xz` desde la [versión oficial Nerd Fonts v3.5.1](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaCode.tar.xz).
2. Descomprime el archivo (por ejemplo, con 7-Zip).
3. Selecciona estos cuatro ficheros de fuente:
   - `CaskaydiaCoveNerdFontMono-Regular.ttf`
   - `CaskaydiaCoveNerdFontMono-Bold.ttf`
   - `CaskaydiaCoveNerdFontMono-Italic.ttf`
   - `CaskaydiaCoveNerdFontMono-BoldItalic.ttf`
4. Haz clic derecho y selecciona **Instalar** (o **Instalar para todos los usuarios**).
5. El nombre oficial de la familia de fuentes en Windows Terminal es: **`CaskaydiaCove Nerd Font Mono`**.

### Paso 3: Instalar Starship en WSL

Ejecuta el instalador oficial de Starship en espacio de usuario (sin necesidad de permisos root):

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh
sh /tmp/starship-install.sh --yes --bin-dir "$HOME/.local/bin"
```

Asegúrate de que `~/.local/bin` esté en tu `$PATH` agregando esta línea si es necesario:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Paso 4: Copiar la configuración del prompt

Copia la plantilla de configuración en el directorio estándar de Starship:

```bash
mkdir -p "$HOME/.config"
cp starship.toml "$HOME/.config/starship.toml"
```

### Paso 5: Configurar Oh My Zsh y ~/.zshrc

1. Si no tienes Oh My Zsh instalado, clónalo:
   ```bash
   git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
   ```

2. Configura tu fichero `~/.zshrc`:
   - Desactiva el tema nativo de OMZ antes de cargarlo (`zsh/omz-theme-setting.zsh`):
     ```zsh
     ZSH_THEME=""
     ```
   - Carga Oh My Zsh:
     ```zsh
     source $ZSH/oh-my-zsh.sh
     ```
   - Añade tus herramientas, alias y variables de entorno habituales (por ejemplo, de tu `.bashrc`).
   - Al **final absoluto** de `~/.zshrc`, añade la inicialización de Starship (`zsh/starship-init.zsh`):
     ```zsh
     eval "$(starship init zsh)"
     ```

### Paso 6: Configurar Windows Terminal

Puedes aplicar la configuración automáticamente ejecutando nuestro script en Python:

```bash
python3 scripts/apply-windows-terminal-settings.py
```

O hacerlo a mano:
1. En Windows Terminal pulsa `Ctrl+,` y abajo a la izquierda selecciona **Abrir archivo JSON**.
2. En la lista `"schemes": [ ... ]`, pega el contenido de [windows-terminal/catppuccin-mocha.json](windows-terminal/catppuccin-mocha.json).
3. En `"profiles": { "list": [ ... ] }`, busca tu perfil de Ubuntu y agrégale las propiedades de [windows-terminal/profile-appearance.json](windows-terminal/profile-appearance.json):
   ```json
   "colorScheme": "Catppuccin Mocha",
   "font": {
       "face": "CaskaydiaCove Nerd Font Mono",
       "size": 12.5
   },
   "padding": "12, 12, 12, 12",
   "cursorShape": "bar",
   "cursorColor": "#F5E0DC",
   "useAcrylic": true,
   "opacity": 95,
   "tabColor": "#89B4FA"
   ```
4. Guarda el archivo.

### Paso 7: Establecer Zsh como shell predeterminada

Cambia la shell por defecto de tu usuario de Ubuntu:

```bash
chsh -s $(which zsh)
```

Cierra Windows Terminal y vuelve a abrirlo.

### Paso 8: (Opcional) Sincronización con Windows PowerShell

Para disfrutar exactamente de la misma apariencia y prompt en PowerShell nativo de Windows:

1. **Instalar Starship en Windows**:
   Ejecuta en PowerShell:
   ```powershell
   winget install --id Starship.Starship
   ```
   *(O el instalador automático `install.sh` ubicará `starship.exe` en `%USERPROFILE%\bin\starship.exe` automáticamente).*

2. **Sincronizar la configuración del prompt**:
   Asegúrate de que `starship.toml` esté copiado en `%USERPROFILE%\.config\starship.toml`.

3. **Configurar el perfil de PowerShell**:
   Edita `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (o `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`):
   ```powershell
   if (Get-Command starship -ErrorAction SilentlyContinue) {
       Invoke-Expression (&starship init powershell)
   }
   Set-Alias -Name g -Value git
   ```

4. **Permitir scripts locales en PowerShell**:
   Si PowerShell muestra una advertencia de política de ejecución al cargar tu perfil, ejecuta una sola vez:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## Verificación y pruebas automatizadas

El repositorio incluye un conjunto de pruebas automatizadas en `scripts/verify.sh` que comprueba 16 puntos clave:

```bash
./scripts/verify.sh
```

Comprobaciones realizadas:
- [x] Binario de Zsh y versión instalada
- [x] Shell por defecto del usuario en `/etc/passwd`
- [x] Binario de Starship y versión
- [x] Sintaxis y módulos de `~/.config/starship.toml`
- [x] Estructura de directorios de Oh My Zsh
- [x] Desactivación del tema OMZ (`ZSH_THEME=""`) en `~/.zshrc`
- [x] Hook de inicialización de Starship en `~/.zshrc`
- [x] Comprobación de sintaxis limpia de `~/.zshrc` (`zsh -n`)
- [x] Detección de las 4 fuentes TTF `CaskaydiaCove Nerd Font Mono` en Windows
- [x] Presencia del esquema Catppuccin Mocha en `settings.json`
- [x] Asignación de la fuente al perfil Ubuntu en Windows Terminal
- [x] Prueba de renderizado del prompt con glifos de Git en sesión Zsh interactiva
- [x] Sincronización de `starship.toml` en el home de Windows (`%USERPROFILE%\.config\starship.toml`)
- [x] Disponibilidad del binario `starship.exe` para Windows
- [x] Perfil de PowerShell configurado con el hook de Starship (`Microsoft.PowerShell_profile.ps1`)
- [x] Perfil de Windows PowerShell estilizado en Windows Terminal

---

## Resolución de problemas y Preguntas Frecuentes

#### 1. El símbolo de la rama Git sale como un cuadrado `[?]` o carácter roto.
* **Causa**: Windows Terminal no tiene seleccionada la fuente parcheada o no se reinició Windows Terminal tras instalar la fuente.
* **Solución**: Asegúrate de haber instalado los 4 archivos `.ttf` en Windows y reinicia Windows Terminal. Revisa en la configuración que la propiedad `"font"` tenga `"face": "CaskaydiaCove Nerd Font Mono"`.

#### 2. Starship muestra el aviso `[ERROR] - (starship::print): Under a 'dumb' terminal`.
* **Causa**: Ocurre únicamente en terminales no interactivas de IDEs donde `$TERM` se establece en `dumb`.
* **Solución**: Las sesiones interactivas normales de Windows Terminal usan automáticamente `TERM=xterm-256color`. Puedes probarlo con `TERM=xterm-256color starship prompt`.

#### 3. ¿Dónde está el archivo `settings.json` en Windows?
* Ruta estándar de la Microsoft Store:
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
* Accesible desde WSL en:
  `/mnt/c/Users/<TuUsuarioWindows>/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`

---

## Estructura del directorio

```text
workstations/wsl-terminal-config/
├── README.md                              # Documentación en inglés (Internacional)
├── README.es.md                           # Documentación en español (Esta guía)
├── starship.toml                          # Configuración minimalista del prompt Starship
├── scripts/
│   ├── install.sh                         # Instalador automático integral
│   ├── verify.sh                          # Suite de verificación con 13 pruebas
│   └── apply-windows-terminal-settings.py # Modificador seguro de JSON con respaldo
├── windows-terminal/
│   ├── catppuccin-mocha.json              # Esquema de color independiente
│   └── profile-appearance.json            # Propiedades visuales del perfil
└── zsh/
    ├── omz-theme-setting.zsh              # Fragmento para desactivar tema OMZ
    └── starship-init.zsh                  # Fragmento de inicialización de Starship
```
