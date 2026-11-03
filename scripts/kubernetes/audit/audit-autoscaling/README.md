# audit-autoscaling.sh

Interactive and CLI-flag Bash utility to audit and verify compliance with the **corporate 80% autoscaling rule** across Kubernetes microservices.

Cross-references in real time the container resource specifications (`requests` and `limits` for CPU and Memory) from `Deployments` with the target thresholds (`averageUtilization`) configured in their corresponding `HorizontalPodAutoscalers` (HPA).

---

## The 80% Autoscaling Rule

The goal of Horizontal Pod Autoscaling (HPA) is to trigger scaling when a container reaches approximately **80% of its resource limit**, calculated as a percentage relative to its request:

$$\text{autoscaling\_cpu} = \left\lceil 80 \times \frac{\text{resources\_limits\_cpu}}{\text{resources\_request\_cpu}} \right\rceil$$

$$\text{autoscaling\_memory} = \left\lceil 80 \times \frac{\text{resources\_limits\_memory}}{\text{resources\_request\_memory}} \right\rceil$$

*Where:*
* If CPU limit is `1000m` (1 core) and request is `10m`:
  $$\text{Target CPU} = \lceil 80 \times 1000 / 10 \rceil = 8000\%$$
* If memory limit is `200Mi` and request is `130Mi`:
  $$\text{Target Memory} = \lceil 80 \times 200 / 130 \rceil = 124\%$$

---

## What the Script Does

1. **Queries Kubernetes live** using read-only `kubectl` commands (`kubectl get hpa` and `kubectl get deployments`).
2. **Normalizes resource units automatically:**
   - CPU: millicores (`m`) and whole cores (`1`, `2`).
   - Memory: `Mi`, `M`, `Gi`, `G`.
3. **Calculates expected target values** according to the formula.
4. **Compares configured targets against expected values** and detects discrepancies.
5. **Generates an ANSI-colored formatted table** indicating `OK` or `ERROR`.
6. **Outputs a final statistical summary** per environment: total evaluated, correct, and mismatched.

---

## Prerequisites

- **Bash 4+**
- **Python 3** (used natively inside the script for precision math and JSON processing)
- **kubectl** configured with read access to the cluster contexts
- Read permissions for `hpa` and `deployments` in target namespaces

---

## Environments & Contexts

| Environment | Flag Code | `kubectl` Context | Namespace (`<project>-<env>`) |
| :--- | :--- | :--- | :--- |
| **Development** | `des` | `desarrollo` | `<project>-des` *(e.g. apijo-des)* |
| **Integration** | `int` | `integracion` | `<project>-int` *(e.g. apijo-int)* |
| **Acceptance** | `act` | `aceptacion` | `<project>-act` *(e.g. apijo-act)* |
| **Production** | `pro` | `produccion` | `<project>-pro` *(e.g. apijo-pro)* |
| **All** | `all` | Sequentially audits `des`, `int`, `act`, and `pro` |

> [!NOTE]
> In development (`desarrollo`), autoscaling is typically disabled by design to save cluster capacity. The script detects and handles this gracefully without failing.

---

## Syntax and Options

```text
Usage: audit-autoscaling.sh [options] [environment] [project]

Options:
  -e, --entorno <env>       Target environment: des, int, act, pro, all
  -p, --proyecto <project>  Project prefix (default: apijo)
  -s, --servicio <name>     Filter by microservice name (optional)
  -a, --all                 Show all components (not just errors)
  -h, --help                Show help
```

---

## Examples

### 1. Interactive Guided Mode (Recommended)
```bash
./audit-autoscaling.sh
```

### 2. Audit a Specific Environment (Discrepancies Only)
```bash
./audit-autoscaling.sh -e integracion
```

### 3. Audit All Environments
```bash
./audit-autoscaling.sh all
```

### 4. Show All Services (Including OK)
```bash
./audit-autoscaling.sh -e int -a
```

### 5. Filter by Microservice
```bash
./audit-autoscaling.sh -e pro -s user-service -a
```

---

## Output Interpretation

```text
=========================================================================================================
AUDITING ENVIRONMENT: integracion | NAMESPACE: apijo-int | PROJECT: apijo
=========================================================================================================
Microservice                   | Req/Lim CPU   | CPU (Act/Expected) | Req/Lim Mem       | Mem (Act/Expected) | Status   
------------------------------------------------------------------------------------------------------------------------
user-service-v1                | 30m/1         | 75% / 2667%        | 128Mi/192Mi       | 75% / 120%         | ERROR
config-service-v1              | 20m/1         | 75% / 4000%        | 128Mi/192Mi       | 75% / 120%         | ERROR
mail-service-v1                | 70m/1         | 1143% / 1143%      | 130Mi/200Mi       | 124% / 124%        | OK
------------------------------------------------------------------------------------------------------------------------
Summary integracion: 16 evaluated | 8 compliant | 8 with discrepancies
```
