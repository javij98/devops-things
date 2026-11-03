# Kubernetes Secret Copier

Script de administración para clonar un `Secret` de Kubernetes entre namespaces.

## 📋 Descripción

`copy-secrets.sh` extrae la definición de un secreto existente en un namespace de origen, elimina metadatos dinámicos del clúster (`creationTimestamp`, `resourceVersion`, `uid`) y lo aplica en el namespace de destino.

## 🛠️ Requisitos

- `kubectl` con permisos para leer en el namespace de origen y crear/actualizar secretos en el namespace de destino.

## 🚀 Uso

```bash
./copy-secrets.sh <source_namespace> <destination_namespace> <secret_name>
```

### Ejemplo

```bash
./copy-secrets.sh default app-prod db-credentials
```
