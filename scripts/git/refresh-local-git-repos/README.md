# refresh-local-git-repos.sh

Script Bash interactivo y con opciones CLI para gestionar, refrescar y clonar repositorios Git organizados por proyectos bajo un directorio base (por defecto `~/workspace/projects`).

## Características principales

1. **Modo interactivo guiado:** Si se ejecuta sin parámetros, presenta un menú con todos los proyectos locales detectados, su número de repositorios y opciones de configuración.
2. **Soporte de flags / CLI:** Permite especificar proyectos concretos (`-p ocp-apijo,ocp-penyas`) o todos (`-p all`).
3. **Clonado automático de nuevos repositorios remotos:** Opción `-c, --clone-new` para consultar la API REST de Bitbucket (`bitbucket.once.es`), comparar con los repos locales y clonar automáticamente aquellos que falten.
4. **Actualización segura de Git:**
   - Valida el estado del working tree antes de tocar nada.
   - Ejecuta `git fetch --all --prune`.
   - Aplica únicamente `git pull --ff-only` si la rama local está detrás y limpia.
5. **Control riguroso de fallos y bloqueos:**
   - **Detección temprana de CAPTCHA:** Si Bitbucket bloquea la cuenta por intentos fallidos, el script alerta de inmediato y detiene las peticiones sucesivas para evitar bloqueos prolongados.
   - **Exclusión de raíces inválidas:** No procesa el directorio base si contiene `.git` corruptos o vacíos (elimina el falso error `1/254`).
   - **Protección de trabajo en curso (BLOCKED):** No sobrescribe ramas divergidas, detached HEAD, conflictos ni cambios locales sin commit (`git stash` / `git commit` sugerido).

---

## Opciones y Parámetros

```text
Uso: refresh-local-git-repos.sh [opciones]

Opciones:
  -p, --proyectos <p1,p2|all>   Proyectos a refrescar (ej: ocp-apijo, ocp-penyas o all)
  -c, --clone-new               Detecta y clona automáticamente repos remotos nuevos en Bitbucket
  -s, --servicio <filtro>       Filtra microservicios dentro de los proyectos por nombre
  -n, --dry-run                 No modifica nada: solo valida estado local y upstream
  -d, --dir <directorio>        Directorio base de proyectos (defecto: ~/workspace/projects)
  -h, --help                    Muestra esta ayuda
```

---

## Ejemplos de uso

### 1. Modo interactivo (Recomendado)
```bash
~/workspace/scripts/bitbucket/refresh-local-git-repos/refresh-local-git-repos.sh
```

### 2. Refrescar un único proyecto
```bash
refresh-local-git-repos.sh -p ocp-apijo
```

### 3. Refrescar varios proyectos específicos y clonar los nuevos
```bash
refresh-local-git-repos.sh -p ocp-apijo,ocp-penyas -c
```

### 4. Refrescar todos los proyectos locales en modo dry-run
```bash
refresh-local-git-repos.sh -p all -n
```

### 5. Filtrar por un microservicio concreto en todos los proyectos
```bash
refresh-local-git-repos.sh -p all -s dow-jones
```

---

## Estados del script

* `UPDATED`: Repositorio actualizado con `pull --ff-only`.
* `UP-TO-DATE`: Ya estaba sincronizado con su upstream.
* `WOULD-UPDATE`: (Modo dry-run) Requiere pull y es seguro aplicarlo.
* `CLONED`: Nuevo repositorio remoto clonado desde Bitbucket.
* `BLOCKED`: Requiere intervención manual (cambios sin guardar, divergencia, merge en curso).
* `ERROR`: Fallo de red, autenticación o comando Git.
