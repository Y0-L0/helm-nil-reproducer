#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mapfile -t BINARIES < <(ls "$SCRIPT_DIR/helm-bin"/helm-* | sort -V)

BASELINE="${BINARIES[0]}"
BASELINE_OUT="$(mktemp)"
trap 'rm -f "$BASELINE_OUT"' EXIT

"$BASELINE" template "$SCRIPT_DIR" -f "$SCRIPT_DIR/override-null.yaml" > "$BASELINE_OUT"

for HELM_BINARY in "${BINARIES[@]:1}"; do
  THIS_OUT="$(mktemp)"
  "$HELM_BINARY" template "$SCRIPT_DIR" -f "$SCRIPT_DIR/override-null.yaml" > "$THIS_OUT"
  diff -u --label "$(basename "$BASELINE")" --label "$(basename "$HELM_BINARY")" "$BASELINE_OUT" "$THIS_OUT" || true
  rm -f "$THIS_OUT"
done
