# audit-autoscaling.sh

Script Bash interactivo y mediante flags para auditar y verificar el cumplimiento de la **regla corporativa del 80% de autoescalado** en los microservicios desplegados en Kubernetes.

Cruza en tiempo real las especificaciones de recursos (`requests` y `limits` de CPU y Memoria) de los `Deployments` con los umbrales objetivos (`averageUtilization`) configurados en sus correspondientes `HorizontalPodAutoscalers` (HPA).

---

## La regla del 80% de autoescalado

El objetivo del autoescalado horizontal (HPA) es escalar cuando el contenedor alcanza aproximadamente el **80% de su límite máximo de recursos**, calculándose como un porcentaje respecto al request:

$$\text{autoscaling\_cpu} = \left\lceil 80 \times \frac{\text{resources\_limits\_cpu}}{\text{resources\_request\_cpu}} \right\rceil$$

$$\text{autoscaling\_memory} = \left\lceil 80 \times \frac{\text{resources\_limits\_memory}}{\text{resources\_request\_memory}} \right\rceil$$

*Donde:*
* Si el límite de CPU es `1000m` (1 core) y el request es `10m`:
  $$\text{Target CPU} = \lceil 80 \times 1000 / 10 \rceil = 8000\%$$
* Si el límite de memoria es `200Mi` y el request es `130Mi`:
  $$\text{Target Memoria} = \lceil 80 \times 200 / 130 \rceil = 124\%$$

---

## Qué hace el script

1. **Consulta en vivo el clúster Kubernetes** usando `kubectl` de solo lectura (`kubectl get hpa` y `kubectl get deployments`).
2. **Normaliza automáticamente las unidades:**
   * CPU: milicores (`m`) y cores enteros (`1`, `2`).
   * Memoria: `Mi`, `M`, `Gi`, `G`.
3. **Calcula el valor esperado** según la fórmula corporativa para cada microservicio.
4. **Compara el valor real configurado frente al esperado** e identifica discrepancias.
5. **Genera una tabla visual formateada** indicando `OK` o `ERROR` (con código de colores ANSI en terminal).
6. **Ofrece un resumen estadístico final** por entorno: total revisados, correctos y con discrepancias.

---

## Requisitos

* **Bash 4+**
* **Python 3** (integrado de forma nativa en el script para el cálculo de precisión matemática)
* **kubectl** configurado con acceso de lectura a los contextos del clúster
* Permisos de lectura sobre `hpa` y `deployments` en los namespaces a auditar

---

## Entornos y Contextos

El script traduce automáticamente los códigos de entorno a sus contextos y namespaces correspondientes según la convención del proyecto:

| Entorno | Código | Contexto `kubectl` | Namespace (`<proyecto>-<entorno>`) |
| :--- | :--- | :--- | :--- |
| **Desarrollo** | `des` | `desarrollo` | `<proyecto>-des` *(ej. apijo-des)* |
| **Integración** | `int` | `integracion` | `<proyecto>-int` *(ej. apijo-int)* |
| **Aceptación** | `act` | `aceptacion` | `<proyecto>-act` *(ej. apijo-act)* |
| **Producción** | `pro` | `produccion` | `<proyecto>-pro` *(ej. apijo-pro)* |
| **Todos** | `all` | Audita secuencialmente `des`, `int`, `act` y `pro` |

> [!NOTE]
> En desarrollo (`desarrollo`), el autoescalado suele estar desactivado por diseño para ahorrar recursos de infraestructura. El script lo detecta e informa sin fallar.

---

## Sintaxis y Opciones

```text
Uso: audit-autoscaling.sh [opciones] [entorno] [proyecto]

Opciones:
  -e, --entorno <entorno>       Entorno a auditar: des, int, act, pro, all
  -p, --proyecto <proyecto>     Prefijo de proyecto/aplicación (defecto: apijo)
  -s, --servicio <nombre>       Filtrar por nombre de microservicio (opcional)
  -a, --all                     Mostrar todos los componentes (no solo discrepancias)
  -h, --help                    Muestra la ayuda
```

---

## Ejemplos de uso

### 1. Modo interactivo guiado (Recomendado)
Si se ejecuta sin parámetros, el script guía al usuario paso a paso:

```bash
/home/path/to/script/audit-autoscaling/audit-autoscaling.sh
```

*(O utilizando el enlace directo: `./audit-autoscaling`)*

El asistente solicitará:
1. Selección de entorno (`1-5`, o `all`).
2. Prefijo del proyecto / aplicación (`ENTER` para `apijo`).
3. Filtro opcional por microservicio (`ENTER` para todos).
4. Modo de visualización (`1: Solo errores` o `2: Todos los servicios`).

---

### 2. Auditar un entorno concreto (solo discrepancias)
```bash
audit-autoscaling int
```
o con flag:
```bash
audit-autoscaling -e integracion
```

---

### 3. Auditar todos los entornos de golpe
```bash
audit-autoscaling all
```

Auditará secuencialmente `des`, `int`, `act` y `pro`.

---

### 4. Mostrar la tabla completa (incluyendo componentes correctos `OK`)
```bash
audit-autoscaling -e int -a
```

---

### 5. Filtrar por un microservicio específico
```bash
audit-autoscaling -e pro -s dow-jones -a
```

---

### 6. Auditar un proyecto diferente a `apijo`
```bash
audit-autoscaling -e int -p penyas
```

---

## Interpretación de la salida

```text
=========================================================================================================
AUDITANDO ENTORNO: integracion | NAMESPACE: apijo-int | PROYECTO: apijo
=========================================================================================================
Microservicio                  | Req/Lim CPU   | CPU (Act/Esperado) | Req/Lim Mem       | Mem (Act/Esperado) | Estado   
------------------------------------------------------------------------------------------------------------------------
dow-jones-service-v1           | 30m/1         | 75% / 2667%        | 128Mi/192Mi       | 75% / 120%        | ERROR
jo-config-service-v1           | 20m/1         | 75% / 4000%        | 128Mi/192Mi       | 75% / 120%        | ERROR
mail-service-v1                | 70m/1         | 1143% / 1143%      | 130Mi/200Mi       | 124% / 124%       | OK
syndicate-service-v1           | 40m/1         | 2000% / 2000%      | 512Mi/1000Mi      | 124% / 157%       | ERROR
------------------------------------------------------------------------------------------------------------------------
Resumen integracion: 16 revisados | 8 correctos | 8 con discrepancias
```

### Significado de las columnas:
* **`Microservicio`:** Nombre del recurso `Deployment` objetivo del autoescalado.
* **`Req/Lim CPU`:** Recursos de CPU configurados en el contenedor (`requests / limits`).
* **`CPU (Act/Esperado)`:** Porcentaje de target configurado en el HPA vs el porcentaje calculado con la fórmula corporativa.
* **`Req/Lim Mem`:** Recursos de Memoria configurados en el contenedor (`requests / limits`).
* **`Mem (Act/Esperado)`:** Porcentaje de target configurado en el HPA vs el porcentaje calculado.
* **`Estado`:**
  * `OK` (Verde): Ambos umbrales coinciden con el cálculo teórico.
  * `ERROR` (Rojo): Al menos uno de los recursos tiene un porcentaje desalineado respecto al límite.

---

## Códigos de salida

* `0`: Auditoría completada con éxito.
* `1`: Parámetros no válidos o error de sintaxis.

