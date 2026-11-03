#!/usr/bin/env bash
# ==============================================================================
# Real-time pod resource monitoring script in Kubernetes
# Supports monitoring Jenkins build pods (infraestructure), application microservices
# (<project>-<env>), and infrastructure services (<project>-srv) across any
# cluster environment (desarrollo, integracion, aceptacion, produccion).
# ==============================================================================

set -o pipefail

# ANSI color codes and styles
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    RED="\033[0;31m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    MAGENTA="\033[0;35m"
    NC="\033[0m" # No Color
else
    BOLD=""
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    NC=""
fi

# Configuration and default values
NS=""
CTX=""
ENTORNO=""
PROJECT=""
SERVICES=""
INTERVAL=1
POD_NAME_PATTERN=""
IS_SRV=false
INTERACTIVE=false
KUBECTL_ERROR_MSG=""

# Tracking variables for metrics
declare -A max_cpu
declare -A max_mem
declare -A seen_pods
declare -A pod_node
declare -A pod_node_history
declare -A node_cpu_pct
declare -A node_mem_pct
declare -A max_node_cpu_pct
declare -A max_node_mem_pct
declare -a pods
last_lines=0
POD_COL_WIDTH=62
METRIC_COL_WIDTH=10
NODE_COL_WIDTH=14

fit_text() {
    local text="$1"
    local width="$2"

    if (( ${#text} <= width )); then
        printf "%s" "$text"
    else
        printf "%s" "${text:0:width}"
    fi
}

usage() {
    cat <<EOF
Uso: $(basename "$0") [opciones]

Monitoriza en tiempo real el consumo de CPU y memoria de pods en Kubernetes,
registrando picos históricos tanto por pod como por nodo.

Opciones de Entorno y Aplicación:
  -e, --entorno <env>           Entorno / clúster: des, int, act, pro
  -P, --project <proyecto>      Proyecto/aplicación (ej: apijo, werese, penyas)
  --srv, --infra                Monitorizar namespace de infraestructura (<proyecto>-srv)
  -n, --namespace <nombre>      Namespace directo (ej: werese-pro, werese-srv, jenkins-ocp)
  -c, --context <contexto>      Contexto kubectl directo (ej: produccion, desarrollo)

Opciones de Filtrado y Ejecución:
  -s, --filter, --services <s>  Filtro por palabra o servicio (ej: krakend, grafana, mail)
  -p, --pattern <regex>         Expresión regular opcional en nombre de pod
  -i, --interval <segundos>     Intervalo de refresco en segundos (defecto: 1)
  -I, --interactive             Iniciar en modo interactivo guiado
  -h, --help                    Muestra esta ayuda

Si se ejecuta sin parámetros, el script iniciará automáticamente el asistente interactivo.
EOF
}

# If no arguments provided, enable interactive mode
if [[ $# -eq 0 ]]; then
    INTERACTIVE=true
fi

# Parse CLI arguments and options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--entorno)
            ENTORNO="$2"
            shift 2
            ;;
        -P|--project|--proyecto)
            PROJECT="$2"
            shift 2
            ;;
        --srv|--infra|-t)
            IS_SRV=true
            if [[ "$1" == "-t" && "$2" == "srv" ]]; then
                shift 2
            else
                shift 1
            fi
            ;;
        -n|--namespace)
            NS="$2"
            shift 2
            ;;
        -c|--context)
            CTX="$2"
            shift 2
            ;;
        -s|--services|--filter)
            SERVICES="$2"
            shift 2
            ;;
        -p|--pattern)
            POD_NAME_PATTERN="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -I|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: opción no válida '$1'${NC}" >&2
            usage
            exit 1
            ;;
    esac
done

