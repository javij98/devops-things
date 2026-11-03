#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/functions.sh"

POD=$(new_pod)

# 200 samples of readiness
kubectl --context "$CLUSTER" -n "$NS" exec "$POD" -- sh -c \
"for i in \$(seq 1 200); do curl -s -o /dev/null -w '%{time_total}\n' http://127.0.0.1:${PORT}${READY_PATH}; done" \
| tee ready_lat.txt

echo "== Latencia readiness =="
cat ready_lat.txt | percentiles

# 200 samples of liveness
kubectl --context "$CLUSTER" -n "$NS" exec "$POD" -- sh -c \
"for i in \$(seq 1 200); do curl -s -o /dev/null -w '%{time_total}\n' http://127.0.0.1:${PORT}${LIVE_PATH}; done" \
| tee live_lat.txt

echo "== Latencia liveness =="
cat live_lat.txt | percentiles
