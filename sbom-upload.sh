================================================================================
FILE 1: .env
================================================================================

# Docker Registry
REGISTRY_HOST="docker.io"
REGISTRY_USER="your-docker-username"
REGISTRY_PASS="your-docker-password"

# Dependency-Track
DT_URL="http://127.0.0.1:8081"
API_KEY="your-dependency-track-api-key"

# Images to scan
# Format: "registry/image:tag|DT-project-name|parent-project-name"
IMAGES=(
  "docker.io/vantage/postgres:16-alpine|postgres|"
)


================================================================================
FILE 2: sbom-upload.sh
================================================================================

#!/bin/bash
set -euo pipefail
source .env

docker login "$REGISTRY_HOST" -u "$REGISTRY_USER" -p "$REGISTRY_PASS"

for ENTRY in "${IMAGES[@]}"; do
  IFS='|' read -r IMAGE PROJECT PARENT <<< "$ENTRY"
  NAME=$(basename "$IMAGE" | cut -d: -f1)
  SBOM="/tmp/sbom-${NAME}.json"

  docker pull "$IMAGE"
  trivy image --format cyclonedx --output "$SBOM" --insecure "$IMAGE"

  # Look up existing project UUID by name
  UUID=$(curl -sk "${DT_URL}/api/v1/project/lookup?name=${PROJECT}&version=latest" \
    -H "X-Api-Key: ${API_KEY}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['uuid'])")

  if [ -z "$UUID" ]; then
    echo "ERROR: Project '${PROJECT}' not found in Dependency-Track. Please create it manually first."
    continue
  fi

  echo "Found project UUID: $UUID"

  # Upload SBOM using project UUID
  HTTP=$(curl -sk -o /dev/null -w "%{http_code}" \
    -X POST "${DT_URL}/api/v1/bom" \
    -H "X-Api-Key: ${API_KEY}" \
    -F "project=${UUID}" \
    -F "bom=@${SBOM}")

  echo "Done: $NAME -> HTTP $HTTP"
done

================================================================================
INSTRUCTIONS
================================================================================

1. Save the .env section as: .env
2. Save the script section as: sbom-upload.sh
3. Fill in your actual values in .env
4. Make script executable: chmod +x sbom-upload.sh
5. Run: ./sbom-upload.sh

NOTE: Project must be created manually in Dependency-Track UI before running.
URL: http://127.0.0.1:8080

