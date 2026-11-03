# monitor-pod-resources.sh

Real-time monitoring script for CPU and memory usage of build pods and nodes in Kubernetes.

Detects running pods matching a name pattern, displays a live terminal table, and tracks historical maximum usage per pod until execution stops.

## Features

- Discovers running pods in a namespace using regex pattern matching.
- Reads resource metrics via `kubectl top pod`.
- Displays real-time per pod:
  - Current and peak CPU (`m`)
  - Current and peak memory (`Mi`)
  - Assigned node
- Displays node resource utilization:
  - CPU%
  - MEM%
- On `Ctrl+C`, prints a final summary of historical peaks per pod and per node.

## Prerequisites

- Bash 4+ (uses associative arrays)
- `kubectl` configured with cluster/context access
- Cluster metrics available (`metrics-server` or equivalent)

## Defaults

If executed without flags, default values are:

- Namespace: `jenkins-ocp`
- Context: `infraestructure`
- Refresh interval: `1` second
- Pod pattern: `-build-`

## Usage

```bash
./monitor-pod-resources.sh [options]
```

### Options

- `-n <namespace>`: Target namespace
- `-c <context>`: kubectl context
- `-i <seconds>`: Refresh interval in seconds (supports decimals > 0)
- `-p <regex>`: Pod name regex pattern
- `-s <services>`: Comma-separated list of microservice names (e.g. `user-service,purchase-service`)
- `-P <project>`: Project filter (2nd token in pod name, e.g. `apijo`, `quiosp`)
- `-h`: Show help

## Examples

Run with defaults:

```bash
./monitor-pod-resources.sh
```

Change interval to 2s:

```bash
./monitor-pod-resources.sh -i 2
```

Filter pods matching custom pattern:

```bash
./monitor-pod-resources.sh -p despliegue
```

Specify namespace and context:

```bash
./monitor-pod-resources.sh -n jenkins-ocp -c infraestructure
```

Filter specific services:

```bash
./monitor-pod-resources.sh -s user-service,purchase-service
```

Combine project and service filters:

```bash
./monitor-pod-resources.sh -P quiosp -s management-front
```

## Troubleshooting

1. Verify cluster connection and namespace:
   ```bash
   kubectl --context infraestructure get pods -n jenkins-ocp
   ```
2. Check metrics availability:
   ```bash
   kubectl --context infraestructure top pod -n jenkins-ocp
   ```