# ==============================================================================
# GUIDED INTERACTIVE WIZARD
# ==============================================================================
if [ "$INTERACTIVE" = true ]; then
    echo -e "${BOLD}${CYAN}======================================================================${NC}"
    echo -e "${BOLD}${CYAN}  ASISTENTE DE MONITORIZACIÓN DE RECURSOS DE PODS EN TIEMPO REAL      ${NC}"
    echo -e "${BOLD}${CYAN}======================================================================${NC}"
    echo ""

    echo -e "${BOLD}1) ¿Qué ámbito deseas monitorizar?${NC}"
    echo "   1) Builds de Jenkins (contexto: infraestructure | namespace: jenkins-ocp)"
    echo "   2) Pods de Proyecto en Entorno (<proyecto>-<entorno> o <proyecto>-srv)"
    echo "   3) Configuración personalizada / manual"
    read -r -p "   Opción [1-3, ENTER para 1]: " modo_sel
    case "$modo_sel" in
        2)
            echo ""
            echo -e "${BOLD}2) Selecciona el entorno / clúster:${NC}"
            echo "   1) Desarrollo  (des) [contexto: desarrollo]"
            echo "   2) Integración (int) [contexto: integracion]"
            echo "   3) Aceptación  (act) [contexto: aceptacion]"
            echo "   4) Producción  (pro) [contexto: produccion]"
            read -r -p "   Opción [1-4 o des/int/act/pro, ENTER para 2]: " env_sel

            env_sel_lower="$(echo "${env_sel:-int}" | tr '[:upper:]' '[:lower:]')"
            case "$env_sel_lower" in
                1|des|desarrollo)
                    ENTORNO="des"
                    CTX="desarrollo"
                    ;;
                3|act|aceptacion)
                    ENTORNO="act"
                    CTX="aceptacion"
                    ;;
                4|pro|produccion)
                    ENTORNO="pro"
                    CTX="produccion"
                    ;;
                2|int|integracion|"")
                    ENTORNO="int"
                    CTX="integracion"
                    ;;
                *)
                    ENTORNO="$env_sel_lower"
                    CTX="$env_sel"
                    ;;
            esac
            echo ""

            read -r -p "3) Proyecto / Aplicación [ENTER para 'apijo']: " input_proj
            if [[ -n "$input_proj" ]]; then
                PROJECT="$input_proj"
            else
                PROJECT="apijo"
            fi
            echo ""

            echo -e "${BOLD}4) Tipo de componentes a monitorizar en ${CTX}:${NC}"
            echo "   1) Microservicios de aplicación (${PROJECT}-${ENTORNO}) [Recomendado / Defecto]"
            echo "   2) Servicios de infraestructura (${PROJECT}-srv - KrakenD, Grafana, Kafka, etc.)"
            read -r -p "   Opción [1-2 o app/srv, ENTER para 1]: " tipo_sel
            tipo_sel_lower="$(echo "${tipo_sel:-1}" | tr '[:upper:]' '[:lower:]')"
            if [[ "$tipo_sel_lower" == "2" || "$tipo_sel_lower" == "srv" || "$tipo_sel_lower" == "infra" ]]; then
                IS_SRV=true
                NS="${PROJECT}-srv"
            else
                IS_SRV=false
                NS="${PROJECT}-${ENTORNO}"
            fi
            echo -e "   ${GREEN}➜ Namespace resuelto: ${BOLD}${NS}${NC} | Contexto: ${BOLD}${CTX}${NC}"
            echo ""

            read -r -p "5) Filtrar por palabra o microservicio (ej. krakend, grafana, mail) [ENTER para todos]: " input_filter
            SERVICES="$input_filter"
            echo ""

            read -r -p "6) Intervalo de refresco en segundos [ENTER para 1]: " input_interval
            [[ -n "$input_interval" ]] && INTERVAL="$input_interval"
            echo ""
            ;;
        3)
            echo ""
            read -r -p "2) Contexto kubectl [ENTER para 'infraestructure']: " input_ctx
            CTX="${input_ctx:-infraestructure}"
            echo ""

            read -r -p "3) Namespace de Kubernetes [ENTER para 'jenkins-ocp']: " input_ns
            NS="${input_ns:-jenkins-ocp}"
            echo ""

            read -r -p "4) Filtrar por palabra o microservicio [ENTER para todos]: " input_filter
            SERVICES="$input_filter"
            echo ""

            read -r -p "5) Patrón regex opcional en nombre de pod [ENTER para ninguno]: " input_pat
            POD_NAME_PATTERN="$input_pat"
            echo ""

            read -r -p "6) Intervalo de refresco en segundos [ENTER para 1]: " input_interval
            [[ -n "$input_interval" ]] && INTERVAL="$input_interval"
            echo ""
            ;;
        1|"")
            # Jenkins Builds default
            CTX="infraestructure"
            NS="jenkins-ocp"
            POD_NAME_PATTERN="-build-"

            echo ""
            read -r -p "2) Filtrar por palabra o microservicio (ej. apijo, mail, user) [ENTER para todos]: " input_filter
            SERVICES="$input_filter"
            echo ""

            read -r -p "3) Intervalo de refresco en segundos [ENTER para 1]: " input_interval
            [[ -n "$input_interval" ]] && INTERVAL="$input_interval"
            echo ""
            ;;
    esac
