#!/usr/bin/env bash
# Thin wrapper so the resource-scaffolding tool matches the tools/*.sh convention.
# See tools/add-resource.js for the actual logic and usage.
set -euo pipefail
cd "$(dirname "$0")/.."
exec node tools/add-resource.js "$@"
