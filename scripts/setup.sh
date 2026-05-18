#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_CONFIG="$ROOT/Config/MacTrack.local.xcconfig"

if [[ -f "$LOCAL_CONFIG" ]]; then
  echo "Config/MacTrack.local.xcconfig already exists."
else
  cat > "$LOCAL_CONFIG" <<'EOF'
// Private signing overrides (not committed).
DEVELOPMENT_TEAM =
PRODUCT_BUNDLE_IDENTIFIER = com.example.MactrackTime
EOF
  echo "Created Config/MacTrack.local.xcconfig — set DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER."
fi

echo "Edit Config/MacTrack.xcconfig or Config/MacTrack.local.xcconfig, then open MacTrack.xcodeproj."
