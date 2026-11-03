#!/usr/bin/env bash
# ==============================================================================
# Audit script for HorizontalPodAutoscaler (HPA) vs Deployments in K8s
# Validates compliance with the corporate 80% autoscaling rule:
#   target_cpu    = ceil(80 * limits.cpu / requests.cpu)
#   target_memory = ceil(80 * limits.memory / requests.memory)
# ==============================================================================

set -o pipefail

# Colors and formats (only if output is an interactive terminal)
if [ -t 1 ]; then
  BOLD="\033[1m"
  GREEN="\033[0;32m"
  RED="\033[0;31m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  CYAN="\033[0;36m"
  NC="\033[0m" # No Color
else
  BOLD=""
  GREEN=""
  RED=""
  YELLOW=""
  BLUE=""
  CYAN=""
  NC=""
fi

# Default variables
ENTORNO=""
PROYECTO="apijo"
SERVICE_FILTER=""
SHOW_ALL="false"

usage() {
  echo -e "${BOLD}Uso:${NC} $(basename "$0") [opciones] [entorno] [proyecto]

${BOLD}Opciones:${NC}
  -e, --entorno <entorno>       Entorno a auditar: des, int, act, pro, all
  -p, --proyecto <proyecto>     Prefijo de proyecto/aplicación (defecto: apijo)
  -s, --servicio <nombre>       Filtrar por nombre de microservicio (opcional)
  -a, --all                     Mostrar todos los componentes (no solo discrepancias)
  -h, --help                    Muestra esta ayuda

Si se ejecuta sin parámetros, el script entrará en ${BOLD}modo interactivo guiado${NC}."
  exit 0
}

# Argument parsing with flags if provided
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--entorno)
      ENTORNO="$2"
      shift 2
      ;;
    -p|--proyecto)
      PROYECTO="$2"
      shift 2
      ;;
    -s|--servicio)
      SERVICE_FILTER="$2"
      shift 2
      ;;
    -a|--all)
      SHOW_ALL="true"
      shift
      ;;
    -h|--help)
      usage
      ;;
    int|integracion|act|aceptacion|pro|produccion|des|desarrollo|all|todos)
      ENTORNO="$1"
      shift
      ;;
    *)
      if [ -z "$ENTORNO" ]; then
        ENTORNO="$1"
      elif [ -z "$PROYECTO" ] || [ "$PROYECTO" = "apijo" ]; then
        PROYECTO="$1"
      fi
      shift
      ;;
  esac
done

# ==============================================================================
# INTERACTIVE MODE (if environment was not provided)
# ==============================================================================
if [ -z "$ENTORNO" ]; then
  echo -e "${BOLD}${CYAN}======================================================================${NC}"
  echo -e "${BOLD}${CYAN}      AUDITORÍA DE AUTOSCALING EN KUBERNETES (REGLA DEL 80%)          ${NC}"
  echo -e "${BOLD}${CYAN}======================================================================${NC}"
  echo ""
  
  # 1. Prompt Environment
  echo -e "${BOLD}1) Selecciona el entorno que deseas auditar:${NC}"
  echo "   1) Desarrollo  (des) [contexto: desarrollo]"
  echo "   2) Integración (int) [contexto: integracion]"
  echo "   3) Aceptación  (act) [contexto: aceptacion]"
  echo "   4) Producción  (pro) [contexto: produccion]"
  echo "   5) Todos los entornos (des, int, act, pro)"
  read -r -p "   Elige una opción [1-5] (por defecto: 2 - Integración): " opt_env
  
  case "${opt_env:-2}" in
    1|des|desarrollo)  ENTORNO="des" ;;
    2|int|integracion) ENTORNO="int" ;;
    3|act|aceptacion)  ENTORNO="act" ;;
    4|pro|produccion)  ENTORNO="pro" ;;
    5|all|todos)       ENTORNO="all" ;;
    *) echo -e "${RED}Opción no válida. Se usará 'int'.${NC}"; ENTORNO="int" ;;
  esac
  echo ""

  # 2. Prompt Project / Application
  read -r -p "2) Proyecto / Aplicación [ENTER para '${PROYECTO}']: " input_proj
  if [ -n "$input_proj" ]; then
    PROYECTO="$input_proj"
  fi
  echo ""

  # 3. Prompt Microservice filter
  read -r -p "3) Filtrar por microservicio (opcional, ENTER para revisar todos): " input_svc
  SERVICE_FILTER="$input_svc"
  echo ""

  # 4. Prompt Display mode
  echo -e "${BOLD}4) ¿Qué resultados deseas visualizar en la tabla?${NC}"
  echo "   1) Solo discrepancias / errores (Recomendado)"
  echo "   2) Todos los microservicios (incluyendo OK)"
  read -r -p "   Elige una opción [1-2] (por defecto: 1): " opt_view
  if [ "$opt_view" = "2" ]; then
    SHOW_ALL="true"
  else
    SHOW_ALL="false"
  fi
  echo ""
fi

