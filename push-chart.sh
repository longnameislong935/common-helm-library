#!/usr/bin/env bash
#
# push-chart.sh — bump the chart patch version, package, push to GHCR, clean up.
#
# Steps:
#   1. Increment the patch component of `version:` in Chart.yaml by one.
#   2. helm package .
#   3. helm push the resulting .tgz to the OCI registry.
#   4. Delete the local .tgz.
#
# Prereqs:
#   - helm 3.8+ (OCI support)
#   - Logged in to the registry first, e.g.:
#       echo "$GITHUB_TOKEN" | helm registry login ghcr.io -u <user> --password-stdin
#
# Env overrides:
#   OCI_REPO   target OCI repo (default: oci://ghcr.io/longnameislong935/common-helm-library)
#              helm appends the chart name, giving:
#              ghcr.io/longnameislong935/common-helm-library/common-helm-library:<version>

set -euo pipefail

# Always operate from the repo root (this script lives there).
cd "$(dirname "$0")"

CHART_FILE="Chart.yaml"
OCI_REPO="${OCI_REPO:-oci://ghcr.io/longnameislong935/common-helm-library}"

# --- 1. Read + increment the patch version -------------------------------
# `tr -d '\r'` guards against Windows (CRLF) line endings in Chart.yaml.
current="$(awk '/^version:/ {print $2; exit}' "$CHART_FILE" | tr -d '\r\n')"
if [[ -z "${current}" ]]; then
  echo "ERROR: could not find a 'version:' line in ${CHART_FILE}" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "${current}"
if ! [[ "${patch}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: unexpected version '${current}' (expected MAJOR.MINOR.PATCH)" >&2
  exit 1
fi

new="${major}.${minor}.$((patch + 1))"
echo ">> bumping version: ${current} -> ${new}"

# Portable in-place edit (works with GNU and BSD sed).
sed -i.bak -E "s/^version:.*/version: ${new}/" "${CHART_FILE}"
rm -f "${CHART_FILE}.bak"

# --- 2. Package ----------------------------------------------------------
echo ">> helm package ."
pkg="$(helm package . | awk '/Successfully packaged chart/ {print $NF}')"
if [[ -z "${pkg}" || ! -f "${pkg}" ]]; then
  echo "ERROR: helm package did not produce a .tgz" >&2
  exit 1
fi
echo ">> packaged: ${pkg}"

# --- 3. Push -------------------------------------------------------------
echo ">> helm push ${pkg} ${OCI_REPO}"
helm push "${pkg}" "${OCI_REPO}"

# --- 4. Delete the local package ----------------------------------------
echo ">> removing local package ${pkg}"
rm -f "${pkg}"

echo ">> done. published ${new} to ${OCI_REPO}"
