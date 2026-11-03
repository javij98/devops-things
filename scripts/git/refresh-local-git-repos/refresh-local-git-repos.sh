#!/usr/bin/env bash
# ==============================================================================
# refresh-local-git-repos.sh
# 
# Script interactivo y con flags para:
# 1. Seleccionar proyectos específicos o todos ('all') en ~/workspace/projects.
# 2. Refrescar repositorios locales mediante git fetch --all --prune y git pull --ff-only.
# 3. Detectar y clonar automáticamente nuevos repositorios remotos desde Bitbucket.
# 4. Control exhaustivo de fallos:
#    - Detección de bloqueos por CAPTCHA / cuenta bloqueada en Bitbucket.
#    - Protección contra sobreescritura de cambios locales (BLOCKED).
#    - Exclusión automática del directorio base de proyectos (evita falso error 1/254).
#    - Clasificación precisa de errores de Git y red.
# ==============================================================================

set -uo pipefail

# Colores (solo si terminal interactivo)
if [ -t 1 ]; then
  BOLD="\033[1m"
  GREEN="\033[0;32m"
  RED="\033[0;31m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  CYAN="\033[0;36m"
  MAGENTA="\033[0;35m"
  NC="\033[0m" # No Color
else
  BOLD=""
  GREEN=""
  RED=""
  YELLOW=""
  BLUE=""
  CYAN=""
  MAGENTA=""
  NC=""
fi

# Variables de configuración
SERVER="bitbucket.once.es"
DRY_RUN=0
CLONE_NEW=0
SELECTED_PROJECTS_ARG=""
SERVICE_FILTER=""

# Directorio base por defecto
if [[ -d "$PWD/ocp-apijo" || -d "$PWD/ocp-penyas" ]]; then
  BASE_DIR="$PWD"
elif [[ -d "/home/jjimenezmo/workspace/projects" ]]; then
  BASE_DIR="/home/jjimenezmo/workspace/projects"
else
  BASE_DIR="$PWD"
fi

# Contadores globales
UPDATED_COUNT=0
UP_TO_DATE_COUNT=0
WOULD_UPDATE_COUNT=0
CLONED_COUNT=0
BLOCKED_COUNT=0
ERROR_COUNT=0

declare -a BLOCKED_REPORTS=()
declare -a ERROR_REPORTS=()

# Estado del repositorio actual
CURRENT_STATUS=""
CURRENT_SUMMARY=""
CURRENT_DETAILS=""
CURRENT_GUIDANCE=""
CURRENT_OUTPUT=""
CURRENT_BRANCH=""
CURRENT_UPSTREAM=""
CURRENT_AHEAD=0
CURRENT_BEHIND=0
declare -a CURRENT_BLOCKERS=()
declare -a CURRENT_GUIDES=()

CAPTCHA_ABORT=0

# Credenciales en memoria para API Bitbucket
BB_USER=""
BB_PASS=""

# ==============================================================================
# AYUDA Y USO
# ==============================================================================
usage() {
  echo -e "${BOLD}Uso:${NC} $(basename "$0") [opciones]

${BOLD}Opciones:${NC}
  -p, --proyectos <p1,p2|all>   Proyectos a refrescar (ej: ocp-apijo, ocp-penyas o all)
  -c, --clone-new               Detecta y clona automáticamente repos remotos nuevos en Bitbucket
  -s, --servicio <filtro>       Filtra microservicios dentro de los proyectos por nombre
  -n, --dry-run                 No modifica nada: solo valida estado local y upstream
  -d, --dir <directorio>        Directorio base de proyectos (defecto: $BASE_DIR)
  -h, --help                    Muestra esta ayuda

Si se ejecuta sin parámetros, el script entrará en ${BOLD}modo interactivo guiado${NC}."
  exit 0
}

# ==============================================================================
# PARSEO DE PARÁMETROS
# ==============================================================================
while (($# > 0)); do
  case "$1" in
    -p|--proyectos|--proyecto)
      SELECTED_PROJECTS_ARG="$2"
      shift 2
      ;;
    -c|--clone-new)
      CLONE_NEW=1
      shift
      ;;
    -s|--servicio|--service)
      SERVICE_FILTER="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -d|--dir)
      BASE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    all|todos)
      SELECTED_PROJECTS_ARG="all"
      shift
      ;;
    *)
      if [ -z "$SELECTED_PROJECTS_ARG" ]; then
        SELECTED_PROJECTS_ARG="$1"
      else
        echo "Argumento no reconocido: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================
shell_quote() {
  printf '%q' "$1"
}

indent_block() {
  local prefix="$1"
  local text="${2-}"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s%s\n' "$prefix" "$line"
  done <<< "$text"
}

build_bullets() {
  local out=""
  local item
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    out+="- $item"$'\n'
  done
  printf '%s' "${out%$'\n'}"
}

