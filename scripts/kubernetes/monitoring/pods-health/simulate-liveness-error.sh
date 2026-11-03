#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/functions.sh"

POD=$(new_pod)
echo "Marcando T0 y enviando SIGSTOP al PID 1"
T0=$(date +%s)
# kubectl --context "$CLUSTER" -n "$NS" exec "$POD" -- sh -c 'kill -STOP 1' || echo "Not allowed in this image/user"
# kubectl --context "$CLUSTER" -n "$NS" exec "$POD" -- sh -c '
#   pgid=$(ps -o pgid= -p 1 | tr -d " ")
#   # the -PGID notation sends the signal to the whole group
#   kill -STOP -- -"$pgid"
# ' || echo "Could not send SIGSTOP"

kubectl --context "$CLUSTER" -n "$NS" exec "$POD" -- sh -c '
  for child in $(cat /proc/1/task/1/children); do
    kill -STOP "$child" && exit 0
  done
  echo "PID 1 no tiene hijos; no hay a quién parar" >&2
  exit 1
'

# Watch events until the container is killed
echo "Esperando evento de Killing container..."
kubectl --context "$CLUSTER" -n "$NS" get events --field-selector involvedObject.name="$POD" --watch | grep -m1 -E "Killing container|Back-off"

T1=$(date +%s)
echo "Tiempo hasta reinicio (aprox): $((T1 - T0)) s"
