# calculate-pod-ready-time.sh

Purpose
- Measure how long it takes for a newly created Kubernetes pod's container to reach the "Ready" condition after the container has started.
- Repeats the process N times and records the time deltas (seconds) between container start and Ready transition.

Prerequisites
- bash 4+ (script uses bash features)
- kubectl installed and configured with access to the target cluster
- execute permissions for the script: chmod +x calculate-pod-ready-time.sh
- A companion file named `functions.sh` located in the same directory. This script expects `functions.sh` to provide a function named `new_pod` (that returns the new pod name) and may use other helper functions.
- A `percentiles` utility used at the end of the script to print statistics. If not available, use simple alternatives shown below.

Required environment variables (must be set prior to running)
- CLUSTER — kubectl context to use
- NS — namespace to target
- SEL — label selector to choose the pod(s) (e.g. "app=my-app")

What the script does (high level)
1. Optionally deletes the oldest pod matching the selector to force replacement.
2. Waits for a new pod to appear (via `new_pod`).
3. Waits until the pod condition Ready=true (timeout 600s).
4. Reads the container started timestamp and the Ready transition timestamp.
5. Computes the delta in seconds and appends it to `ready_times.txt`.
6. Repeats for N iterations (N is set at the top of the script; default 10).
7. Prints percentiles/statistics of collected times.

Usage
1. Ensure CLUSTER, NS, SEL are exported:
   export CLUSTER="my-cluster"
   export NS="default"
   export SEL="app=my-app"

2. Ensure functions.sh exists and is correct:
   - It must be in the same directory as the script.
   - It must provide new_pod() to return the new pod name.

3. Make the script executable and run it:
   chmod +x calculate-pod-ready-time.sh
   ./calculate-pod-ready-time.sh

Notes
- To change the number of iterations, edit the N variable near the top of the script.
- The script writes per-run deltas (seconds) to ready_times.txt in the current directory.
- If the `percentiles` tool isn't installed, get basic stats with:
   sort -n ready_times.txt | awk 'BEGIN{n=0} {a[++n]=$1} END{if(n){print "count",n; print "min",a[1]; print "max",a[n]; print "median", a[int((n+1)/2)]}}'

Troubleshooting
- If the script hangs waiting for a pod, check `kubectl --context "$CLUSTER" -n "$NS" get pods -l "$SEL"` to ensure pods are being created.
- If timestamps are empty, confirm containerStatuses and Ready condition exist in pod status.
- Check permissions and kubectl context if API calls fail.

Files
- calculate-pod-ready-time.sh — measurement script
- functions.sh — required helper functions (must be present)
- ready_times.txt — output produced by runs