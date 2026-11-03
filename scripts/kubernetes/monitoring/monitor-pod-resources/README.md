# monitor-pod-resources.sh

Real-time interactive and CLI-driven monitoring utility for CPU and memory usage of Kubernetes pods across different scopes:
- **Jenkins build pods** in cluster infrastructure (`infraestructure` / `jenkins-ocp`).
- **Application microservices** in environment namespaces (`<project>-<env>`, e.g. `apijo-des`, `apijo-int`, `werese-pro`).
- **Project infrastructure services** in `<project>-srv` namespaces (e.g. KrakenD, Grafana, Kafka, Zookeeper, Debezium) across all environments (`desarrollo`, `integracion`, `aceptacion`, `produccion`).

Detects running pods, displays an ANSI-colored dynamic live table, and records peak resource consumption per pod and per node until execution is stopped with `Ctrl+C`.

---

## Features

- **Multi-Scope Monitoring:**
  - **Jenkins Builds:** context `infraestructure` and namespace `jenkins-ocp` (filtering `-build-`).
  - **Application Microservices:** automatic namespace resolution to `<project>-<env>`.
  - **Project Infrastructure (`-srv`):** dedicated monitoring for project-level shared services (KrakenD, Grafana, Kafka, Keycloak Adapter, etc.) residing in `<project>-srv`.
  - **Custom / Manual:** arbitrary context and namespace input.
- **Flexible Substring Filter:** case-insensitive word matching allowing filters like `mail`, `krakend`, or comma-separated lists without requiring rigid hyphens.
- **Real-Time Live Dashboard:**
  - Current and peak CPU (`m`).
  - Current and peak memory (`Mi`).
  - Assigned cluster node.
  - Associated node metrics (`%CPU`, `%MEM`).
- **Consolidated Summary:** on `Ctrl+C`, prints historical peak metrics per pod and per node.

---

## Prerequisites

- **Bash 4+** (uses associative arrays)
- **kubectl** configured with read access to the relevant cluster contexts
- Cluster metrics enabled (`metrics-server` or equivalent)
- RBAC read permissions for pods and metrics (`top pod`, `top node`)

---

## 🔗 Symbolic Links & Execution Standards

The utility supports both local execution via relative symlinks and global execution:

### 1. In-Repository Relative Symlink (Tracked in Git)
The directory includes a local relative symlink without the `.sh` extension:
```text
monitor-pod-resources -> monitor-pod-resources.sh
```
This enables invocation without the `.sh` extension:
```bash
# Using the relative symlink:
./monitor-pod-resources

# Or executing the script directly:
./monitor-pod-resources.sh
```

> [!TIP]
> Git versions symlinks natively using mode `120000`, storing only a lightweight pointer (~20 bytes). Do NOT add this symlink to `.gitignore`.

### 2. Global User Symlink (`$PATH`)
To run `monitor-pod-resources` globally from any working directory:
```bash
ln -s "/path/to/devops-things/scripts/kubernetes/monitoring/monitor-pod-resources/monitor-pod-resources.sh" ~/.local/bin/monitor-pod-resources
```

---

## Usage Modes

### 1. Interactive Guided Wizard (Default)
Running the script without arguments launches the interactive assistant:

```bash
monitor-pod-resources
```

The wizard guides you step-by-step:
1. **Scope:**
   - `1) Jenkins Builds:` automatically sets `infraestructure`, `jenkins-ocp`, and `-build-`.
   - `2) Application / Infrastructure Pods:`
     - Select environment / cluster: `1: des`, `2: int`, `3: act`, `4: pro`.
     - Enter project: e.g. `apijo`, `werese`.
     - Select component type: `1: Application microservices (<project>-<env>)` or `2: Infrastructure services (<project>-srv)`.
     - Optional keyword filter.
     - Refresh interval.
   - `3) Custom / Manual configuration.`

---

### 2. Command-Line Options (Flags)

```bash
monitor-pod-resources [options]
```

| Flag | Long Option | Description | Default |
| :--- | :--- | :--- | :--- |
| `-e <env>` | `--entorno <env>` | Environment / cluster (`des`, `int`, `act`, `pro`) | - |
| `-P <proj>` | `--project <proj>` | Project name (e.g. `apijo`, `werese`) | - |
| `--srv` | `--infra` | Target `<project>-srv` infrastructure namespace | `false` |
| `-n <name>` | `--namespace <name>` | Explicit Kubernetes namespace | `jenkins-ocp` |
| `-c <ctx>` | `--context <ctx>` | Explicit kubectl context | `infraestructure` |
| `-s <words>` | `--filter, --services` | Substring keyword filter (e.g. `krakend`, `mail`) | *(all)* |
| `-p <regex>` | `--pattern <regex>` | Optional regex pattern for pod names | - |
| `-i <sec>` | `--interval <sec>` | Refresh interval in seconds | `1` |
| `-I` | `--interactive` | Force interactive wizard | - |
| `-h` | `--help` | Show help | - |

---

## Examples

### Launch interactive assistant:
```bash
monitor-pod-resources
```

### Monitor `werese` application microservices in production:
```bash
monitor-pod-resources -e pro -P werese
```

### Monitor `werese` infrastructure services (KrakenD, Grafana) in development:
```bash
monitor-pod-resources -e des -P werese --srv
```

### Monitor specific microservice (`mail`) in integration:
```bash
monitor-pod-resources -e int -P apijo -s mail
```

### Monitor Jenkins build pods for a specific component:
```bash
monitor-pod-resources -c infraestructure -n jenkins-ocp -s user-service
```

---

## Output Examples

### 1) Live dynamic monitoring table

```text
Monitorizando pods en Kubernetes
Contexto: integracion | Namespace: apijo-int | Refresco: 1s
Filtro por palabra/servicio: mail
Presiona Ctrl+C para detener y ver el informe de picos máximos...
----------------------------------------------------------------------------------------
[EN VIVO 14:32:38] Pods activos en apijo-int (integracion)
----------------------------------------------------------------------------------------
POD                                                                   CPU    CPU_MAX        MEM    MEM_MAX           NODO
---                                                                   ---    -------        ---    -------           ----
mail-service-7848c4cf8d-2xghq                                         26m      145m      1055Mi     1248Mi    vm-ocpinf04
mail-service-7848c4cf8d-4hk29                                         32m      190m      1012Mi     1200Mi    vm-ocpinf07

NODO                                           CPU%     CPU_MAX%     MEM%     MEM_MAX%
----                                           ----     --------     ----     --------
vm-ocpinf04                                     14%          97%      47%          84%
vm-ocpinf07                                     16%          98%      40%          75%
```

### 2) Historical peak summary upon `Ctrl+C`

```text
========================================================================================
                    RESUMEN FINAL DE PICOS MÁXIMOS POR POD                             
========================================================================================
mail-service-7848c4cf8d-2xghq                                     Nodo: vm-ocpinf04     | CPU Máx:    145m | MEM Máx:  1248Mi
mail-service-7848c4cf8d-4hk29                                     Nodo: vm-ocpinf07     | CPU Máx:    190m | MEM Máx:  1200Mi

========================================================================================
                    RESUMEN FINAL DE PICOS MÁXIMOS POR NODO (%)                        
========================================================================================
vm-ocpinf04                              CPU Máx:     97% | MEM Máx:     84%
vm-ocpinf07                              CPU Máx:     98% | MEM Máx:     75%
========================================================================================
```
