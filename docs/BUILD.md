# Сборка Triglav Live

## Требования

- Linux x86_64, Docker (рекомендуется) или установленный `archiso`.
- ~15 ГБ свободного места (профиль + workdir + ISO).
- Сеть для скачивания пакетов Arch и TriglavCode (если не задан локальный архив).

## Docker (по умолчанию)

`build.sh` запускает privileged-контейнер `archlinux:latest`, ставит `archiso`,
копирует releng-профиль, накладывает `profile/overlay`, добавляет пакеты и
вызывает `mkarchiso`.

```bash
cp config.env.example config.env
./build.sh
```

Результат: `out/triglav-live-<version>-x86_64.iso` и `.sha256`.

## Без Docker

```bash
sudo pacman -S --needed archiso
./build.sh --in-container
```

## Офлайн-сборка TriglavCode

Скачайте `triglavcode-*-linux-x64.tar.gz` заранее и укажите:

```bash
TRIGLAVCODE_TARBALL_URL=/path/to/triglavcode-1.19.0-triglav.1-linux-x64.tar.gz
```

или отключите встраивание (`EMBED_TRIGLAVCODE=0`) — тогда бинарник
подтянется при первом запуске через `triglav-code-fetch`.

## Проверка

```bash
make test-config      # bash -n для всех скриптов
make shellcheck       # если установлен shellcheck
```

Проверено в QEMU (BIOS и UEFI): загрузка до motd, `triglav help`,
`triglav doctor --short`, `triglav tools list`, `triglav ask --save-only`,
`triglavcode --version` (нужен `-cpu host`, иначе Bun падает с SIGILL на
урезанном CPU-модели QEMU).

Запуск ISO в QEMU:

```bash
qemu-system-x86_64 -m 4096 -enable-kvm \
  -drive file=out/triglav-live-*.iso,media=cdrom,readonly=on \
  -boot d
```

## CI

Workflow лежит в `ci/build-iso.yml`; включение и ограничения токена описаны в
`docs/CI.md`. Он собирает ISO в контейнере `archlinux:latest` и прикрепляет
артефакт. На тег `v*` создаётся релиз с ISO.