# ==============================================================================
# AUDIT FUNCTION PER ENVIRONMENT
# ==============================================================================
auditar_entorno() {
  local env_code="$1"
  local ctx=""
  local ns=""

  case "$env_code" in
    des|desarrollo) ctx="desarrollo";  ns="${PROYECTO}-des" ;;
    int|integracion) ctx="integracion"; ns="${PROYECTO}-int" ;;
    act|aceptacion)  ctx="aceptacion";  ns="${PROYECTO}-act" ;;
    pro|produccion)  ctx="produccion";  ns="${PROYECTO}-pro" ;;
    *) echo -e "${RED}Entorno no reconocido: $env_code${NC}"; return 1 ;;
  esac

  echo -e "${BOLD}${BLUE}=========================================================================================================${NC}"
  echo -e "${BOLD}AUDITANDO ENTORNO: ${CYAN}${ctx}${NC} | NAMESPACE: ${CYAN}${ns}${NC} | PROYECTO: ${CYAN}${PROYECTO}${NC}"
  if [ -n "$SERVICE_FILTER" ]; then
    echo -e "FILTRO POR MICROSERVICIO: ${YELLOW}${SERVICE_FILTER}${NC}"
  fi
  echo -e "${BOLD}${BLUE}=========================================================================================================${NC}"

  # Export variables for Python audit engine
  export AUDIT_CTX="$ctx"
  export AUDIT_NS="$ns"
  export AUDIT_SVC="$SERVICE_FILTER"
  export AUDIT_SHOW_ALL="$SHOW_ALL"
  export AUDIT_PROJ="$PROYECTO"

  python3 - << 'EOF'
import os
import subprocess
import json
import math
import re
import sys

ctx = os.environ.get("AUDIT_CTX", "")
ns = os.environ.get("AUDIT_NS", "")
svc_filter = os.environ.get("AUDIT_SVC", "").strip().lower()
show_all = os.environ.get("AUDIT_SHOW_ALL", "false").lower() in ("true", "1", "yes")

# ANSI Colors
is_tty = sys.stdout.isatty()
C_RED = "\033[0;31m" if is_tty else ""
C_GREEN = "\033[0;32m" if is_tty else ""
C_YELLOW = "\033[1;33m" if is_tty else ""
C_BOLD = "\033[1m" if is_tty else ""
C_RESET = "\033[0m" if is_tty else ""

def parse_cpu(c):
    if not c:
        return 0.0
    c = str(c).strip().lower()
    if c.endswith('m'):
        return float(c[:-1])
    try:
        return float(c) * 1000.0
    except ValueError:
        return 0.0

def parse_mem(m):
    if not m:
        return 0.0
    m = str(m).strip().upper()
    if m.endswith('MI'):
        return float(m[:-2])
    elif m.endswith('M'):
        return float(m[:-1])
    elif m.endswith('GI') or m.endswith('G'):
        num = re.sub(r'[^0-9.]', '', m)
        return float(num) * 1024.0 if num else 0.0
    try:
        return float(m)
    except ValueError:
        return 0.0

# 1. Fetch HPAs
try:
    hpa_res = subprocess.run(
        ["kubectl", "--context", ctx, "get", "hpa", "-n", ns, "-o", "json"],
        capture_output=True, text=True, check=True
    )
    hpa_items = json.loads(hpa_res.stdout).get("items", [])
except subprocess.CalledProcessError as e:
    err_msg = e.stderr.strip()
    if "NotFound" in err_msg or "not found" in err_msg.lower():
        print(f"{C_YELLOW}Aviso: No se encontraron recursos HPA o el namespace '{ns}' no existe en {ctx}.{C_RESET}\n")
    else:
        print(f"{C_RED}Error al conectar a kubectl ({ctx}): {err_msg}{C_RESET}\n")
    sys.exit(0)
except Exception as e:
    print(f"{C_RED}Error inesperado al consultar HPAs: {e}{C_RESET}\n")
    sys.exit(0)

if not hpa_items:
    print(f"{C_YELLOW}No se encontraron recursos HPA en el namespace '{ns}'.{C_RESET}")
    print(f"Nota: Si es entorno de desarrollo, es normal al estar el autoescalado desactivado.\n")
    sys.exit(0)

# 2. Fetch Deployments
try:
    dep_res = subprocess.run(
        ["kubectl", "--context", ctx, "get", "deployments", "-n", ns, "-o", "json"],
        capture_output=True, text=True, check=True
    )
    dep_items = json.loads(dep_res.stdout).get("items", [])
    deps = {d["metadata"]["name"]: d for d in dep_items}
except Exception as e:
    print(f"{C_RED}Error al consultar Deployments en '{ns}': {e}{C_RESET}\n")
    sys.exit(0)

rows = []
total_evaluados = 0
total_errores = 0

