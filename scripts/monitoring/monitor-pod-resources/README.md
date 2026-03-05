# monitor-pod-resources.sh

Script para monitorizar en tiempo real el uso de CPU y memoria de pods de build de Jenkins en Kubernetes.

Detecta pods Running por patrón de nombre, muestra una tabla en vivo y guarda los máximos históricos por pod hasta que detienes la ejecución.

## Qué hace

- Descubre pods Running en un namespace usando un patrón regex.
- Lee métricas con `kubectl top pod`.
- Muestra en vivo por pod:
  - CPU actual y máxima (m)
  - Memoria actual y máxima (Mi)
  - Nodo asignado
- Muestra también la utilización de nodos implicados en la build:
  - CPU%
  - MEM%
- Al pulsar `Ctrl+C`, imprime un resumen final con máximos por pod.

## Requisitos

- Bash 4+ (usa arrays asociativos)
- `kubectl` configurado y con acceso al cluster/contexto
- Métricas habilitadas en el clúster (`metrics-server` o equivalente)

## Valores por defecto

Si ejecutas sin opciones, usa estos valores:

- Namespace: `jenkins-ocp`
- Contexto: `infraestructure`
- Refresco: `1` segundo
- Patrón de pods: `-build-`

## Uso

```bash
./monitor-pod-resources.sh [opciones]
```

### Opciones

- `-n <namespace>`: Namespace
- `-c <context>`: Contexto de kubectl
- `-i <seconds>`: Intervalo de refresco (acepta enteros o decimales > 0)
- `-p <regex>`: Patrón regex para filtrar nombre de pod
- `-s <services>`: Lista de microservicios separados por coma (ej: `user-service,purchase-service`)
- `-P <project>`: Proyecto (2º bloque del nombre del pod, ej: `apijo`, `quiosp`)
- `-h`: Ayuda

## Ejemplos de uso

Ejecutar con valores por defecto:

```bash
./monitor-pod-resources.sh
```

Cambiar solo el intervalo a 2s:

```bash
./monitor-pod-resources.sh -i 2
```

Filtrar solo pods que contengan "despliegue":

```bash
./monitor-pod-resources.sh -p despliegue
```

Usar namespace y contexto específicos:

```bash
./monitor-pod-resources.sh -n jenkins-ocp -c infraestructure
```

Combinar todo:

```bash
./monitor-pod-resources.sh -n jenkins-ocp -c infraestructure -i 1 -p '-build-'
```

Filtrar solo servicios concretos (ejemplo: `user-service` y `purchase-service`):

```bash
./monitor-pod-resources.sh -s user-service,purchase-service
```

Combinar patrón + servicios:

```bash
./monitor-pod-resources.sh -p '-build-' -s user-service,purchase-service
```

Filtrar por proyecto (ejemplo: `apijo`):

```bash
./monitor-pod-resources.sh -P apijo
```

Filtrar por proyecto + servicios:

```bash
./monitor-pod-resources.sh -P quiosp -s management-front
```

## Ejemplos de output

### 1) Inicio + pods detectados

```text
Monitoring all running Jenkins build pods
Namespace: jenkins-ocp | Context: infraestructure | Name pattern: -build- | Refresh: 1s
Press Ctrl+C to stop and see the final report...
-------------------------------------------------------
[LIVE 13:49:08] Running Jenkins build pods
-------------------------------------------------------
POD                                                                           CPU    CPU_MAX          MEM      MEM_MAX
---                                                                           ---    -------          ---      -------
gsa-devops-build-ocpcli-versionado-componentes-develop-19-kjf9g               6m       108m         484Mi       485Mi

Node utilization for monitored pods
NODE                                          CPU%      MEM%
----                                          ----      ----
worker-01                                      62%       71%
```

### 2) Sin pods que cumplan el filtro

```text
[LIVE 13:50:12] Running Jenkins build pods
-------------------------------------------------------
[WAITING FOR DATA...] No running build pods detected.
```

### 3) Resumen al detener con Ctrl+C

```text
========================================
  HISTORICAL PEAK RESULTS BY POD
========================================
gsa-devops-build-ocpcli-versionado-componentes-develop-19-kjf9g   CPU Max:   108m | MEM Max:      485Mi
========================================
```

## Comportamiento de opciones

Las opciones de línea de comandos sobrescriben los valores por defecto solo en esa ejecución.
No modifican el archivo ni cambian los valores para futuras ejecuciones.

## Notas

- El patrón de `-p` es regex de `awk`/expresión regular usada en el filtrado.
- El filtro `-s` busca pods cuyo nombre contenga `-build-<servicio>-`.
- El filtro `-P` compara el 2º bloque del nombre del pod (separado por `-`).
  - Ejemplo: `sp-quiosp-act-int-quiosp-build-management-front-release-8-drqfm` → proyecto `quiosp`
  - Ejemplo: `apijo-apijo-desarrollo-apijo-build-user-service-feature-8-wzjpt` → proyecto `apijo`
- La tabla principal muestra el nodo (`NODE`) de cada pod monitorizado.
- La sección `Node utilization for monitored pods` muestra `%CPU` y `%MEM` con datos de `kubectl top node`.
- Si no hay pods que cumplan el filtro, verás el mensaje de espera.
- Si un pod no tiene métrica en ese instante, se mostrará `N/A`.

## Solución rápida de problemas

Si no aparece información:

1. Verifica acceso y contexto:

   ```bash
   kubectl --context infraestructure get pods -n jenkins-ocp
   ```

2. Verifica métricas:

   ```bash
   kubectl --context infraestructure top pod -n jenkins-ocp
   ```

3. Verifica permisos RBAC para listar pods y consultar métricas.
