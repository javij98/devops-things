# Kubernetes Kafka / OCI Auditor

Script de auditoría para rastrear referencias a brokers Kafka y endpoints OCI en despliegues, ConfigMaps y Secretos dentro de un clúster Kubernetes.

## 📋 Descripción

El script `k8s-kafka-auditor.sh` inspecciona todos los namespaces del clúster buscando patrones de configuración relacionados con Kafka / Oracle Cloud Infrastructure:
- **Deployments:** Variables de entorno definidas en contenedores.
- **ConfigMaps:** Claves y datos de configuración (`application.yml`, `properties`, etc.).
- **Secrets:** Valores decodificados en Base64 para detectar cadenas de conexión o credenciales expuestas.

## 🛠️ Requisitos

- `kubectl` configurado con acceso de lectura sobre el clúster.
- `jq`
- `column` (util-linux)

## 🚀 Uso

```bash
./k8s-kafka-auditor.sh
```
