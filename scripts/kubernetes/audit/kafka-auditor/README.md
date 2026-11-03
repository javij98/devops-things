# Kubernetes Kafka / OCI Auditor

Audit script to track references to Kafka brokers and Oracle Cloud Infrastructure (OCI) endpoints across Deployments, ConfigMaps, and Secrets in a Kubernetes cluster.

## 📋 Description

`k8s-kafka-auditor.sh` inspects cluster namespaces for Kafka and OCI configuration patterns:
- **Deployments:** Container environment variables.
- **ConfigMaps:** Configuration keys and data payloads (`application.yml`, `properties`, etc.).
- **Secrets:** Base64-decoded values to identify exposed connection strings or credentials.

## 🛠️ Prerequisites

- `kubectl` with read access to the target cluster.
- `jq`
- `column` (util-linux)

## 🚀 Usage

```bash
./k8s-kafka-auditor.sh
```