for hpa in hpa_items:
    hpa_name = hpa["metadata"]["name"]
    target_ref = hpa["spec"].get("scaleTargetRef", {}).get("name", "")
    
    # Filter by service if specified by user
    if svc_filter and (svc_filter not in hpa_name.lower() and svc_filter not in target_ref.lower()):
        continue

    dep = deps.get(target_ref)
    if not dep:
        continue

    total_evaluados += 1
    containers = dep["spec"]["template"]["spec"].get("containers", [])
    if not containers:
        continue

    # Select main container (matching name or first one)
    c_selected = containers[0]
    for c in containers:
        c_name = c.get("name", "")
        if c_name in target_ref or target_ref.startswith(c_name):
            c_selected = c
            break

    res = c_selected.get("resources", {})
    req_cpu_str = res.get("requests", {}).get("cpu", "N/A")
    lim_cpu_str = res.get("limits", {}).get("cpu", "N/A")
    req_mem_str = res.get("requests", {}).get("memory", "N/A")
    lim_mem_str = res.get("limits", {}).get("memory", "N/A")

    req_cpu = parse_cpu(req_cpu_str)
    lim_cpu = parse_cpu(lim_cpu_str)
    req_mem = parse_mem(req_mem_str)
    lim_mem = parse_mem(lim_mem_str)

    calc_cpu = math.ceil(80.0 * lim_cpu / req_cpu) if req_cpu > 0 and lim_cpu > 0 else None
    calc_mem = math.ceil(80.0 * lim_mem / req_mem) if req_mem > 0 and lim_mem > 0 else None

    act_cpu = None
    act_mem = None
    for m in hpa["spec"].get("metrics", []):
        r_name = m.get("resource", {}).get("name")
        val = m.get("resource", {}).get("target", {}).get("averageUtilization")
        if r_name == "cpu":
            act_cpu = val
        elif r_name == "memory":
            act_mem = val

    diff_cpu = (act_cpu != calc_cpu)
    diff_mem = (act_mem != calc_mem)
    is_error = diff_cpu or diff_mem

    if is_error:
        total_errores += 1

    if show_all or is_error:
        rows.append({
            "target": target_ref,
            "req_lim_cpu": f"{req_cpu_str}/{lim_cpu_str}",
            "act_cpu": act_cpu,
            "exp_cpu": calc_cpu,
            "diff_cpu": diff_cpu,
            "req_lim_mem": f"{req_mem_str}/{lim_mem_str}",
            "act_mem": act_mem,
            "exp_mem": calc_mem,
            "diff_mem": diff_mem,
            "is_error": is_error
        })

# Render table
col_svc = 30
col_cpu_res = 13
col_cpu_tgt = 18
col_mem_res = 17
col_mem_tgt = 17
col_estado = 9

header = (
    f"{'Microservicio':<{col_svc}} | "
    f"{'Req/Lim CPU':<{col_cpu_res}} | "
    f"{'CPU (Act/Esperado)':<{col_cpu_tgt}} | "
    f"{'Req/Lim Mem':<{col_mem_res}} | "
    f"{'Mem (Act/Esperado)':<{col_mem_tgt}} | "
    f"{'Estado':<{col_estado}}"
)
sep = "-" * len(header)

print(header)
print(sep)

for r in sorted(rows, key=lambda x: x["target"]):
    status_str = f"{C_RED}ERROR{C_RESET}" if r["is_error"] else f"{C_GREEN}OK{C_RESET}"
    
    cpu_act_str = f"{r['act_cpu']}%" if r["act_cpu"] is not None else "N/A"
    cpu_exp_str = f"{r['exp_cpu']}%" if r["exp_cpu"] is not None else "N/A"
    cpu_tgt = f"{cpu_act_str} / {cpu_exp_str}"
    if r["diff_cpu"]:
        cpu_tgt = f"{C_YELLOW}{cpu_tgt}{C_RESET}"

    mem_act_str = f"{r['act_mem']}%" if r["act_mem"] is not None else "N/A"
    mem_exp_str = f"{r['exp_mem']}%" if r["exp_mem"] is not None else "N/A"
    mem_tgt = f"{mem_act_str} / {mem_exp_str}"
    if r["diff_mem"]:
        mem_tgt = f"{C_YELLOW}{mem_tgt}{C_RESET}"

    # Length adjustment for escape codes
    svc_name = r["target"]
    if len(svc_name) > col_svc:
        svc_name = svc_name[:col_svc - 2] + ".."

    print(
        f"{svc_name:<{col_svc}} | "
        f"{r['req_lim_cpu']:<{col_cpu_res}} | "
        f"{cpu_tgt:<{col_cpu_tgt + (len(cpu_tgt) - len(f'{cpu_act_str} / {cpu_exp_str}'))}} | "
        f"{r['req_lim_mem']:<{col_mem_res}} | "
        f"{mem_tgt:<{col_mem_tgt + (len(mem_tgt) - len(f'{mem_act_str} / {mem_exp_str}'))}} | "
        f"{status_str}"
    )

print(sep)
print(f"Resumen {ctx}: {C_BOLD}{total_evaluados}{C_RESET} revisados | "
      f"{C_GREEN}{total_evaluados - total_errores} correctos{C_RESET} | "
      f"{C_RED}{total_errores} con discrepancias{C_RESET}\n")
EOF
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
if [ "$ENTORNO" = "all" ] || [ "$ENTORNO" = "todos" ]; then
  for e in des int act pro; do
    auditar_entorno "$e"
  done
else
  auditar_entorno "$ENTORNO"
fi
