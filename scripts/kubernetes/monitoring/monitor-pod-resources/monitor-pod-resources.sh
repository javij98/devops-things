#!/bin/bash

# Configuration
NS="jenkins-ocp"
CTX="infraestructure"
INTERVAL=1
POD_NAME_PATTERN="-build-"
SERVICES=""
PROJECT=""

# Tracking variables (per pod)
declare -A max_cpu
declare -A max_mem
declare -A seen_pods
declare -A pod_node
declare -A node_cpu_pct
declare -A node_mem_pct
declare -A max_node_cpu_pct
declare -A max_node_mem_pct
declare -a pods
last_lines=0
POD_COL_WIDTH=62
METRIC_COL_WIDTH=10
NODE_COL_WIDTH=12

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
Usage: $(basename "$0") [-n namespace] [-c context] [-i seconds] [-p pod_name_pattern] [-s services] [-P project]

Options:
  -n  Namespace (default: $NS)
  -c  kubectl context (default: $CTX)
  -i  Refresh interval in seconds (default: $INTERVAL)
  -p  Pod name regex pattern (default: $POD_NAME_PATTERN)
    -s  Service name(s), comma-separated (example: user-service,purchase-service)
    -P  Project filter (2nd token in pod name, example: apijo, quiosp)
  -h  Show help
EOF
}

while getopts ":n:c:i:p:s:P:h" opt; do
    case "$opt" in
        n) NS="$OPTARG" ;;
        c) CTX="$OPTARG" ;;
        i) INTERVAL="$OPTARG" ;;
        p) POD_NAME_PATTERN="$OPTARG" ;;
        s) SERVICES="$OPTARG" ;;
        P) PROJECT="$OPTARG" ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Error: invalid option -$OPTARG"
            usage
            exit 1
            ;;
        :)
            echo "Error: missing value for -$OPTARG"
            usage
            exit 1
            ;;
    esac
done

# Check if interval is a valid positive number
if ! [[ "$INTERVAL" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ "$INTERVAL" == "0" || "$INTERVAL" == "0.0" ]]; then
    echo "Error: interval must be a number greater than 0."
    exit 1
fi

load_pods_and_nodes() {
    pods=()
    pod_node=()

    while read -r pod phase node; do
        [[ -z "$pod" || "$phase" != "Running" ]] && continue
        echo "$pod" | grep -Eq -- "$POD_NAME_PATTERN" || continue
        pod_matches_project "$pod" || continue
        pod_matches_service "$pod" || continue

        pods+=("$pod")
        pod_node["$pod"]="${node:-N/A}"
    done < <(
        kubectl --context "$CTX" get pods -n "$NS" \
            -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName \
            --no-headers 2>/dev/null
    )
}

pod_matches_project() {
    local pod="$1"
    local project_in_name

    [[ -z "$PROJECT" ]] && return 0

    IFS='-' read -r _ project_in_name _ <<<"$pod"
    [[ -n "$project_in_name" && "$project_in_name" == "$PROJECT" ]]
}

pod_matches_service() {
    local pod="$1"

    if [[ -z "$SERVICES" ]]; then
        return 0
    fi

    IFS=',' read -r -a service_list <<<"$SERVICES"
    for service in "${service_list[@]}"; do
        service="${service#${service%%[![:space:]]*}}"
        service="${service%${service##*[![:space:]]}}"
        [[ -z "$service" ]] && continue

        if [[ "$pod" == *"-build-${service}-"* ]]; then
            return 0
        fi
    done

    return 1
}

