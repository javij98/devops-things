# Kubernetes Secret Copier

Administration script to replicate a Kubernetes `Secret` between namespaces.

## 📋 Description

`copy-secrets.sh` extracts an existing secret definition from a source namespace, strips dynamic cluster metadata (`creationTimestamp`, `resourceVersion`, `uid`), and applies it into the destination namespace.

## 🛠️ Prerequisites

- `kubectl` configured with read permissions in the source namespace and create/update permissions in the target namespace.

## 🚀 Usage

```bash
./copy-secrets.sh <source_namespace> <destination_namespace> <secret_name>
```

### Example

```bash
./copy-secrets.sh default app-prod db-credentials
```