fi

# Automatic context and namespace deduction when flags are used
if [[ -z "$CTX" && -n "$ENTORNO" ]]; then
    entorno_lower="$(echo "$ENTORNO" | tr '[:upper:]' '[:lower:]')"
    case "$entorno_lower" in
        des|desarrollo)     CTX="desarrollo"; ENTORNO="des" ;;
        des-srv)            CTX="desarrollo"; ENTORNO="des"; IS_SRV=true ;;
        int|integracion)    CTX="integracion"; ENTORNO="int" ;;
        int-srv)            CTX="integracion"; ENTORNO="int"; IS_SRV=true ;;
        act|aceptacion)     CTX="aceptacion"; ENTORNO="act" ;;
        act-srv)            CTX="aceptacion"; ENTORNO="act"; IS_SRV=true ;;
        pro|produccion)     CTX="produccion"; ENTORNO="pro" ;;
        pro-srv)            CTX="produccion"; ENTORNO="pro"; IS_SRV=true ;;
        srv)                CTX="produccion"; ENTORNO="srv"; IS_SRV=true ;;
        *)                  CTX="$ENTORNO" ;;
    esac
fi

if [[ -z "$NS" ]]; then
    if [[ -n "$PROJECT" ]]; then
        if [ "$IS_SRV" = true ]; then
            NS="${PROJECT}-srv"
        elif [[ -n "$ENTORNO" ]]; then
            NS="${PROJECT}-${ENTORNO}"
        else
            NS="${PROJECT}-int"
        fi
    elif [[ "$CTX" == "infraestructure" || -z "$CTX" ]]; then
        CTX="infraestructure"
        NS="jenkins-ocp"
        [[ -z "$POD_NAME_PATTERN" ]] && POD_NAME_PATTERN="-build-"
    else
        NS="default"
    fi
fi

[[ -z "$CTX" ]] && CTX="infraestructure"

# Normalize context aliases
case "$(echo "$CTX" | tr '[:upper:]' '[:lower:]')" in
    des) CTX="desarrollo" ;;
    int) CTX="integracion" ;;
    act) CTX="aceptacion" ;;
    pro) CTX="produccion" ;;
esac

# Validate interval
if ! [[ "$INTERVAL" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ "$INTERVAL" == "0" || "$INTERVAL" == "0.0" ]]; then
    echo -e "${RED}Error: el intervalo debe ser un número mayor a 0.${NC}" >&2
    exit 1
fi

# Verify kubectl binary exists
if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}Error: kubectl no está instalado o no se encuentra en el PATH.${NC}" >&2
    exit 1
fi

# ==============================================================================
# FILTERING AND METRIC LOADING FUNCTIONS
# ==============================================================================

# Flexible case-insensitive substring filter for pod names
pod_matches_filter() {
    local pod="$1"

    [[ -z "$SERVICES" ]] && return 0

    local pod_lower
    pod_lower="$(echo "$pod" | tr '[:upper:]' '[:lower:]')"

    IFS=',' read -r -a term_list <<<"$SERVICES"
    for term in "${term_list[@]}"; do
        term="${term#${term%%[![:space:]]*}}"
        term="${term%${term##*[![:space:]]}}"
        [[ -z "$term" ]] && continue

        local term_lower
        term_lower="$(echo "$term" | tr '[:upper:]' '[:lower:]')"

        if [[ "$pod_lower" == *"$term_lower"* ]]; then
            return 0
        fi
    done

    return 1
}

