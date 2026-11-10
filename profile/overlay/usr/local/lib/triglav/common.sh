#!/usr/bin/env bash
# Triglav Live shared helpers.
# shellcheck shell=bash

TG_VERSION="${TG_VERSION:-0.1.0}"
TG_MOUNT="${TG_MOUNT:-/mnt}"
TG_REPORT_DIR="${TG_REPORT_DIR:-/root/triglav-reports}"
TG_LIB_DIR="${TG_LIB_DIR:-/usr/local/lib/triglav}"
TG_SHARE_DIR="${TG_SHARE_DIR:-/usr/local/share/triglav}"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_P=$'\033[38;5;141m'
  C_VIOLET=$'\033[38;5;99m'
  C_G=$'\033[38;5;114m'
  C_Y=$'\033[38;5;214m'
  C_R=$'\033[38;5;203m'
else
  C_RESET= C_DIM= C_BOLD= C_P= C_VIOLET= C_G= C_Y= C_R=
fi

tg_info()  { printf '%s[triglav]%s %s\n' "$C_P" "$C_RESET" "$*"; }
tg_ok()    { printf '%s[ ok ]%s %s\n' "$C_G" "$C_RESET" "$*"; }
tg_warn()  { printf '%s[warn]%s %s\n' "$C_Y" "$C_RESET" "$*" >&2; }
tg_err()   { printf '%s[fail]%s %s\n' "$C_R" "$C_RESET" "$*" >&2; }
tg_step()  { printf '\n%s==>%s %s%s%s\n' "$C_P" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
tg_dim()   { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

tg_need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    tg_err "нужен root. Запустите: sudo $0 $*"
    exit 1
  fi
}

tg_have() { command -v "$1" >/dev/null 2>&1; }

tg_confirm() {
  local prompt="${1:-Продолжить?}" answer
  if [[ ${TG_ASSUME_YES:-0} == 1 ]]; then
    return 0
  fi
  read -r -p "$(printf '%s[?]%s %s [y/N] ' "$C_Y" "$C_RESET" "$prompt")" answer
  [[ "$answer" =~ ^([yY]|[yY][eE][sS]|д|да)$ ]]
}

tg_report_path() {
  local name="${1:-report}"
  mkdir -p "$TG_REPORT_DIR"
  printf '%s/%s-%s.txt' "$TG_REPORT_DIR" "$name" "$(date +%Y%m%d-%H%M%S)"
}

tg_section() {
  printf '\n%s──────── %s ────────%s\n' "$C_VIOLET" "$*" "$C_RESET"
}

tg_is_mounted() {
  local target="$1"
  grep -qs " ${target} " /proc/mounts || mountpoint -q "$target" 2>/dev/null
}

# All whole disks, excluding loop/rom devices.
tg_disks() {
  lsblk -dpno NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}'
}

# Linux filesystem partitions that may contain an installed system.
tg_root_candidates() {
  lsblk -rno NAME,FSTYPE,SIZE | while read -r name fstype size; do
    case "$fstype" in
      ext2|ext3|ext4|btrfs|xfs|f2fs) printf '/dev/%s\t%s\t%s\n' "$name" "$fstype" "$size" ;;
    esac
  done
}

tg_fs_type() { blkid -s TYPE -o value "$1" 2>/dev/null || true; }
tg_fs_uuid() { blkid -s UUID -o value "$1" 2>/dev/null || true; }

tg_parttype() {
  lsblk -rno PARTTYPE "$1" 2>/dev/null | head -1
}

