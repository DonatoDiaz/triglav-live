# Использование Triglav Live

## 1. Диагностика

```bash
triglav-doctor            # полный отчёт, сохраняется в /root/triglav-reports
triglav-doctor --short    # краткая сводка
lsblk -f                  # разделы и ФС
```

Отчёт содержит: режим загрузки, Secure Boot, CPU/RAM, железо, SMART/NVMe,
LUKS/LVM/RAID, кандидатов на root, загрузчик, ядра/initramfs, pacman, ошибки
dmesg/journal, сеть.

## 2. Монтирование системы

```bash
triglav-mount             # интерактивный выбор
triglav-mount --auto      # самый большой Linux-раздел
triglav-mount --dev /dev/nvme0n1p2
triglav-mount --status
triglav-mount --umount
```

Для btrfs автоматически монтируются типовые субтома (`@`, `@home`, `@root`,
`@var`, `@cache`, `@log`, `@snapshots`). EFI-раздел монтируется туда, куда
указывает `fstab` установленной системы.

## 3. Ремонт

```bash
triglav-repair menu
triglav-repair boot                 # grub/systemd-boot + mkinitcpio -P
triglav-repair fsck /dev/nvme0n1p2  # btrfs: read-only по умолчанию
triglav-repair fsck /dev/... --repair   # btrfs check --repair (опасно)
triglav-repair pacman               # db.lck, ключи, база, переустановка ядра
triglav-repair fstab                # genfstab -U
triglav-repair password             # сброс пароля root
triglav-repair snapshot             # btrfs-снимок перед изменениями
triglav-repair rescue-disks /dev/sdX /dev/sdY
triglav-repair chroot               # arch-chroot /mnt
```

`--yes` отключает подтверждения (используйте осторожно).

## 4. Сеть

```bash
triglav-net status
triglav-net wifi-list
triglav-net wifi "MyWiFi" "password"
triglav-net dhcp enp3s0
triglav-net test
```

## 5. Дополнительные инструменты

```bash
triglav-tools list
triglav-tools install gparted
triglav-tools group filesystem
triglav-tools search hdd
```

Пакеты ставятся в RAM-overlay и исчезают после перезагрузки. Для постоянной
работы используйте установленную систему через chroot или persistence-раздел.

## 6. Логи

```bash
triglav-collect
# /root/triglav-reports/triglav-collect-*.tar.gz
```

## 7. AI-ремонт одним промптом

```bash
triglav-ai-setup
triglav ask "после обновления система падает в emergency mode"
```

См. `docs/AI.md`.

## Типовые сценарии

| Симптом | Действия |
|---|---|
| GRUB rescue / чёрный экран | `triglav-mount`, проверить `/mnt/boot`, `triglav-repair boot` |
| Kernel panic, нет initramfs | `triglav-repair boot` (mkinitcpio -P) |
| Root read-only, ошибки ФС | `triglav-repair fsck`, SMART через `triglav-doctor` |
| Сломался pacman после обновления | `triglav-repair pacman` |
| Забыт пароль | `triglav-repair password` |
| Диск сыпется | `triglav-repair rescue-disks`, ремонт копии |
| Нет Wi-Fi | `triglav-net wifi-list` → `triglav-net wifi SSID` |
