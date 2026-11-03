#!/bin/bash

# Define the context and search pattern (Regex for OCI or Kafka strings)
CONTEXT="produccion"
SEARCH_PATTERN="oraclecloud\.com|oci\.once\.es|oci\.pruebas11\.net|kafka"

echo "========================================================================="
echo "STARTING KUBERNETES AUDIT FOR KAFKA-OCI"
echo "Context: $CONTEXT"
echo "========================================================================="

# 1. Audit Environment Variables in Deployments
echo -e "\n[+] ANALYZING ENVIRONMENT VARIABLES IN DEPLOYMENTS..."
kubectl get deployments --all-namespaces --context $CONTEXT -o json | jq -r --arg pat "(?i)$SEARCH_PATTERN" '
  .items[] |
  .metadata.namespace as $ns |
  .metadata.name as $name |
  .spec.template.spec.containers[]? |
  select(.env != null) |
  .env[] |
  select(.value != null) |
  select(.value | test($pat)) |
  "NAMESPACE: \($ns) | DEPLOYMENT: \($name) | VAR: \(.name) | VALUE: \(.value)"
' | column -t -s '|'

# 2. Audit ConfigMaps (application.yml, properties, jaas.conf, etc.)
echo -e "\n[+] ANALYZING CONFIGMAPS..."
kubectl get cm --all-namespaces --context $CONTEXT -o json | jq -r --arg pat "(?i)$SEARCH_PATTERN" '
  .items[] |
  select(.data != null) |
  .metadata.namespace as $ns |
  .metadata.name as $name |
  .data | to_entries[] |
  select(.value | test($pat)) |
  "NAMESPACE: \($ns) | CONFIGMAP: \($name) | KEY: \(.key) | HAS_MATCH: YES"
' | column -t -s '|'

# 3. Audit Secrets (Security Alert: Validating leaks or mismanagement)
echo -e "\n[+] SEARCHING KAFKA IN SECRETS (Validating leaks or mismanagement)..."
kubectl get secrets --all-namespaces --context $CONTEXT -o json | jq -r --arg pat "(?i)$SEARCH_PATTERN" '
  .items[] |
  select(.type == "Opaque") |
  select(.data != null) |
  .metadata.namespace as $ns |
  .metadata.name as $name |
  .data | to_entries[] |
  select((.value | @base64d) | test($pat)) |
  "NAMESPACE: \($ns) | SECRET: \($name) | KEY: \(.key) | WARNING: KAFKA STRING FOUND IN SECRET"
' | column -t -s '|'

echo -e "\n========================================================================="
echo "AUDIT COMPLETED"
echo "========================================================================="