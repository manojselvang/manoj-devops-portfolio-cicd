
#!/usr/bin/env bash
set -euo pipefail

echo "Validating Kubernetes manifests..."

kubectl apply --dry-run=client -f k8s/backend.yaml
kubectl apply --dry-run=client -f k8s/frontend.yaml

echo "Manifest validation completed."
