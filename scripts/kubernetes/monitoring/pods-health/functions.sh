#!/usr/bin/env bash
set -euo pipefail

CLUSTER="desarrollo"                     # contexto kubectl
NS="apijo-des"                           # namespace
DEPLOY="banner-service-v1"            # nombre del Deployment
SEL="service=banner-service"          # label selector de los pods
PORT=8080                                # containerPort
STARTED_PATH="/q/health/started"
READY_PATH="/q/health/ready"
LIVE_PATH="/q/health/live"

# Pod más reciente del deployment
# new_pod() {
#   kubectl --context "$CLUSTER" -n "$NS" get po -l "$SEL" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.creationTimestamp}{"\n"}{end}' \
#   | sort -k2 | tail -n1 | awk '{print $1}'
# }

# # Evita pods terminando al elegir “el más reciente”
new_pod() {
  kubectl --context "$CLUSTER" -n "$NS" get po -l "$SEL" \
    --sort-by=.metadata.creationTimestamp -o json \
  | jq -r '.items[]
           | select(.metadata.deletionTimestamp|not)   # excluye Terminating
           | .metadata.name' \
  | tail -n1
}


# IP del pod
pod_ip() {
  # kubectl --context "$CLUSTER" -n "$NS" get pod "$1" -o jsonpath='{.status.podIP}'

  # Si justo borras un pod y el nuevo todavía no tiene IP, puede venirte bien esperar a
  # que aparezca el contenedor en estado running antes de leer timestamps
  kubectl --context "$CLUSTER" -n "$NS" wait --for=condition=ContainersReady "pod/$POD" --timeout=600s >/dev/null
}



# Estadísticos (P50/P95/P99) a partir de una columna numérica (segundos)
percentiles() {
  # gawk '
  #   {x[NR]=$1} 
  #   n = asort(x)
  #   # índices simples por cuantiles (redondeo conservador)
  #   function idx(p){
  #     i = int(p*n/100);
  #     if(i<1) i = 1;
  #     if(i>n) i = n;
  #     return i
  #   }
  #   END{
  #     printf("count=%d P50=%ss P95=%ss P99=%ss\n", n, x[idx(50)], x[idx(95)], x[idx(99)])
  #   }'
  sort -n | awk '
    {x[NR]=$1+0} # fuerza numérico
    END{
      n=NR
      if(n==0){print "count=0"; exit}
      # índices aproximados
      p50=int(0.50*n); if(p50<1)p50=1
      p95=int(0.95*n); if(p95<1)p95=1
      p99=int(0.99*n); if(p99<1)p99=1
      printf("count=%d P50=%ss P95=%ss P99=%ss\n", n, x[p50], x[p95], x[p99])
    }'
}