build_unique_paragraphs() {
  local out=""
  local item
  declare -A seen=()
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    if [[ -n "${seen["$item"]+x}" ]]; then
      continue
    fi
    seen["$item"]=1
    if [[ -n "$out" ]]; then
      out+=$'\n\n'
    fi
    out+="$item"
  done
  printf '%s' "$out"
}

compact_output() {
  local text="${1-}"
  [[ -n "$text" ]] || return 0
  printf '%s\n' "$text" | sed '/^[[:space:]]*$/d' | tail -n 12
}

read_password() {
  local prompt="$1"
  local password=""
  local char
  echo -n "$prompt" >&2
  while IFS= read -r -s -n1 char; do
    if [[ -z $char ]]; then
      echo >&2
      break
    elif [[ $char == $'\177' ]]; then
      if [ -n "$password" ]; then
        password="${password%?}"
        echo -ne "\b \b" >&2
      fi
    else
      password+="$char"
      echo -n "*" >&2
    fi
  done
  echo "$password"
}

reset_current_result() {
  CURRENT_STATUS=""
  CURRENT_SUMMARY=""
  CURRENT_DETAILS=""
  CURRENT_GUIDANCE=""
  CURRENT_OUTPUT=""
  CURRENT_BRANCH=""
  CURRENT_UPSTREAM=""
  CURRENT_AHEAD=0
  CURRENT_BEHIND=0
  CURRENT_BLOCKERS=()
  CURRENT_GUIDES=()
}

add_blocker() {
  local reason="$1"
  local guide="$2"
  CURRENT_BLOCKERS+=("$reason")
  CURRENT_GUIDES+=("$guide")
}

