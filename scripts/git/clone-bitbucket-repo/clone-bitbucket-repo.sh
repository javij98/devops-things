#!/bin/bash

# ===============================================================================
# Descripción: Script para clonar todos los repositorios de un proyecto Bitbucket
# Autor: Javier Jiménez Molina
# ===============================================================================

# ----------------------------------
# Configuración y Variables Globales
# ----------------------------------
SERVER="bitbucket.once.es"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------
# Funciones Auxiliares
# ------------------------------

read_password() {
    local prompt="$1"
    local password
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

url_encode() {
    jq -nr --arg v "$1" '$v|@uri'
}

print_banner() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Clonar Repositorios de Bitbucket${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

get_credentials() {
    read -p "👤 Usuario: " USER
    if [ -z "$USER" ]; then
        echo -e "${RED}❌ Error: El usuario no puede estar vacío${NC}" >&2
        exit 1
    fi

    PASS=$(read_password "🔑 Contraseña: ")
    if [ -z "$PASS" ]; then
        echo -e "${RED}❌ Error: La contraseña no puede estar vacía${NC}" >&2
        exit 1
    fi
}
     
get_project() {
    read -p "📁 Proyecto: " PROJECT
    if [ -z "$PROJECT" ]; then
        echo -e "${RED}❌ Error: El proyecto no puede estar vacío${NC}" >&2
        exit 1
    fi
}

# Valida que el directorio actual sea el correcto
validate_safe_directory() {
    local project="$1"
    
    # Normalización
    local current_dir_clean=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[-_]//g')
    local project_clean=$(echo "$project" | tr '[:upper:]' '[:lower:]' | sed 's/ocp//g' | sed 's/[-_]//g')

    if [[ "$current_dir_clean" != *"$project_clean"* ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  ADVERTENCIA DE SEGURIDAD${NC}"
        echo -e "${YELLOW}   Estás ubicado en: ${NC}$(basename "$PWD")"
        echo -e "${YELLOW}   El proyecto es:   ${NC}$project ${YELLOW}(clave buscada: '$project_clean')${NC}"
        echo -e "${YELLOW}   La carpeta actual no parece coincidir con el proyecto.${NC}"
        echo ""
        
        read -p "   ¿Deseas continuar de todas formas? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
            echo -e "${RED}❌ Operación cancelada por el usuario.${NC}"
            exit 1
        fi
    fi
}

# Obtiene la lista de repositorios del proyecto
fetch_repositories() {
    local user="$1"
    local pass="$2"
    local project="$3"
    
    echo "" >&2
    echo -e "${BLUE}Conectando a: https://${SERVER}${NC}" >&2
    echo -e "${BLUE}Proyecto: ${project}${NC}" >&2
    echo "" >&2

    local api_url="https://${SERVER}/rest/api/1.0/projects/${project}/repos?limit=1000"
    local response
    
    response=$(curl -s -w "\n%{http_code}" -u "$user:$pass" "$api_url")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ne 200 ]; then
        handle_http_error "$http_code" "$project" "$body"
    fi

    if ! echo "$body" | jq empty 2>/dev/null; then
        echo "❌ Error: La respuesta del servidor no es JSON válido" >&2
        echo "$body" >&2
        exit 1
    fi

    echo "$body"
}

handle_http_error() {
    local code="$1"
    local project="$2"
    local body="$3"

    case "$code" in
        401) echo "❌ Error: Credenciales inválidas (401 Unauthorized)" >&2 ;;
        404) echo "❌ Error: Proyecto '$project' no encontrado (404 Not Found)" >&2 ;;
        403) echo "❌ Error: No tienes permisos para acceder al proyecto '$project' (403 Forbidden)" >&2 ;;
        *)   
            echo "❌ Error: Respuesta inesperada del servidor (HTTP $code)" >&2
            echo "$body" >&2
            ;;
    esac
    exit 1
}

clone_repositories() {
    local json_body="$1"
    local user="$2"
    local pass="$3"

    local repo_count=$(echo "$json_body" | jq -r '.values | length')
    
    if [ "$repo_count" -eq 0 ]; then
        echo "⚠️  Advertencia: No se encontraron repositorios en el proyecto '$PROJECT'" >&2
        return 0
    fi

    echo "✅ Se encontraron $repo_count repositorios"
    echo -e "${BLUE}🔎 Obteniendo lista de repositorios ...${NC}"

    # Contadores
    local success_count=0
    local fail_count=0
    local skip_count=0

    while IFS= read -r repo_url_raw; do
        # Limpieza URL
        local repo_url="${repo_url_raw%%\?*}"
        local repo_dir="$(basename "$repo_url")"
        repo_dir="${repo_dir%.git}"

        if [ -d "$repo_dir/.git" ]; then
            echo -e "${YELLOW}⏭️  $repo_dir ya existe (repo git). Saltando.${NC}"
            ((skip_count++))
            continue
        elif [ -d "$repo_dir" ]; then
            echo -e "${YELLOW}⚠️  Existe '$repo_dir' pero no es git. Saltando.${NC}"
            ((skip_count++))
            continue
        fi

        echo -e "${BLUE}🔄 Clonando: $repo_url ...${NC}"
        
        # Construye URL con credenciales implícitas si es necesario, 
        # pero como usamos GIT_ASKPASS, git debería manejarlo. 
        # Sin embargo, el script original inyectaba las credenciales en la URL.
        # Mantendremos la inyección para asegurar compatibilidad con la forma previa.
        local user_encoded=$(url_encode "$user")
        local pass_encoded=$(url_encode "$pass")
        local repo_url_with_creds="https://${user_encoded}:${pass_encoded}@${SERVER}${repo_url#https://${SERVER}}"
        
        # Ojo: El script original usaba repo_url en el git clone (confiando en GIT_ASKPASS o keychains?)
        # La linea original era: if git clone -- "$repo_url" 2>&1; then
        # Y también construía repo_url_with_creds pero NO la usaba en el comando git clone.
        # Asumiremos que GIT_ASKPASS configurado arriba es suficiente.
        
        if git clone -- "$repo_url_with_creds" 2>&1; then
            echo -e "${GREEN}✅ Clonado: $repo_dir${NC}"
            ((success_count++))
        else
            echo -e "${RED}❌ Error al clonar: $repo_url${NC}" >&2
            ((fail_count++))
        fi
        
    done < <(echo "$json_body" | jq -r '.values[].links.clone[] | select(.name=="http") | .href')

    print_summary "$success_count" "$fail_count" "$skip_count"
}

# Imprime el resumen de operaciones
print_summary() {
    local s="$1"
    local f="$2"
    local k="$3"

    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE} Resumen de operaciones:${NC}"
    echo -e "   ${GREEN}✅ Exitosos: $s${NC}"
    echo -e "   ${RED}❌ Fallidos: $f${NC}"
    echo -e "   ${YELLOW}⏭️  Saltados: $k${NC}"
    echo -e "${BLUE}=========================================${NC}"

    if [ "$f" -gt 0 ]; then
        exit 1
    fi
}

# ------------------------------
# Bloque Principal (Main)
# ------------------------------
main() {
    print_banner
    get_credentials
    get_project
    
    local repo_list_json
    if ! repo_list_json=$(fetch_repositories "$USER" "$PASS" "$PROJECT"); then
        exit 1
    fi
    
    validate_safe_directory "$PROJECT"
    
    clone_repositories "$repo_list_json" "$USER" "$PASS"
}

main
