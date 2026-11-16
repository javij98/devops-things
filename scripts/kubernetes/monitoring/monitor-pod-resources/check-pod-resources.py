#!/usr/bin/env python3
# ==============================================================================
# check-pod-resources.py
# Muestra recursos asignados (requests y limits de CPU y Memoria) vs consumo real
# y porcentaje de utilización de cada pod en Kubernetes.
# ==============================================================================

import sys
import subprocess
import json
import argparse

# Códigos de color ANSI
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"
GRAY = "\033[90m"

def to_mi(val):
    if not val:
        return 0.0
    val = str(val).strip()
    if val.endswith("Ki"):
        return float(val[:-2]) / 1024.0
    if val.endswith("Mi"):
        return float(val[:-2])
    if val.endswith("Gi"):
        return float(val[:-2]) * 1024.0
    if val.endswith("Ti"):
        return float(val[:-2]) * 1024.0 * 1024.0
    if val.endswith("m"):
        return float(val[:-1]) / (1024.0 * 1024.0 * 1000.0)
    if val.endswith("K") or val.endswith("k"):
        return float(val[:-1]) * 1e3 / (1024.0 * 1024.0)
    if val.endswith("M"):
        return float(val[:-1]) * 1e6 / (1024.0 * 1024.0)
    if val.endswith("G"):
        return float(val[:-1]) * 1e9 / (1024.0 * 1024.0)
    try:
        return float(val) / (1024.0 * 1024.0)
    except Exception:
        return 0.0

def to_m(val):
    if not val:
        return 0.0
    val = str(val).strip()
    if val.endswith("m"):
        return float(val[:-1])
    if val.endswith("u"):
        return float(val[:-1]) / 1000.0
    if val.endswith("n"):
        return float(val[:-1]) / 1000000.0
    try:
        return float(val) * 1000.0
    except Exception:
        return 0.0

def color_pct(pct, is_limit=False):
    if pct is None:
        return f"{GRAY}-{RESET}"
    text = f"{pct:.0f}%"
    if is_limit:
        if pct >= 85:
            return f"{RED}{BOLD}{text:>6}{RESET}"
        elif pct >= 70:
            return f"{YELLOW}{text:>6}{RESET}"
        else:
            return f"{GREEN}{text:>6}{RESET}"
    else:
        if pct >= 100:
            return f"{YELLOW}{text:>6}{RESET}"
        else:
            return f"{GREEN}{text:>6}{RESET}"