load_pods_and_nodes() {
    pods=()
    pod_node=()
    KUBECTL_ERROR_MSG=""

    local raw_output
    local exit_code
    raw_output="$(kubectl --context "$CTX" get pods -n "$NS" \
        -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName \
        --no-headers 2>&1)"
    exit_code=$?

    if (( exit_code != 0 )); then
        KUBECTL_ERROR_MSG="$(echo "$raw_output" | head -n 1)"
        return
    fi

    while read -r pod phase node; do
        [[ -z "$pod" || "$phase" != "Running" ]] && continue
        
        if [[ -n "$POD_NAME_PATTERN" ]]; then
            echo "$pod" | grep -Eq -- "$POD_NAME_PATTERN" || continue
        fi

        pod_matches_filter "$pod" || continue

        pods+=("$pod")
        pod_node["$pod"]="${node:-N/A}"
    done <<< "$raw_output"
}

load_top_metrics() {
    declare -gA current_cpu_by_pod
    declare -gA current_mem_by_pod

    while read -r pod cpu_raw mem_raw; do
        [[ -z "$pod" ]] && continue
        if [[ -n "$POD_NAME_PATTERN" ]]; then
            echo "$pod" | grep -Eq -- "$POD_NAME_PATTERN" || continue
        fi
        pod_matches_filter "$pod" || continue

        current_cpu_by_pod["$pod"]="${cpu_raw//[^0-9]/}"
        current_mem_by_pod["$pod"]="${mem_raw//[^0-9]/}"
    done < <(
        kubectl top pod -n "$NS" --context "$CTX" --no-headers 2>/dev/null
    )
}

load_node_metrics() {
    node_cpu_pct=()
    node_mem_pct=()

    while read -r node _cpu cpu_pct _mem mem_pct; do
        [[ -z "$node" ]] && continue
        node_cpu_pct["$node"]="${cpu_pct//[^0-9]/}"
        node_mem_pct["$node"]="${mem_pct//[^0-9]/}"
    done < <(kubectl top node --context "$CTX" --no-headers 2>/dev/null)
}

