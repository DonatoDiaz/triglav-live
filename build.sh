#!/usr/bin/env bash
# Build the Triglav Live ISO.
#
# Default mode: run mkarchiso inside an Arch Linux Docker container.
# --in-container: run the build directly (used by CI and docker/entrypoint.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

IN_CONTAINER=0
[[ "${1:-}" == "--in-container" ]] && IN_CONTAINER=1

if [[ -f config.env ]]; then
  # shellcheck disable=SC1091
  source config.env
elif [[ -f config.env.example ]]; then
  # shellcheck disable=SC1091
  source config.env.example
fi

: "${ISO_NAME:=triglav-live}"
: "${ISO_LABEL:=TRIGLAV_LIVE}"
: "${ISO_VERSION:=0.1.0}"
: "${ISO_PUBLISHER:=Triglav Labs}"
: "${ISO_APPLICATION:=Triglav Live — rescue and repair environment}"
: "${EMBED_TRIGLAVCODE:=1}"
: "${TRIGLAVCODE_REPO:=DonatoDiaz/triglavcode}"
: "${TRIGLAVCODE_TAG:=latest}"
: "${TRIGLAVCODE_TARBALL_URL:=}"
: "${AIROOTFS_COMPRESSION:=xz}"
: "${OUT_DIR:=out}"

export ISO_NAME ISO_LABEL ISO_VERSION ISO_PUBLISHER ISO_APPLICATION
export EMBED_TRIGLAVCODE TRIGLAVCODE_REPO TRIGLAVCODE_TAG TRIGLAVCODE_TARBALL_URL
export AIROOTFS_COMPRESSION OUT_DIR REPO_ROOT="$ROOT"

if [[ "$IN_CONTAINER" == "1" ]]; then
  exec "$ROOT/docker/entrypoint.sh"
fi

command -v docker >/dev/null 2>&1 || {
  echo "docker is required (or run: sudo pacman -S archiso && ./build.sh --in-container)" >&2
  exit 1
}

echo "==> Triglav Live ${ISO_VERSION}"
echo "==> Building in archlinux:latest (privileged container)"

mkdir -p "$ROOT/.build/pacman-cache" "$ROOT/$OUT_DIR"

docker run --rm --privileged \
  --network host \
  -e ISO_NAME -e ISO_LABEL -e ISO_VERSION -e ISO_PUBLISHER -e ISO_APPLICATION \
  -e EMBED_TRIGLAVCODE -e TRIGLAVCODE_REPO -e TRIGLAVCODE_TAG -e TRIGLAVCODE_TARBALL_URL \
  -e AIROOTFS_COMPRESSION -e OUT_DIR -e REPO_ROOT=/repo \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$ROOT:/repo" -v "$ROOT/.build/pacman-cache:/var/cache/pacman/pkg" -w /repo \
  archlinux:latest bash /repo/docker/entrypoint.sh

ISO="$(find "$ROOT/$OUT_DIR" -maxdepth 1 -name '*.iso' -printf '%f\n' | sort | tail -1)"
if [[ -n "$ISO" ]]; then
  ( cd "$ROOT/$OUT_DIR" && sha256sum "$ISO" > "$ISO.sha256" )
  echo "==> Done: $ROOT/$OUT_DIR/$ISO"
  ls -lh "$ROOT/$OUT_DIR/$ISO"
fi
