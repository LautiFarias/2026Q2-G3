#!/usr/bin/env bash
# Vacía un bucket versionado (objetos, versiones y delete markers) para que
# CloudFormation pueda borrarlo. Se usa desde el destroy de modules/s3-bucket.
set -euo pipefail
BUCKET="$1"

aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null || exit 0

while true; do
  aws s3api list-object-versions --bucket "$BUCKET" --max-items 500 --output json > /tmp/versiones.json
  jq '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}' /tmp/versiones.json > /tmp/borrar.json
  if [ "$(jq '.Objects | length' /tmp/borrar.json)" -eq 0 ]; then
    break
  fi
  aws s3api delete-objects --bucket "$BUCKET" --delete file:///tmp/borrar.json > /dev/null
done
echo "Bucket $BUCKET vacío."