load_top_metrics() {
    declare -gA current_cpu_by_pod
    declare -gA current_mem_by_pod

    while read -r pod cpu_raw mem_raw; do
        [[ -z "$pod" ]] && continue
        pod_matches_project "$pod" || continue
        pod_matches_service "$pod" || continue
        current_cpu_by_pod["$pod"]="${cpu_raw//[^0-9]/}"
        current_mem_by_pod["$pod"]="${mem_raw//[^0-9]/}"
    done < <(
        kubectl top pod -n "$NS" --context "$CTX" --no-headers 2>/dev/null \
            | awk -v pattern="$POD_NAME_PATTERN" '$1 ~ pattern {print $1, $2, $3}'
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
    echo "========================================"
    echo "   HISTORICAL PEAK RESULTS BY POD"
    echo "========================================"

    if ((${#seen_pods[@]} == 0)); then
        echo "No build pods were detected."
    else
        while IFS= read -r pod; do
            printf "%-70s CPU Max: %6sm | MEM Max: %8sMi\n" \
                "$pod" "${max_cpu[$pod]:-0}" "${max_mem[$pod]:-0}"
        done < <(printf "%s\n" "${!seen_pods[@]}" | sort)
    fi

    echo
    echo "========================================"
    echo "  HISTORICAL PEAK RESULTS BY NODE (%)"
    echo "========================================"
    if ((${#max_node_cpu_pct[@]} == 0)); then
        echo "No node metrics were collected."
    else
        while IFS= read -r node; do
            printf "%-40s CPU Max: %6s%% | MEM Max: %6s%%\n" \
                "$node" "${max_node_cpu_pct[$node]:-0}" "${max_node_mem_pct[$node]:-0}"
        done < <(printf "%s\n" "${!max_node_cpu_pct[@]}" | sort)
    fi

    echo "========================================"
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

handle_stop() {
    show_cursor
    print_summary
    exit 0
}

# Capture Ctrl+C / termination and restore terminal state
trap 'handle_stop' INT TERM
trap 'show_cursor' EXIT

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is not installed or not in PATH."
    exit 1
fi

hide_cursor

echo "Monitoring all running Jenkins build pods"
echo "Namespace: $NS | Context: $CTX | Name pattern: $POD_NAME_PATTERN | Refresh: ${INTERVAL}s"
if [[ -n "$SERVICES" ]]; then
    echo "Service filter: $SERVICES"
fi
if [[ -n "$PROJECT" ]]; then
    echo "Project filter: $PROJECT"
fi
echo "Press Ctrl+C to stop and see the final report..."
echo "-------------------------------------------------------"

while true; do
    cycle_start="$(date +%s)"

    load_pods_and_nodes
    load_top_metrics
    load_node_metrics

    if (( last_lines > 0 )); then
        printf "\033[%sA" "$last_lines"
    fi

    lines_printed=0

    terminal_cols="$(tput cols 2>/dev/null || echo 120)"
    fixed_cols=$(( (METRIC_COL_WIDTH * 4) + NODE_COL_WIDTH + 5 ))
    current_pod_col_width=$(( terminal_cols - fixed_cols ))
    if (( current_pod_col_width < 36 )); then
        current_pod_col_width=36
    elif (( current_pod_col_width > POD_COL_WIDTH )); then
        current_pod_col_width=$POD_COL_WIDTH
    fi

    echo "[LIVE $(date +%H:%M:%S)] Running Jenkins build pods"
    ((lines_printed++))
    echo "-------------------------------------------------------"
    ((lines_printed++))

    if ((${#pods[@]} == 0)); then
        echo "[WAITING FOR DATA...] No running build pods detected."
        ((lines_printed++))
    else
        printf "%-${current_pod_col_width}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${METRIC_COL_WIDTH}s %${NODE_COL_WIDTH}s\n" \
            "POD" "CPU" "CPU_MAX" "MEM" "MEM_MAX" "NODE"
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
        printf "%-40s %8s %12s %8s %12s\n" "NODE" "CPU%" "CPU_MAX%" "MEM%" "MEM_MAX%"
        ((lines_printed++))
        printf "%-40s %8s %12s %8s %12s\n" "----" "----" "--------" "----" "--------"
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

            printf "%-40s %7s%% %11s%% %7s%% %11s%%\n" \
                "$node" "$cpu_pct" "$cpu_max_pct" "$mem_pct" "$mem_max_pct"
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