# DevOps Things

Repositorio centralizado de herramientas, scripts de automatización y plantillas Kubernetes para administración, auditoría y monitoreo.

## 📁 Estructura del Repositorio

```text
devops-things/
├── kubernetes/
│   └── templates/                # Plantillas y manifiestos declarativos de Kubernetes
│       ├── configMaps/           # Ejemplos y plantillas de ConfigMaps
│       ├── cronjobs/             # Plantillas de CronJobs (e.g. backup)
│       └── pods/                 # Pods utilitarios para administración (e.g. AWS CLI)
└── scripts/                      # Colección de scripts y utilidades operacionales
    ├── git/                      # Automatización y gestión de repositorios Git/Bitbucket
    │   ├── clone-bitbucket-repo/ # Clonado masivo interactivo de repos por proyecto
    │   └── refresh-local-git-repos/ # Sincronización interactiva y clonado incremental
    └── kubernetes/               # Utilidades operacionales para Kubernetes
        ├── admin/                # Scripts de administración (e.g. copia de secretos entre namespaces)
        ├── audit/                # Auditoría de recursos (HPA/autoscaling, Kafka/OCI)
        └── monitoring/           # Monitoreo de recursos y latencia/salud de pods
```

## 🛠️ Componentes

### Scripts de Git / SCM
- **[clone-bitbucket-repo](scripts/git/clone-bitbucket-repo/):** Script interactivo para clonar repositorios de proyectos Bitbucket.
- **[refresh-local-git-repos](scripts/git/refresh-local-git-repos/):** Script interactivo con soporte CLI para refrescar repositorios locales mediante `fetch`/`pull --ff-only` y clonar repositorios nuevos del proyecto remoto.

### Scripts de Kubernetes
- **[admin/copy-secrets](scripts/kubernetes/admin/):** Copia segura de secretos entre diferentes namespaces en Kubernetes.
- **[audit/audit-autoscaling](scripts/kubernetes/audit/audit-autoscaling/):** Auditoría interactiva y detallada de HPAs, métricas y límites de recursos.
- **[audit/kafka-auditor](scripts/kubernetes/audit/kafka-auditor/):** Rastreo de configuraciones y credenciales Kafka/OCI en despliegues, ConfigMaps y secretos.
- **[monitoring/monitor-pod-resources](scripts/kubernetes/monitoring/monitor-pod-resources/):** Monitoreo continuo de uso de CPU y memoria de pods en tiempo real.
- **[monitoring/pods-health](scripts/kubernetes/monitoring/pods-health/):** Cálculo de tiempos de respuesta de endpoints de salud (readiness/liveness) y simulación de fallos.
