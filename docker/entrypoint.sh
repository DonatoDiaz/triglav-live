#!/usr/bin/env bash
# Runs inside the archlinux container (root). Builds the ISO with mkarchiso.
set -euo pipefail

REPO="${REPO_ROOT:-/repo}"
WORK="/tmp/tgwork"
PROFILE="/tmp/tgprofile"
OUT="${REPO}/${OUT_DIR:-out}"

export LC_ALL=C

echo "==> Installing archiso tooling"
pacman -Syu --noconfirm --needed archiso jq rsync curl tar xz zstd >/dev/null

echo "==> Preparing releng profile"
rm -rf "$WORK" "$PROFILE"
mkdir -p "$WORK" "$OUT"
cp -a /usr/share/archiso/configs/releng "$PROFILE"

echo "==> Applying Triglav overlay"
rsync -a "$REPO/profile/overlay/" "$PROFILE/airootfs/"
if [[ -d "$REPO/profile/profile-overlay" ]]; then
  rsync -a "$REPO/profile/profile-overlay/" "$PROFILE/"
fi

echo "==> Adding packages"
if [[ -f "$REPO/profile/packages.add" ]]; then
  cat "$REPO/profile/packages.add" >> "$PROFILE/packages.x86_64"
fi
if [[ -f "$REPO/profile/packages.remove" ]]; then
  grep -vxF -f "$REPO/profile/packages.remove" "$PROFILE/packages.x86_64" > "$PROFILE/packages.tmp" || true
  mv "$PROFILE/packages.tmp" "$PROFILE/packages.x86_64"
fi
awk 'NF && !seen[$0]++' "$PROFILE/packages.x86_64" > "$PROFILE/packages.tmp"
mv "$PROFILE/packages.tmp" "$PROFILE/packages.x86_64"

echo "==> Patching profile metadata"
sed -i \
  -e "s|^iso_name=.*|iso_name=\"${ISO_NAME}\"|" \
  -e "s|^iso_label=.*|iso_label=\"${ISO_LABEL}\"|" \
  -e "s|^iso_publisher=.*|iso_publisher=\"${ISO_PUBLISHER}\"|" \
  -e "s|^iso_application=.*|iso_application=\"${ISO_APPLICATION}\"|" \
  -e "s|^iso_version=.*|iso_version=\"${ISO_VERSION}\"|" \
  "$PROFILE/profiledef.sh"

if [[ "${AIROOTFS_COMPRESSION}" == "zstd" ]]; then
  sed -i "s|^airootfs_image_tool_options=.*|airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')|" "$PROFILE/profiledef.sh"
fi

echo "==> Branding boot entries"
for d in "$PROFILE/syslinux" "$PROFILE/grub" "$PROFILE/efiboot"; do
  [[ -d "$d" ]] || continue
  grep -rl "Arch Linux" "$d" 2>/dev/null | while read -r f; do
    sed -i "s|Arch Linux install medium|Triglav Live|g; s|Arch Linux|Triglav Live|g" "$f"
  done
done

echo "==> Embedding TriglavCode (EMBED_TRIGLAVCODE=${EMBED_TRIGLAVCODE})"
mkdir -p "$PROFILE/airootfs/opt/triglavcode"
if [[ "${EMBED_TRIGLAVCODE}" == "1" ]]; then
  TMPTC="$(mktemp -d)"
  URL="${TRIGLAVCODE_TARBALL_URL}"
  if [[ -z "$URL" ]]; then
    API="https://api.github.com/repos/${TRIGLAVCODE_REPO}/releases"
    if [[ "${TRIGLAVCODE_TAG}" == "latest" ]]; then
      META="$(curl -fsSL "${API}/latest")"
    else
      META="$(curl -fsSL "${API}/tags/${TRIGLAVCODE_TAG}")"
    fi
    URL="$(printf '%s' "$META" | jq -r '[.assets[]? | select(.name | endswith("linux-x64.tar.gz"))][0].browser_download_url // empty')"
    [[ -n "$URL" ]] || { echo "ERROR: no linux-x64.tar.gz asset for ${TRIGLAVCODE_REPO}@${TRIGLAVCODE_TAG}" >&2; exit 1; }
  fi

  echo "    source: $URL"
  if [[ -f "$URL" ]]; then
    cp "$URL" "$TMPTC/tc.tar.gz"
  elif [[ -f "$REPO/$URL" ]]; then
    cp "$REPO/$URL" "$TMPTC/tc.tar.gz"
  else
    curl -fL --retry 3 -o "$TMPTC/tc.tar.gz" "$URL"
  fi

  tar xzf "$TMPTC/tc.tar.gz" -C "$TMPTC"
  SRC="$(find "$TMPTC" -maxdepth 1 -type d -name 'triglavcode-*' | head -1)"
  [[ -n "$SRC" ]] || { echo "ERROR: unexpected TriglavCode archive layout" >&2; exit 1; }
  install -m 0755 "$SRC/triglavcode" "$PROFILE/airootfs/opt/triglavcode/triglavcode"
  cp -a "$SRC/extras" "$PROFILE/airootfs/opt/triglavcode/" 2>/dev/null || true
  cp -a "$SRC/docs" "$PROFILE/airootfs/opt/triglavcode/" 2>/dev/null || true
  for f in LICENSE NOTICE README.md RELEASE_NOTES.md; do
    [[ -f "$SRC/$f" ]] && cp "$SRC/$f" "$PROFILE/airootfs/opt/triglavcode/"
  done
  rm -rf "$TMPTC"
  du -sh "$PROFILE/airootfs/opt/triglavcode"
else
  echo "    skipped; runtime fetch via triglav-code-fetch"
fi

echo "==> Fixing ownership and permissions"
chown -R root:root "$PROFILE/airootfs"
find "$PROFILE/airootfs/usr/local/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
find "$PROFILE/airootfs/usr/local/lib/triglav" -type f -exec chmod 0644 {} + 2>/dev/null || true
chmod 0755 "$PROFILE/airootfs/usr/local/share/triglav"/* 2>/dev/null || true
chmod 0755 "$PROFILE/airootfs/opt/triglavcode/triglavcode" 2>/dev/null || true
chmod 0700 "$PROFILE/airootfs/root" 2>/dev/null || true

# mkarchiso copies airootfs with --no-preserve=mode, so executable bits must be
# declared in profiledef.sh's file_permissions array.
PERM_FILE="/tmp/tg-file-permissions"
: > "$PERM_FILE"
while IFS= read -r f; do
  printf '  ["/%s"]="0:0:755"\n' "$f" >> "$PERM_FILE"
done < <(cd "$PROFILE/airootfs" && find usr/local/bin -type f | sort)
printf '  ["/opt/triglavcode/triglavcode"]="0:0:755"\n' >> "$PERM_FILE"
sed -i "/^file_permissions=(/r $PERM_FILE" "$PROFILE/profiledef.sh"

echo "==> Running mkarchiso"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
  chown -R "${HOST_UID}:${HOST_GID}" "$OUT" /var/cache/pacman/pkg 2>/dev/null || true
fi

echo "==> Build finished"
ls -lh "$OUT"
