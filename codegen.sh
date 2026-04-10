#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# codegen.sh — OpenAPI → Dart model codegen pipeline
#
# Steps:
#   1. Export the OpenAPI spec from the NestJS backend (one of two strategies)
#   2. Run gen_dart_models.js to generate Dart model classes
#   3. Run `flutter analyze` to verify no compilation errors
#
# Strategies for obtaining the spec:
#   A) LIVE SERVER  — hit http://localhost:3008/api/docs-json  (fastest)
#   B) SCRIPT BOOT  — run scripts/export-spec.ts in the backend (no live server needed,
#                     but requires DATABASE_URL to point to a reachable Postgres)
#
# Usage:
#   bash codegen.sh                  # auto-detect (A then B)
#   FORCE_SCRIPT=1 bash codegen.sh   # force strategy B
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "$0")/../textile-erp-backend" 2>/dev/null && pwd || echo "")"
FLUTTER_DIR="$(cd "$(dirname "$0")" && pwd)"
SPEC_FILE="${BACKEND_DIR}/openapi.json"
SERVER_URL="${BACKEND_URL:-http://localhost:3008}"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

# ── 1. Export spec ──────────────────────────────────────────────────────────────
if [[ -z "${BACKEND_DIR}" ]]; then
  error "Backend dir not found. Expected at '../textile-erp-backend' relative to this script."
fi

FORCE_SCRIPT="${FORCE_SCRIPT:-0}"

if [[ "${FORCE_SCRIPT}" != "1" ]] && curl -sf "${SERVER_URL}/api/docs-json" -o "${SPEC_FILE}" 2>/dev/null; then
  info "Spec fetched from running server → ${SPEC_FILE}"
else
  warn "Server not reachable at ${SERVER_URL}; falling back to script-based export"
  if [[ ! -d "${BACKEND_DIR}" ]]; then
    error "Backend not found at ${BACKEND_DIR}"
  fi

  info "Building backend and exporting spec…"
  cd "${BACKEND_DIR}"
  npm run build --silent
  npx ts-node -r tsconfig-paths/register scripts/export-spec.ts
  cd "${FLUTTER_DIR}"

  info "Spec exported → ${SPEC_FILE}"
fi

if [[ ! -f "${SPEC_FILE}" ]]; then
  error "Spec file still not found at ${SPEC_FILE}"
fi

# ── 2. Generate Dart models ─────────────────────────────────────────────────────
info "Generating Dart models from spec…"
node "${FLUTTER_DIR}/scripts/gen_dart_models.js" \
  --spec "${SPEC_FILE}" \
  --out  "${FLUTTER_DIR}/lib/core/models/generated"

# ── 3. Verify with flutter analyze ─────────────────────────────────────────────
info "Running flutter analyze…"
cd "${FLUTTER_DIR}"
flutter analyze --no-fatal-infos 2>&1 | tail -5

info "Done! Generated models are in lib/core/models/generated/models_generated.dart"
echo ""
echo "Next steps:"
echo "  • Import generated types in your providers/screens:"
echo "    import '../../../core/models/generated/models_generated.dart';"
echo "  • Or re-export from models.dart:"
echo "    export 'generated/models_generated.dart';"
