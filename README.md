# Triglav Live

Аварийный live-образ на базе Arch Linux в стилистике Triglav Labs: диагностика,
ремонт загрузчика и файловых систем, сеть, и **TriglavCode** для решения проблем
одним промптом.

> Образ не подписан для Secure Boot. Загружайте с выключенным Secure Boot либо
> подпишите загрузчик самостоятельно.
>
> TriglavCode (Bun) требует CPU не ниже x86-64-v2 (SSE4.2/POPCNT). На очень
> старых CPU скрипты `triglav-*` работают, а AI-часть может не запуститься.

## Что внутри

- Минимальный archiso (releng) + набор аварийных инструментов.
- `triglav-doctor` — read-only отчёт: железо, SMART, разделы, LUKS/LVM/RAID,
  загрузчик, fstab, ядра/initramfs, pacman, journal/dmesg, сеть.
- `triglav-mount` — находит и монтирует установленную систему (ext4/btrfs/xfs/f2fs,
  включая btrfs-субтома) и EFI-раздел для chroot.
- `triglav-repair` — загрузчик (`grub-install`/`bootctl`), `mkinitcpio -P`,
  `fsck`, pacman (lock/ключи/база), `fstab`, сброс пароля, btrfs-снимок,
  клонирование диска через `ddrescue`.
- `triglav-net` — iwd/Wi-Fi, DHCP, проверка связности.
- `triglav-tools` — доустановка пакетов из сети (образ остаётся компактным).
- `triglav-ask "проблема"` — собирает диагностику, формирует промпт и запускает
  TriglavCode с агентом-ремонтником.
- `triglav-ai-setup` — настройка любого OpenAI-совместимого провайдера.

## Сборка

Требуется Docker (или `archiso` локально) и ~15 ГБ свободного места.

```bash
cp config.env.example config.env      # по желанию
./build.sh                            # Docker + mkarchiso
# результат: out/triglav-live-*.iso (+ .sha256)
```

Локально без Docker:

```bash
sudo pacman -S archiso
./build.sh --in-container
```

Опции `config.env`:

| Переменная | Значение |
|---|---|
| `ISO_VERSION` | версия образа |
| `EMBED_TRIGLAVCODE` | `1` — вшить TriglavCode в ISO |
| `TRIGLAVCODE_TAG` | `latest` или тег релиза |
| `TRIGLAVCODE_TARBALL_URL` | локальный путь/URL архива (офлайн-сборка) |
| `AIROOTFS_COMPRESSION` | `xz` (меньше) или `zstd` (быстрее) |

## Запись на USB

```bash
sudo dd if=out/triglav-live-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Или `sudo cp out/triglav-live-*.iso /dev/sdX` (образ гибридный, BIOS+UEFI).

## Быстрый старт после загрузки

Загрузка: BIOS (syslinux) и UEFI (systemd-boot). Root автоматически входит на
tty1 и на последовательной консоли `ttyS0` (добавьте `console=ttyS0,115200` в
параметры ядра для headless-сервера).

```bash
triglav ask "не грузится, висит на Loading Linux"
```

Если AI ещё не настроен:

```bash
triglav-ai-setup
triglav ask "root в read-only после обновления"
```

Без AI:

```bash
triglav-doctor
triglav-mount --auto
triglav-repair menu
```

## Структура

```
build.sh                  сборка ISO (Docker / локально)
config.env.example        конфигурация сборки
profile/packages.add      пакеты поверх releng
profile/overlay/          всё, что попадает в airootfs
  usr/local/bin/          triglav-* команды
  usr/local/lib/triglav/  общая библиотека
  etc/                    motd, issue, shell, конфиги
  opt/triglav/AGENTS.md   инструкции для AI-агента
docker/entrypoint.sh      mkarchiso внутри контейнера
.github/workflows/        сборка ISO в CI
docs/                     сборка, использование, AI
```

## Безопасность

- Live-образ работает от root и имеет доступ ко всем дискам.
- `triglav-ask --auto` разрешает агенту выполнять команды без подтверждений —
  используйте только осознанно.
- Перед изменениями на btrfs делайте `triglav-repair snapshot`.
- Для важных данных сначала клонируйте диск: `triglav-repair rescue-disks SRC DST`.

## Лицензия

MIT (см. `LICENSE`). Arch Linux, TriglavCode и сторонние пакеты — под своими
лицензиями.