finalize_blocked_result() {
  CURRENT_STATUS="BLOCKED"
  if ((${#CURRENT_BLOCKERS[@]} == 1)); then
    CURRENT_SUMMARY="${CURRENT_BLOCKERS[0]}"
  else
    CURRENT_SUMMARY="Se han detectado ${#CURRENT_BLOCKERS[@]} bloqueos que requieren intervencion manual."
  fi
  CURRENT_DETAILS=$(build_bullets "${CURRENT_BLOCKERS[@]}")
  CURRENT_GUIDANCE=$(build_unique_paragraphs "${CURRENT_GUIDES[@]}")
}

set_error_result() {
  local summary="$1"
  local guidance="$2"
  local output="${3-}"
  CURRENT_STATUS="ERROR"
  CURRENT_SUMMARY="$summary"
  CURRENT_DETAILS=$(build_bullets "$summary")
  CURRENT_GUIDANCE="$guidance"
  CURRENT_OUTPUT=$(compact_output "$output")
}

# ==============================================================================
# DESCUBRIMIENTO DE PROYECTOS Y REPOSITORIOS
# ==============================================================================
# Obtiene proyectos locales que contengan repositorios Git
get_available_projects() {
  local p
  local bname
  local count
  for p in "$BASE_DIR"/*; do
    [[ -d "$p" ]] || continue
    bname=$(basename "$p")
    # Ignorar carpetas de sistema o no proyectos
    [[ "$bname" != .* && "$bname" != "graphify-out" && "$bname" != "vscode-workspaces" && "$bname" != "worktrees" ]] || continue
    count=$(find "$p" -maxdepth 2 -name .git 2>/dev/null | wc -l)
    if ((count > 0)); then
      printf '%s\n' "$bname"
    fi
  done
}

# Cuenta repositorios válidos dentro de un proyecto
count_project_repos() {
  local proj_dir="$1"
  find "$proj_dir" -maxdepth 2 -name .git 2>/dev/null | wc -l
}

# Infiere la clave del proyecto en Bitbucket a partir de los remotos locales
get_bitbucket_project_key() {
  local proj_dir="$1"
  local sample_git
  local url
  local key=""
  sample_git=$(find "$proj_dir" -maxdepth 2 -name .git 2>/dev/null | head -n 1)
  if [[ -n "$sample_git" ]]; then
    url=$(git -C "$(dirname "$sample_git")" remote get-url origin 2>/dev/null || true)
    key=$(echo "$url" | sed -nE 's#.*/scm/([^/]+)/.*#\1#p')
    if [[ -z "$key" ]]; then
      key=$(echo "$url" | sed -nE 's#.*[:/]([^/]+)/[^/]+\.git#\1#p')
    fi
  fi
  if [[ -z "$key" ]]; then
    key=$(basename "$proj_dir")
  fi
  printf '%s' "$key"
}

# Intenta extraer credenciales guardadas en remotes existentes
try_extract_remote_creds() {
  local p
  local g
  local u
  for p in "$BASE_DIR"/*; do
    [[ -d "$p" ]] || continue
    for g in "$p"/*/.git; do
      [[ -d "$g" ]] || continue
      u=$(git -C "$(dirname "$g")" remote get-url origin 2>/dev/null || true)
      if [[ "$u" =~ https://([^:]+):([^@]+)@bitbucket\.once\.es ]]; then
        BB_USER="${BASH_REMATCH[1]}"
        BB_PASS="${BASH_REMATCH[2]}"
        return 0
      fi
    done
  done
  return 1
}

# ==============================================================================
# MODO INTERACTIVO
# ==============================================================================
if [ -z "$SELECTED_PROJECTS_ARG" ]; then
  echo -e "${BOLD}${CYAN}======================================================================${NC}"
  echo -e "${BOLD}${CYAN}      REFRESCO Y CLONADO DE REPOSITORIOS BITBUCKET / GIT LOCALES      ${NC}"
  echo -e "${BOLD}${CYAN}======================================================================${NC}"
  echo -e "Directorio base: ${YELLOW}$BASE_DIR${NC}\n"

  # Listar proyectos disponibles
  declare -a PROJ_LIST=()
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    PROJ_LIST+=("$p")
  done < <(get_available_projects)

  if ((${#PROJ_LIST[@]} == 0)); then
    echo -e "${RED}❌ No se encontraron proyectos con repositorios Git en $BASE_DIR${NC}" >&2
    exit 1
  fi

  echo -e "${BOLD}1) Selecciona el/los proyectos a refrescar:${NC}"
  local_idx=1
  total_all_repos=0
  for p in "${PROJ_LIST[@]}"; do
    c=$(count_project_repos "$BASE_DIR/$p")
    ((total_all_repos += c))
    printf '   %2d) %-25s (%s repos)\n' "$local_idx" "$p" "$c"
    ((local_idx += 1))
  done
  printf '    0) %-25s (%s repos en total)\n' "Todos los proyectos (all)" "$total_all_repos"
  echo ""

  read -r -p "   Elige opciones [0-${#PROJ_LIST[@]}, o varias separadas por coma] (defecto: 0 - Todos): " opt_proj
  opt_proj="${opt_proj:-0}"

  if [[ "$opt_proj" == "0" || "$opt_proj" == "all" || "$opt_proj" == "todos" ]]; then
    SELECTED_PROJECTS_ARG="all"
  else
    # Parsear lista separada por comas o números
    declare -a CHOSEN=()
    IFS=',' read -r -a tokens <<< "$opt_proj"
    for tok in "${tokens[@]}"; do
      tok=$(echo "$tok" | tr -d '[:space:]')
      if [[ "$tok" =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= ${#PROJ_LIST[@]})); then
        CHOSEN+=("${PROJ_LIST[$((tok - 1))]}")
      elif [[ -d "$BASE_DIR/$tok" ]]; then
        CHOSEN+=("$tok")
      fi
    done
    if ((${#CHOSEN[@]} == 0)); then
      echo -e "${YELLOW}Selección no válida. Se procesarán todos los proyectos.${NC}"
      SELECTED_PROJECTS_ARG="all"
    else
      SELECTED_PROJECTS_ARG=$(IFS=,; echo "${CHOSEN[*]}")
    fi
  fi
  echo ""

  # Pregunta: Clonar nuevos repos remotos
  read -r -p "2) ¿Comprobar y clonar nuevos repositorios desde Bitbucket? [s/N]: " opt_clone
  if [[ "$opt_clone" =~ ^[sSyY]$ ]]; then
    CLONE_NEW=1
  else
    CLONE_NEW=0
  fi
  echo ""

  # Pregunta: Filtro de microservicio
  read -r -p "3) Filtrar por nombre de microservicio (opcional, ENTER para todos): " input_svc
  SERVICE_FILTER="$input_svc"
  echo ""

  # Pregunta: Dry run
  read -r -p "4) ¿Modo dry-run (solo comprobar sin hacer fetch ni pull)? [s/N]: " opt_dry
  if [[ "$opt_dry" =~ ^[sSyY]$ ]]; then
    DRY_RUN=1
  else
    DRY_RUN=0
  fi
  echo ""
fi

# ==============================================================================
# RESOLUCIÓN DE PROYECTOS SELECCIONADOS
# ==============================================================================
declare -a TARGET_PROJECTS=()
if [[ "$SELECTED_PROJECTS_ARG" == "all" || "$SELECTED_PROJECTS_ARG" == "todos" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    TARGET_PROJECTS+=("$p")
  done < <(get_available_projects)
else
  IFS=',' read -r -a p_tokens <<< "$SELECTED_PROJECTS_ARG"
  for pt in "${p_tokens[@]}"; do
    pt=$(echo "$pt" | tr -d '[:space:]')
    if [[ -d "$BASE_DIR/$pt" ]]; then
      TARGET_PROJECTS+=("$pt")
    else
      echo -e "${YELLOW}⚠️ Aviso: El proyecto '$pt' no existe en $BASE_DIR. Se omitirá.${NC}"
    fi
  done
fi

if ((${#TARGET_PROJECTS[@]} == 0)); then
  echo -e "${RED}❌ No hay proyectos válidos seleccionados para refrescar.${NC}" >&2
  exit 1
fi

# ==============================================================================
# GESTIÓN DE CLONADO REMOTO DE NUEVOS REPOSITORIOS
# ==============================================================================
check_and_clone_new_repos() {
  local project="$1"
  local proj_dir="$BASE_DIR/$project"
  local project_key
  project_key=$(get_bitbucket_project_key "$proj_dir")

  echo -e "\n${BOLD}${MAGENTA}--- Comprobando repositorios remotos en Bitbucket (${project_key}) ---${NC}"

  # Si no hay credenciales, intentar extraerlas de remotes o pedirlas
  if [[ -z "$BB_USER" || -z "$BB_PASS" ]]; then
    if ! try_extract_remote_creds; then
      echo -e "${CYAN}Se requieren credenciales para consultar la API de Bitbucket (https://${SERVER}):${NC}"
      read -r -p "👤 Usuario: " BB_USER
      BB_PASS=$(read_password "🔑 Contraseña o Personal Access Token: ")
      echo ""
    fi
  fi

  if [[ -z "$BB_USER" || -z "$BB_PASS" ]]; then
    echo -e "${YELLOW}⚠️ Sin credenciales. Se omite la detección de nuevos repos remotos.${NC}"
    return 0
  fi

  local api_url="https://${SERVER}/rest/api/1.0/projects/${project_key}/repos?limit=1000"
  local response
  local http_code
  local body

  response=$(curl -s -w "\n%{http_code}" -u "${BB_USER}:${BB_PASS}" "$api_url")
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$body" =~ [Cc][Aa][Pp][Tt][Cc][Hh][Aa] || "$body" =~ "account has been locked" || "$http_code" == "401" && "$body" =~ "CaptchaRequired" ]]; then
    echo -e "${BOLD}${RED}❌ ERROR CRÍTICO: Cuenta de Bitbucket bloqueada por CAPTCHA.${NC}"
    echo -e "${RED}Bitbucket ha bloqueado la cuenta tras varios intentos fallidos.${NC}"
    echo -e "${YELLOW}Acción requerida: Abre https://${SERVER} en tu navegador, cierra sesión si estabas dentro, vuelve a iniciar sesión y resuelve el CAPTCHA.${NC}\n"
    CAPTCHA_ABORT=1
    return 1
  fi

  if [ "$http_code" -ne 200 ]; then
    echo -e "${YELLOW}⚠️ No se pudo consultar la API de Bitbucket para '$project_key' (HTTP $http_code). Se omite el clonado.${NC}"
    return 0
  fi

  if ! echo "$body" | jq empty 2>/dev/null; then
    echo -e "${RED}❌ Respuesta no válida de la API de Bitbucket.${NC}"
    return 0
  fi

  local remote_count
  remote_count=$(echo "$body" | jq -r '.values | length')
  echo -e "Repositorios reportados por Bitbucket en '${project_key}': ${BOLD}${remote_count}${NC}"

  while IFS= read -r repo_slug; do
    [[ -n "$repo_slug" ]] || continue
    
    # Filtrar por servicio si aplica
    if [[ -n "$SERVICE_FILTER" && "$repo_slug" != *"$SERVICE_FILTER"* ]]; then
      continue
    fi

    local target_dir="$proj_dir/$repo_slug"
    if [[ -d "$target_dir" ]]; then
      continue # Ya existe en local
    fi

    echo -e "${CYAN}➕ Detectado nuevo repositorio remoto: ${BOLD}${repo_slug}${NC}"
    if ((DRY_RUN)); then
      echo -e "${YELLOW}   [DRY-RUN] Se clonaría en $target_dir${NC}"
      ((CLONED_COUNT += 1))
      continue
    fi

    # Obtener URL HTTP de clonado
    local clone_url
    clone_url=$(echo "$body" | jq -r --arg s "$repo_slug" '.values[] | select(.slug==$s) | .links.clone[] | select(.name=="http") | .href')
    if [[ -z "$clone_url" ]]; then
      clone_url="https://${SERVER}/scm/${project_key}/${repo_slug}.git"
    fi

    echo -e "${BLUE}   🔄 Clonando en $target_dir ...${NC}"
    local clone_output
    clone_output=$(git clone "$clone_url" "$target_dir" 2>&1)
    if (($? == 0)); then
      echo -e "${GREEN}   ✅ Clonado exitosamente.${NC}"
      ((CLONED_COUNT += 1))
    else
      echo -e "${RED}   ❌ Error al clonar:${NC}"
      indent_block "      " "$clone_output"
      ((ERROR_COUNT += 1))
      ERROR_REPORTS+=("$(format_report "$target_dir" "ERROR" "Fallo al clonar nuevo repositorio desde Bitbucket" "- No se pudo clonar $repo_slug" "Revisa permisos o conectividad: git clone $clone_url" "$clone_output")")
      if [[ "$clone_output" =~ [Cc][Aa][Pp][Tt][Cc][Hh][Aa] || "$clone_output" =~ "account has been locked" ]]; then
        CAPTCHA_ABORT=1
        return 1
      fi
    fi
  done < <(echo "$body" | jq -r '.values[].slug')
}

# ==============================================================================
# CLASIFICACIÓN DE ERRORES DE GIT
# ==============================================================================
classify_git_failure() {
  local command_label="$1"
  local repo="$2"
  local output="$3"
  local lower_output
  local quoted_repo

  lower_output=$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')
  quoted_repo=$(shell_quote "$repo")

  # 1. Detección prioritaria de CAPTCHA / cuenta bloqueada
  if [[ "$lower_output" =~ captcha\ required || "$lower_output" =~ account\ has\ been\ locked || "$lower_output" =~ captcharequired ]]; then
    set_error_result \
      "Cuenta de Bitbucket bloqueada por CAPTCHA durante '$command_label'." \
      "⚠️ Bitbucket ha bloqueado la cuenta por demasiados intentos fallidos.
Acción requerida: Abre https://${SERVER} en tu navegador, cierra sesión si estabas dentro, vuelve a entrar y resuelve el CAPTCHA." \
      "$output"
    CAPTCHA_ABORT=1
    return 0
  fi

  case "$lower_output" in
    *"authentication failed"*|*"could not read username"*|*"access denied"*|*"permission denied"*|*"http basic: access denied"*|*"403 forbidden"*|*"401 unauthorized"*)
      set_error_result \
        "Fallo de autenticacion o permisos durante '$command_label'." \
        "Verifica tus credenciales o token para el remoto:
  git -C $quoted_repo remote -v
Cuando el acceso vuelva a funcionar, ejecuta de nuevo el script." \
        "$output"
      ;;
    *"could not resolve host"*|*"failed to connect"*|*"network is unreachable"*|*"no route to host"*|*"connection timed out"*|*"operation timed out"*|*"connection reset"*|*"temporary failure in name resolution"*)
      set_error_result \
        "Fallo de red durante '$command_label'." \
        "Comprueba conectividad, VPN, proxy o DNS hacia el remoto.
Cuando la red vuelva a estar disponible, vuelve a ejecutar el script." \
        "$output"
      ;;
    *"does not appear to be a git repository"*|*"repository not found"*|*"could not read from remote repository"*)
      set_error_result \
        "El remoto no existe, no es accesible o esta mal configurado para '$command_label'." \
        "Revisa la URL del remoto y los permisos:
  git -C $quoted_repo remote -v
Corrige el remoto si es necesario y vuelve a ejecutar el script." \
        "$output"
      ;;
    *"another git process seems to be running"*|*".lock"*|*"cannot lock ref"*|*"unable to create "*)
      set_error_result \
        "Git esta bloqueado por otro proceso o por archivos lock durante '$command_label'." \
        "Comprueba si hay otro proceso Git usando este repositorio.
Si no lo hay, elimina manualmente el archivo .lock afectado con cuidado y vuelve a ejecutar el script." \
        "$output"
      ;;
    *"not possible to fast-forward, aborting."*)
      set_error_result \
        "La rama no puede actualizarse con fast-forward." \
        "Revisa la divergencia del repo:
  git -C $quoted_repo log --oneline --left-right HEAD...@{u}
Integra los cambios manualmente segun la politica del repositorio y vuelve a ejecutar el script." \
        "$output"
      ;;
    *"please commit your changes or stash them"*|*"your local changes to the following files would be overwritten"*|*"your local changes would be overwritten"*)
      set_error_result \
        "Hay cambios locales que impiden completar '$command_label'." \
        "Revisa el estado del repo:
  git -C $quoted_repo status --short
Haz commit, stash o revierte esos cambios manualmente antes de volver a ejecutar el script." \
        "$output"
      ;;
    *)
      set_error_result \
        "Fallo inesperado durante '$command_label'." \
        "Ejecuta manualmente el comando para inspeccionar el problema:
  git -C $quoted_repo $command_label
Corrige el problema y vuelve a ejecutar el script." \
        "$output"
      ;;
  esac
}

# ==============================================================================
# VALIDACIÓN LOCAL Y ACTUALIZACIÓN DEL REPOSITORIO
# ==============================================================================
collect_local_blockers() {
  local repo="$1"
  local git_dir="$2"
  local branch="$3"
  local upstream="$4"
  local quoted_repo
  local status_output
  local line
  local xy
  local has_conflicts=0
  local has_staged=0
  local has_unstaged=0
  local has_untracked=0

  quoted_repo=$(shell_quote "$repo")

  if [[ -f "$git_dir/MERGE_HEAD" ]]; then
    add_blocker "Hay un merge en curso." "Termina el merge o abortalo con: git -C $quoted_repo merge --abort"
  fi
  if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
    add_blocker "Hay un rebase en curso." "Continua con: git -C $quoted_repo rebase --continue o aborta con: git -C $quoted_repo rebase --abort"
  fi
  if [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
    add_blocker "Hay un cherry-pick en curso." "Continua o aborta con: git -C $quoted_repo cherry-pick --abort"
  fi
  if [[ -f "$git_dir/REVERT_HEAD" ]]; then
    add_blocker "Hay un revert en curso." "Continua o aborta con: git -C $quoted_repo revert --abort"
  fi
  if [[ -f "$git_dir/BISECT_LOG" ]]; then
    add_blocker "Hay una sesion de git bisect en curso." "Finaliza con: git -C $quoted_repo bisect reset"
  fi
  if [[ -f "$git_dir/index.lock" || -f "$git_dir/FETCH_HEAD.lock" || -f "$git_dir/HEAD.lock" || -f "$git_dir/config.lock" ]]; then
    add_blocker "Existen archivos lock de Git en el repositorio." "Verifica que no haya procesos activos y elimina el archivo lock si procede."
  fi
  if [[ -z "$branch" ]]; then
    add_blocker "HEAD esta desacoplado (detached HEAD)." "Cambia a una rama: git -C $quoted_repo switch <rama>"
  fi
  if [[ -n "$branch" && -z "$upstream" ]]; then
    add_blocker "La rama '$branch' no tiene upstream configurado." "Configura upstream: git -C $quoted_repo branch --set-upstream-to origin/$branch $branch"
  fi

  status_output=$(git -C "$repo" status --porcelain=v1 --untracked-files=normal --ignore-submodules=none 2>&1)
  if (($? != 0)); then
    set_error_result "No se pudo leer el estado local del repositorio." "Ejecuta: git -C $quoted_repo status" "$status_output"
    return 1
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    xy="${line:0:2}"
    if [[ "$xy" == "??" ]]; then
      has_untracked=1
      continue
    fi
    if [[ "$xy" == *U* || "$xy" == "AA" || "$xy" == "DD" ]]; then
      has_conflicts=1
    fi
    if [[ "${xy:0:1}" != " " && "${xy:0:1}" != "?" ]]; then
      has_staged=1
    fi
    if [[ "${xy:1:1}" != " " && "${xy:1:1}" != "?" ]]; then
      has_unstaged=1
    fi
  done <<< "$status_output"

  if ((has_conflicts)); then
    add_blocker "Hay conflictos sin resolver en el working tree." "Resuelve los conflictos antes de reintentar: git -C $quoted_repo status"
  fi
  if ((has_staged)); then
    add_blocker "Hay cambios en staging sin commit." "Haz commit, stash o revierte los cambios en staging: git -C $quoted_repo status --short"
  fi
  if ((has_unstaged)); then
    add_blocker "Hay cambios locales sin preparar en el working tree." "Haz commit o stash de los cambios modificados: git -C $quoted_repo stash"
  fi

  return 0
}

assess_tracking_state() {
  local repo="$1"
  local branch="$2"
  local upstream="$3"
  local mode="$4"
  local quoted_repo
  local counts

  quoted_repo=$(shell_quote "$repo")
  counts=$(git -C "$repo" rev-list --left-right --count "HEAD...$upstream" 2>&1)
  if (($? != 0)); then
    set_error_result "No se pudo comparar la rama local con el upstream '$upstream'." "Revisa git -C $quoted_repo branch -vv" "$counts"
    return 1
  fi

  CURRENT_AHEAD="${counts%%[[:space:]]*}"
  CURRENT_BEHIND="${counts##*[[:space:]]}"

  if ((CURRENT_AHEAD > 0 && CURRENT_BEHIND > 0)); then
    add_blocker "La rama '$branch' ha divergido de '$upstream' (${CURRENT_AHEAD} locales, ${CURRENT_BEHIND} remotos)." \
      "Inspecciona la divergencia: git -C $quoted_repo log --oneline --left-right HEAD...$upstream"
    finalize_blocked_result
    return 0
  fi

  if ((CURRENT_AHEAD > 0)); then
    add_blocker "La rama '$branch' esta ${CURRENT_AHEAD} commit(s) por delante de '$upstream'." \
      "Haz push o reordena tus commits locales: git -C $quoted_repo log --oneline $upstream..HEAD"
    finalize_blocked_result
    return 0
  fi

  if ((CURRENT_BEHIND > 0)); then
    if ((DRY_RUN)) || [[ "$mode" == "dry-run" ]]; then
      CURRENT_STATUS="WOULD-UPDATE"
      CURRENT_SUMMARY="La rama '$branch' esta ${CURRENT_BEHIND} commit(s) por detras de '$upstream' y se podria actualizar."
    else
      CURRENT_STATUS="READY-TO-PULL"
      CURRENT_SUMMARY="La rama '$branch' esta ${CURRENT_BEHIND} commit(s) por detras de '$upstream'."
    fi
    return 0
  fi

  CURRENT_STATUS="UP-TO-DATE"
  CURRENT_SUMMARY="La rama '$branch' ya esta sincronizada con '$upstream'."
  return 0
}

process_repo() {
  local repo="$1"
  local is_bare
  local git_dir
  local branch
  local upstream
  local fetch_output
  local pull_output

  reset_current_result

  # Validar que sea un repositorio real con working tree (evita falsos positivos como la raiz)
  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    set_error_result "La ruta detectada no es un repositorio Git valido." "Verifica la ruta o elimina la carpeta .git vacia/danada."
    return 0
  fi

  is_bare=$(git -C "$repo" rev-parse --is-bare-repository 2>/dev/null || printf 'false')
  if [[ "$is_bare" == "true" ]]; then
    add_blocker "El repositorio es bare y no tiene working tree." "Este script esta disenado para clones estandar."
    finalize_blocked_result
    return 0
  fi

  git_dir=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null || true)
  if [[ -z "$git_dir" ]]; then
    set_error_result "No se pudo localizar el directorio interno de Git." "Ejecuta: git -C $(shell_quote "$repo") rev-parse --absolute-git-dir"
    return 0
  fi

  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  CURRENT_BRANCH="$branch"
  CURRENT_UPSTREAM="$upstream"

  if ! collect_local_blockers "$repo" "$git_dir" "$branch" "$upstream"; then
    return 0
  fi

  if ((${#CURRENT_BLOCKERS[@]} > 0)); then
    finalize_blocked_result
    return 0
  fi

  if ((DRY_RUN)); then
    assess_tracking_state "$repo" "$branch" "$upstream" "dry-run"
    return 0
  fi

  # Ejecución de fetch
  fetch_output=$(git -C "$repo" fetch --all --prune 2>&1)
  if (($? != 0)); then
    classify_git_failure "fetch --all --prune" "$repo" "$fetch_output"
    return 0
  fi

  if ! assess_tracking_state "$repo" "$branch" "$upstream" "normal"; then
    return 0
  fi

  if [[ "$CURRENT_STATUS" == "BLOCKED" || "$CURRENT_STATUS" == "ERROR" || "$CURRENT_STATUS" == "UP-TO-DATE" ]]; then
    return 0
  fi

  # Ejecución de pull --ff-only
  pull_output=$(git -C "$repo" pull --ff-only 2>&1)
  if (($? != 0)); then
    classify_git_failure "pull --ff-only" "$repo" "$pull_output"
    return 0
  fi

  CURRENT_STATUS="UPDATED"
  CURRENT_SUMMARY="La rama '$branch' se ha actualizado correctamente desde '$upstream'."
}

# ==============================================================================
# IMPRESIÓN Y REGISTRO DE RESULTADOS
# ==============================================================================
format_report() {
  local repo="$1"
  local status="$2"
  local summary="$3"
  local details="$4"
  local guidance="$5"
  local output="$6"

  printf 'Repo: %s\n' "$repo"
  printf 'Estado: %s\n' "$status"
  printf 'Resumen: %s\n' "$summary"

  if [[ -n "$details" ]]; then
    printf 'Problemas detectados:\n'
    indent_block '  ' "$details"
  fi
  if [[ -n "$guidance" ]]; then
    printf 'Guia de resolucion:\n'
    indent_block '  ' "$guidance"
  fi
  if [[ -n "$output" ]]; then
    printf 'Detalle Git:\n'
    indent_block '  ' "$output"
  fi
}

record_result() {
  local repo="$1"
  case "$CURRENT_STATUS" in
    UPDATED)
      ((UPDATED_COUNT += 1))
      ;;
    UP-TO-DATE)
      ((UP_TO_DATE_COUNT += 1))
      ;;
    WOULD-UPDATE)
      ((WOULD_UPDATE_COUNT += 1))
      ;;
    BLOCKED)
      ((BLOCKED_COUNT += 1))
      BLOCKED_REPORTS+=("$(format_report "$repo" "$CURRENT_STATUS" "$CURRENT_SUMMARY" "$CURRENT_DETAILS" "$CURRENT_GUIDANCE" "$CURRENT_OUTPUT")")
      ;;
    ERROR)
      ((ERROR_COUNT += 1))
      ERROR_REPORTS+=("$(format_report "$repo" "$CURRENT_STATUS" "$CURRENT_SUMMARY" "$CURRENT_DETAILS" "$CURRENT_GUIDANCE" "$CURRENT_OUTPUT")")
      ;;
  esac
}

print_current_result() {
  case "$CURRENT_STATUS" in
    UPDATED)
      printf '  %bUPDATED:%b %s\n' "$GREEN" "$NC" "$CURRENT_SUMMARY"
      ;;
    UP-TO-DATE)
      printf '  %bUP-TO-DATE:%b %s\n' "$GREEN" "$NC" "$CURRENT_SUMMARY"
      ;;
    WOULD-UPDATE)
      printf '  %bWOULD-UPDATE:%b %s\n' "$CYAN" "$NC" "$CURRENT_SUMMARY"
      ;;
    BLOCKED)
      printf '  %bBLOCKED:%b %s\n' "$YELLOW" "$NC" "$CURRENT_SUMMARY"
      ;;
    ERROR)
      printf '  %bERROR:%b %s\n' "$RED" "$NC" "$CURRENT_SUMMARY"
      ;;
    *)
      printf '  %bERROR:%b estado interno no reconocido.\n' "$RED" "$NC"
      ;;
  esac
}

print_summary() {
  echo -e "\n${BOLD}${BLUE}======================================================================${NC}"
  echo -e "${BOLD}${BLUE}                         RESUMEN DE OPERACIONES                       ${NC}"
  echo -e "${BOLD}${BLUE}======================================================================${NC}"

  if ((DRY_RUN)); then
    echo -e "  ${CYAN}WOULD-UPDATE :${NC} $WOULD_UPDATE_COUNT"
  else
    echo -e "  ${GREEN}UPDATED      :${NC} $UPDATED_COUNT"
  fi
  echo -e "  ${GREEN}UP-TO-DATE   :${NC} $UP_TO_DATE_COUNT"
  if ((CLONE_NEW)); then
    echo -e "  ${MAGENTA}CLONED (NEW) :${NC} $CLONED_COUNT"
  fi
  echo -e "  ${YELLOW}BLOCKED      :${NC} $BLOCKED_COUNT"
  echo -e "  ${RED}ERROR        :${NC} $ERROR_COUNT"
  echo -e "${BOLD}${BLUE}======================================================================${NC}"

  if ((${#BLOCKED_REPORTS[@]} > 0)); then
    echo -e "\n${BOLD}${YELLOW}=== REPOSITORIOS BLOQUEADOS (ACCIONES MANUALES PENDIENTES) ===${NC}"
    for report in "${BLOCKED_REPORTS[@]}"; do
      printf '\n%s\n' "$report"
    done
  fi

  if ((${#ERROR_REPORTS[@]} > 0)); then
    echo -e "\n${BOLD}${RED}=== REPOSITORIOS CON ERROR ===${NC}"
    for report in "${ERROR_REPORTS[@]}"; do
      printf '\n%s\n' "$report"
    done
  fi
}

# ==============================================================================
# BARRIDO Y EJECUCIÓN PRINCIPAL
# ==============================================================================
main() {
  echo -e "${BOLD}Directorio base:${NC} $BASE_DIR"
  echo -e "${BOLD}Proyectos seleccionados (${#TARGET_PROJECTS[@]}):${NC} ${CYAN}${TARGET_PROJECTS[*]}${NC}"
  if ((DRY_RUN)); then
    echo -e "${YELLOW}Modo dry-run activo: no se ejecutará fetch ni pull.${NC}"
  fi
  echo ""

  for project in "${TARGET_PROJECTS[@]}"; do
    local proj_dir="$BASE_DIR/$project"
    
    # 1. Comprobar y clonar nuevos repos si está solicitado
    if ((CLONE_NEW)); then
      check_and_clone_new_repos "$project"
      if ((CAPTCHA_ABORT)); then
        echo -e "\n${BOLD}${RED}Deteniendo el proceso debido al bloqueo por CAPTCHA en Bitbucket.${NC}"
        break
      fi
    fi

    # 2. Descubrir repos locales dentro del proyecto (excluyendo $BASE_DIR y .git corruptos)
    local -a repos=()
    local git_entry
    local repo_path

    while IFS= read -r git_entry; do
      [[ -n "$git_entry" ]] || continue
      repo_path=$(dirname "$git_entry")
      # Excluir la raíz y validar que sea un working tree real
      if [[ "$repo_path" != "$BASE_DIR" ]] && git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Filtrar por servicio si aplica
        if [[ -n "$SERVICE_FILTER" && "$(basename "$repo_path")" != *"$SERVICE_FILTER"* ]]; then
          continue
        fi
        repos+=("$repo_path")
      fi
    done < <(find "$proj_dir" -mindepth 2 -maxdepth 3 \( -type d -name .git -prune -print \) -o \( -type f -name .git -print \) | sort -u)

    echo -e "\n${BOLD}${CYAN}📁 PROYECTO: ${project} (${#repos[@]} repositorios locales a refrescar)${NC}"

    local idx=0
    for repo in "${repos[@]}"; do
      ((idx += 1))
      printf '\n[%s/%s] %s\n' "$idx" "${#repos[@]}" "$repo"
      process_repo "$repo"
      print_current_result
      record_result "$repo"

      # Si se detecta bloqueo por CAPTCHA, consultar o abortar para no seguir bloqueando la cuenta
      if ((CAPTCHA_ABORT)); then
        echo -e "\n${BOLD}${RED}⚠️ Deteniendo la ejecución para no prolongar el bloqueo de tu cuenta Bitbucket.${NC}"
        echo -e "${YELLOW}Por favor, resuelve el CAPTCHA en https://${SERVER} antes de reintentar.${NC}"
        break 2
      fi
    done
  done

  print_summary

  if ((BLOCKED_COUNT > 0 || ERROR_COUNT > 0)); then
    exit 1
  fi
  exit 0
}

main "$@"