print_summary() {
    echo
    echo
    echo -e "${BOLD}${BLUE}========================================================================================${NC}"
    echo -e "${BOLD}${BLUE}                    RESUMEN FINAL DE PICOS MÁXIMOS POR POD                             ${NC}"
    echo -e "${BOLD}${BLUE}========================================================================================${NC}"

    if ((${#seen_pods[@]} == 0)); then
        echo "No se detectaron pods en ejecución durante la sesión con los filtros indicados."
    else
        while IFS= read -r pod; do
            node_name="${pod_node_history[$pod]:-N/A}"
            c_max="${max_cpu[$pod]:-0}"
            m_max="${max_mem[$pod]:-0}"
            printf "%-65s Nodo: %-15s | CPU Máx: %6sm | MEM Máx: %8sMi\n" \
                "$pod" "$node_name" "$c_max" "$m_max"
        done < <(printf "%s\n" "${!seen_pods[@]}" | sort)
    fi

    echo
    echo -e "${BOLD}${BLUE}========================================================================================${NC}"
    echo -e "${BOLD}${BLUE}                    RESUMEN FINAL DE PICOS MÁXIMOS POR NODO (%)                        ${NC}"
    echo -e "${BOLD}${BLUE}========================================================================================${NC}"
    if ((${#max_node_cpu_pct[@]} == 0)); then
        echo "No se recolectaron métricas de nodos en este contexto."
    else
        while IFS= read -r node; do
            c_max_pct="${max_node_cpu_pct[$node]:-0}"
            m_max_pct="${max_node_mem_pct[$node]:-0}"
            printf "%-40s CPU Máx: %6s%% | MEM Máx: %6s%%\n" \
                "$node" "$c_max_pct" "$m_max_pct"
        done < <(printf "%s\n" "${!max_node_cpu_pct[@]}" | sort)
    fi

    echo -e "${BOLD}${BLUE}========================================================================================${NC}"
}

hide_cursor() {
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        tput civis
    fi
}

show_cursor() {
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        tput cnorm
    fi
}

save_cursor_pos() {
    if command -v tput >/dev/null 2>&1; then
        tput sc
    else
        printf "\033[s"
    fi
}

restore_cursor_pos() {
    if command -v tput >/dev/null 2>&1; then
        tput rc
    else
        printf "\033[u"
    fi
}

handle_stop() {
    show_cursor
    print_summary
    exit 0
}

# Signal traps to restore terminal state
trap 'handle_stop' INT TERM
trap 'show_cursor' EXIT

hide_cursor

echo -e "${BOLD}${CYAN}Monitorizando pods en Kubernetes${NC}"
echo -e "Contexto: ${BOLD}${CTX}${NC} | Namespace: ${BOLD}${NS}${NC} | Refresco: ${BOLD}${INTERVAL}s${NC}"
if [[ -n "$SERVICES" ]]; then
    echo -e "Filtro por palabra/servicio: ${BOLD}${SERVICES}${NC}"
fi
if [[ -n "$POD_NAME_PATTERN" ]]; then
    echo -e "Patrón regex: ${BOLD}${POD_NAME_PATTERN}${NC}"
fi
echo -e "${YELLOW}Presiona Ctrl+C para detener y ver el informe de picos máximos...${NC}"
echo "----------------------------------------------------------------------------------------"

save_cursor_pos

while true; do
    cycle_start="$(date +%s)"

    load_pods_and_nodes
    load_top_metrics
    load_node_metrics

    restore_cursor_pos

    lines_printed=0

    terminal_cols="$(tput cols 2>/dev/null || echo 120)"
    [[ "$terminal_cols" =~ ^[0-9]+$ ]] || terminal_cols=120
    safe_cols=$(( terminal_cols - 2 ))
    if (( safe_cols < 1 )); then
        safe_cols=1
    fi

    pod_fixed_cols=$(( (METRIC_COL_WIDTH * 4) + NODE_COL_WIDTH + 5 ))
    min_pod_col_width=3
    narrow_terminal=0

    if (( safe_cols < (pod_fixed_cols + min_pod_col_width) )); then
        narrow_terminal=1
    else
        current_pod_col_width=$(( safe_cols - pod_fixed_cols ))
        if (( current_pod_col_width > POD_COL_WIDTH )); then
            current_pod_col_width=$POD_COL_WIDTH
        fi
    fi

    node_fixed_cols=44
    node_name_col_width=$(( safe_cols - node_fixed_cols ))
    if (( node_name_col_width < 4 )); then
        node_name_col_width=4
    elif (( node_name_col_width > 40 )); then
        node_name_col_width=40
    fi

    echo -e "[${BOLD}EN VIVO $(date +%H:%M:%S)${NC}] Pods activos en ${BOLD}${NS}${NC} (${CTX})"
    ((lines_printed++))
    echo "----------------------------------------------------------------------------------------"
    ((lines_printed++))

    if [[ -n "$KUBECTL_ERROR_MSG" ]]; then
        echo -e "${RED}[ERROR KUBECTL] ${KUBECTL_ERROR_MSG}${NC}"
        ((lines_printed++))
        echo -e "${YELLOW}Verifica que el contexto '${CTX}' y el namespace '${NS}' sean correctos.${NC}"
        ((lines_printed++))
        printf "\033[J"
        last_lines=$lines_printed
        sleep "$INTERVAL"
        continue
    fi

    if (( narrow_terminal == 1 )); then
        echo "[TERMINAL ESTRECHA ${terminal_cols} cols] pods:${#pods[@]} amplía la ventana del terminal"
        ((lines_printed++))
        printf "\033[J"
        last_lines=$lines_printed

        elapsed=$(( $(date +%s) - cycle_start ))
        sleep_for="$INTERVAL"
        if [[ "$INTERVAL" =~ ^[0-9]+$ ]] && (( elapsed < INTERVAL )); then
            sleep_for=$(( INTERVAL - elapsed ))
        elif [[ "$INTERVAL" =~ ^[0-9]+$ ]] && (( elapsed >= INTERVAL )); then
            sleep_for=0
        fi

        sleep "$sleep_for"
        continue
    fi

    if ((${#pods[@]} == 0)); then
        echo -e "${YELLOW}[ESPERANDO DATOS...] No se detectaron pods en estado Running con los filtros actuales.${NC}"
        ((lines_printed++))
    else
        printf "${BOLD}%-${current_pod_col_width}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${NODE_COL_WIDTH}s${NC}\n" \
            "POD" "CPU" "CPU_MAX" "MEM" "MEM_MAX" "NODO"
        ((lines_printed++))
        printf "%-${current_pod_col_width}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${NODE_COL_WIDTH}s\n" \
            "---" "---" "-------" "---" "-------" "----"
        ((lines_printed++))

        unset active_nodes
        declare -A active_nodes

        for pod in "${pods[@]}"; do
            seen_pods["$pod"]=1

            current_cpu="${current_cpu_by_pod[$pod]:-}"
            current_mem="${current_mem_by_pod[$pod]:-}"

            cpu_max="${max_cpu[$pod]:-0}"
            mem_max="${max_mem[$pod]:-0}"
            node_name="${pod_node[$pod]:-N/A}"
            pod_display="$(fit_text "$pod" "$current_pod_col_width")"
            node_display="$(fit_text "$node_name" "$NODE_COL_WIDTH")"
            [[ "$node_name" != "N/A" ]] && active_nodes["$node_name"]=1
            [[ "$node_name" != "N/A" ]] && pod_node_history["$pod"]="$node_name"

            if [[ -n "$current_cpu" && -n "$current_mem" ]]; then
                (( current_cpu > cpu_max )) && cpu_max=$current_cpu
                (( current_mem > mem_max )) && mem_max=$current_mem
                max_cpu["$pod"]=$cpu_max
                max_mem["$pod"]=$mem_max

                cpu_now_display="${current_cpu}m"
                cpu_max_display="${cpu_max}m"
                mem_now_display="${current_mem}Mi"
                mem_max_display="${mem_max}Mi"

                printf "%-${current_pod_col_width}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${NODE_COL_WIDTH}s\n" \
                    "$pod_display" "$cpu_now_display" "$cpu_max_display" "$mem_now_display" "$mem_max_display" "$node_display"
            else
                cpu_max_display="${cpu_max}m"
                mem_max_display="${mem_max}Mi"

                printf "%-${current_pod_col_width}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${NODE_COL_WIDTH}s\n" \
                    "$pod_display" "N/A" "$cpu_max_display" "N/A" "$mem_max_display" "$node_display"
            fi
            ((lines_printed++))
        done

        echo
        ((lines_printed++))
        printf "${BOLD}%-${node_name_col_width}s %8s %12s %8s %12s${NC}\n" "NODO" "CPU%" "CPU_MAX%" "MEM%" "MEM_MAX%"
        ((lines_printed++))
        printf "%-${node_name_col_width}s %8s %12s %8s %12s\n" "----" "----" "--------" "----" "--------"
        ((lines_printed++))

        while IFS= read -r node; do
            [[ -z "$node" ]] && continue
            cpu_pct="${node_cpu_pct[$node]:-N/A}"
            mem_pct="${node_mem_pct[$node]:-N/A}"

            cpu_max_pct="${max_node_cpu_pct[$node]:-0}"
            mem_max_pct="${max_node_mem_pct[$node]:-0}"

            [[ "$cpu_pct" =~ ^[0-9]+$ ]] && (( cpu_pct > cpu_max_pct )) && cpu_max_pct="$cpu_pct"
            [[ "$mem_pct" =~ ^[0-9]+$ ]] && (( mem_pct > mem_max_pct )) && mem_max_pct="$mem_pct"

            max_node_cpu_pct["$node"]="$cpu_max_pct"
            max_node_mem_pct["$node"]="$mem_max_pct"
            node_display="$(fit_text "$node" "$node_name_col_width")"

            printf "%-${node_name_col_width}s %7s%% %11s%% %7s%% %11s%%\n" \
                "$node_display" "$cpu_pct" "$cpu_max_pct" "$mem_pct" "$mem_max_pct"
            ((lines_printed++))
        done < <(printf "%s\n" "${!active_nodes[@]}" | sort)
    fi

    printf "\033[J"
    last_lines=$lines_printed

    elapsed=$(( $(date +%s) - cycle_start ))
    sleep_for="$INTERVAL"

    if [[ "$INTERVAL" =~ ^[0-9]+$ ]] && (( elapsed < INTERVAL )); then
        sleep_for=$(( INTERVAL - elapsed ))
    elif [[ "$INTERVAL" =~ ^[0-9]+$ ]] && (( elapsed >= INTERVAL )); then
        sleep_for=0
    fi

    sleep "$sleep_for"
done