tg_efi_candidates() {
  lsblk -rno NAME,FSTYPE,PARTTYPE | while read -r name fstype parttype; do
    if [[ "$fstype" == "vfat" ]] && [[ "${parttype,,}" == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" || "${parttype,,}" == "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7" ]]; then
      printf '/dev/%s\n' "$name"
    fi
  done
}

# Mount an installed Linux root read-write at $TG_MOUNT.
# Also mounts common btrfs subvolumes when present.
tg_mount_root() {
  local dev="$1" type
  type="$(tg_fs_type "$dev")"
  [[ -n "$type" ]] || { tg_err "не удалось определить ФС на $dev"; return 1; }
  mkdir -p "$TG_MOUNT"
  if tg_is_mounted "$TG_MOUNT"; then
    tg_warn "$TG_MOUNT уже смонтирован; размонтируйте сначала (triglav-mount --umount)"
    return 1
  fi
  tg_info "монтирую $dev ($type) → $TG_MOUNT"
  if ! mount "$dev" "$TG_MOUNT"; then
    tg_err "mount не удался: $dev"
    return 1
  fi
  if [[ "$type" == "btrfs" ]]; then
    # Default subvolume may be the top level while the system lives in @.
    if [[ ! -f "$TG_MOUNT/etc/os-release" ]] && btrfs subvolume show "$TG_MOUNT/@" >/dev/null 2>&1; then
      umount "$TG_MOUNT"
      mount -o subvol=@ "$dev" "$TG_MOUNT" && tg_dim "  + root subvol @"
    fi
    local sv target
    while read -r sv; do
      case "$sv" in
        @) continue ;;
        @home) target="home" ;;
        @root) target="root" ;;
        @var) target="var" ;;
        @srv) target="srv" ;;
        @cache) target="var/cache" ;;
        @log) target="var/log" ;;
        @tmp) target="tmp" ;;
        @snapshots) target=".snapshots" ;;
        *) target="$sv" ;;
      esac
      mkdir -p "$TG_MOUNT/$target"
      mount -o "subvol=$sv" "$dev" "$TG_MOUNT/$target" 2>/dev/null \
        && tg_dim "  + subvol $sv → /$target"
    done < <(btrfs subvolume list "$TG_MOUNT" 2>/dev/null | awk '{print $NF}' | sed 's|.*/||' | sort -u)
  fi
  if [[ -f "$TG_MOUNT/etc/os-release" ]]; then
    # shellcheck disable=SC1091
    tg_ok "найдена система: $(. "$TG_MOUNT/etc/os-release"; echo "${PRETTY_NAME:-?}")"
  else
    tg_warn "$dev не похож на Linux root (нет /etc/os-release)"
  fi
}

# Mount the EFI System Partition in the right place for the installed system.
tg_mount_efi() {
  local dev target="/boot" fstab_target
  dev="$(tg_efi_candidates | head -1)"
  if [[ -z "$dev" ]]; then
    tg_warn "EFI-раздел не найден"
    return 1
  fi
  if [[ -f "$TG_MOUNT/etc/fstab" ]]; then
    fstab_target="$(awk '$3 ~ /^(vfat|fat|msdos)$/ {print $2; exit}' "$TG_MOUNT/etc/fstab" 2>/dev/null)"
    [[ -n "$fstab_target" ]] && target="$fstab_target"
  fi
  target="${TG_MOUNT%/}/${target#/}"
  # If the fstab target is inside another mount, trim to the mount root.
  mkdir -p "$target"
  if mountpoint -q "$target" 2>/dev/null; then
    tg_dim "  EFI уже смонтирован в $target"
    return 0
  fi
  mount "$dev" "$target" && tg_dim "  EFI $dev → $target"
}

tg_umount_root() {
  if tg_is_mounted "$TG_MOUNT"; then
    tg_info "размонтирую $TG_MOUNT"
    umount -R "$TG_MOUNT" 2>/dev/null || umount -lR "$TG_MOUNT" 2>/dev/null || true
  fi
}

tg_chroot() {
  if [[ ! -x "$TG_MOUNT/usr/bin/arch-chroot" && ! -x /usr/bin/arch-chroot ]]; then
    tg_err "arch-chroot не найден"
    return 1
  fi
  arch-chroot "$TG_MOUNT" "$@"
}

tg_pretty_bytes() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1"; }
