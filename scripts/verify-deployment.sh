#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"

echo "Checking backend rollout..."
kubectl rollout status deployment/backend \
  --namespace="$NAMESPACE" --timeout=180s

echo "Checking frontend rollout..."
kubectl rollout status deployment/frontend \
  --namespace="$NAMESPACE" --timeout=180s

echo "Checking application resources..."
kubectl get deployments,services,pods \
  --namespace="$NAMESPACE"

echo "Deployment verification completed."