def main():
    parser = argparse.ArgumentParser(
        description="Muestra recursos asignados (requests/limits) vs uso actual y porcentaje de utilizacion de pods en Kubernetes."
    )
    parser.add_argument("-e", "--entorno", default="produccion", help="Entorno: des, int, act, pro (o contexto directo)")
    parser.add_argument("-n", "--namespace", default="default", help="Namespace de Kubernetes (ej. apijo-srv, werese-pro)")
    parser.add_argument("-s", "--filter", default="", help="Filtro opcional por texto o servicio (ej. krakend, redis)")
    parser.add_argument("--sort", choices=["mem-lim", "mem-req", "mem-use", "cpu-lim", "cpu-use", "name"], default="name", help="Criterio de ordenacion")
    parser.add_argument("--no-color", action="store_true", help="Desactiva colores ANSI")

    args = parser.parse_args()

    global RESET, BOLD, GREEN, YELLOW, RED, CYAN, GRAY
    if args.no_color or not sys.stdout.isatty():
        RESET = BOLD = GREEN = YELLOW = RED = CYAN = GRAY = ""

    env_map = {
        "des": "desarrollo",
        "int": "integracion",
        "act": "aceptacion",
        "pro": "produccion",
    }
    context = env_map.get(args.entorno.lower(), args.entorno)

    # 1. Obtener top pods
    try:
        top_res = subprocess.run(
            ["kubectl", "--context", context, "top", "pods", "-n", args.namespace, "--no-headers"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"{RED}Error ejecutando 'kubectl top pods': {e.stderr.strip()}{RESET}", file=sys.stderr)
        sys.exit(1)

    top_data = {}
    for line in top_res.stdout.strip().split("\n"):
        parts = line.split()
        if len(parts) >= 3:
            top_data[parts[0]] = (to_m(parts[1]), to_mi(parts[2]))

    # 2. Obtener pod spec
    try:
        get_res = subprocess.run(
            ["kubectl", "--context", context, "get", "pods", "-n", args.namespace, "-o", "json"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"{RED}Error ejecutando 'kubectl get pods': {e.stderr.strip()}{RESET}", file=sys.stderr)
        sys.exit(1)

    try:
        pods_json = json.loads(get_res.stdout)
    except Exception as e:
        print(f"{RED}Error parseando JSON de pods: {e}{RESET}", file=sys.stderr)
        sys.exit(1)

    rows = []
    for item in pods_json.get("items", []):
        name = item["metadata"]["name"]
        status = item.get("status", {}).get("phase", "")
        
        if args.filter and args.filter.lower() not in name.lower():
            continue

        if name not in top_data:
            continue

        cpu_use, mem_use = top_data[name]

        cpu_req = sum(to_m(c.get("resources", {}).get("requests", {}).get("cpu", "0")) for c in item["spec"]["containers"])
        cpu_lim = sum(to_m(c.get("resources", {}).get("limits", {}).get("cpu", "0")) for c in item["spec"]["containers"])
        mem_req = sum(to_mi(c.get("resources", {}).get("requests", {}).get("memory", "0")) for c in item["spec"]["containers"])
        mem_lim = sum(to_mi(c.get("resources", {}).get("limits", {}).get("memory", "0")) for c in item["spec"]["containers"])

        cpu_req_pct = (cpu_use / cpu_req * 100.0) if cpu_req > 0 else None
        cpu_lim_pct = (cpu_use / cpu_lim * 100.0) if cpu_lim > 0 else None
        mem_req_pct = (mem_use / mem_req * 100.0) if mem_req > 0 else None
        mem_lim_pct = (mem_use / mem_lim * 100.0) if mem_lim > 0 else None

        rows.append({
            "name": name,
            "cpu_use": cpu_use,
            "cpu_req": cpu_req,
            "cpu_req_pct": cpu_req_pct,
            "cpu_lim": cpu_lim,
            "cpu_lim_pct": cpu_lim_pct,
            "mem_use": mem_use,
            "mem_req": mem_req,
            "mem_req_pct": mem_req_pct,
            "mem_lim": mem_lim,
            "mem_lim_pct": mem_lim_pct,
        })

    if not rows:
        print(f"No se encontraron pods activos en {context}/{args.namespace}" + (f" con filtro '{args.filter}'" if args.filter else ""))
        sys.exit(0)

    # Ordenacion
    if args.sort == "mem-lim":
        rows.sort(key=lambda x: x["mem_lim_pct"] or -1, reverse=True)
    elif args.sort == "mem-req":
        rows.sort(key=lambda x: x["mem_req_pct"] or -1, reverse=True)
    elif args.sort == "mem-use":
        rows.sort(key=lambda x: x["mem_use"], reverse=True)
    elif args.sort == "cpu-lim":
        rows.sort(key=lambda x: x["cpu_lim_pct"] or -1, reverse=True)
    elif args.sort == "cpu-use":
        rows.sort(key=lambda x: x["cpu_use"], reverse=True)
    else:
        rows.sort(key=lambda x: x["name"])

    # Header
    print(f"\n{BOLD}{CYAN}=== RECURSOS Y UTILIZACIÓN: [{context}] / namespace: [{args.namespace}] ==={RESET}")
    header_fmt = "{:<42} {:>8} {:>8} {:>6} {:>8} {:>6}  |  {:>9} {:>9} {:>6} {:>9} {:>6}"
    print(f"{BOLD}" + header_fmt.format(
        "POD", "CPU_USE", "CPU_REQ", "%REQ", "CPU_LIM", "%LIM", "MEM_USE", "MEM_REQ", "%REQ", "MEM_LIM", "%LIM"
    ) + f"{RESET}")
    print("-" * 120)

    for r in rows:
        name_str = r["name"]
        if len(name_str) > 41:
            name_str = name_str[:38] + "..."

        cpu_u = f"{r['cpu_use']:.0f}m"
        cpu_r = f"{r['cpu_req']:.0f}m" if r['cpu_req'] > 0 else f"{GRAY}-{RESET}"
        cpu_l = f"{r['cpu_lim']:.0f}m" if r['cpu_lim'] > 0 else f"{GRAY}-{RESET}"
        c_req_col = color_pct(r['cpu_req_pct'])
        c_lim_col = color_pct(r['cpu_lim_pct'], is_limit=True)

        mem_u = f"{r['mem_use']:.0f}Mi"
        mem_r = f"{r['mem_req']:.0f}Mi" if r['mem_req'] > 0 else f"{GRAY}-{RESET}"
        mem_l = f"{r['mem_lim']:.0f}Mi" if r['mem_lim'] > 0 else f"{GRAY}-{RESET}"
        m_req_col = color_pct(r['mem_req_pct'])
        m_lim_col = color_pct(r['mem_lim_pct'], is_limit=True)

        print(
            f"{name_str:<42} "
            f"{cpu_u:>8} "
            f"{cpu_r:>8} "
            f"{c_req_col} "
            f"{cpu_l:>8} "
            f"{c_lim_col}  |  "
            f"{mem_u:>9} "
            f"{mem_r:>9} "
            f"{m_req_col} "
            f"{mem_l:>9} "
            f"{m_lim_col}"
        )

    print("-" * 120 + "\n")

if __name__ == "__main__":
    main()
