# CI: сборка ISO в GitHub Actions

Готовый workflow лежит в `ci/build-iso.yml`. GitHub не разрешает загружать
файлы в `.github/workflows/` токену без scope `workflow`, поэтому включите его
одним из способов.

## Вариант 1: через gh (нужен scope workflow)

```bash
gh auth refresh -h github.com -s workflow
make install-workflow
git add .github/workflows/build-iso.yml
git commit -m "ci: enable ISO build"
git push
```

## Вариант 2: через веб-интерфейс

1. Откройте https://github.com/DonatoDiaz/triglav-live
2. Add file → Create new file
3. Имя: `.github/workflows/build-iso.yml`
4. Вставьте содержимое `ci/build-iso.yml` и закоммитьте.

## Что делает workflow

- `lint`: `make test-config` (bash -n для всех скриптов).
- `build`: запускает `./build.sh` (Docker + archiso) на ubuntu-latest,
  загружает ISO как artifact (14 дней).
- На тег `v*` создаёт GitHub Release с ISO и `.sha256`.

Первый запуск занимает ~10–20 минут (скачивание пакетов Arch и TriglavCode).

## Ручной релиз с локальным ISO

```bash
gh release create v0.1.0 \
  out/triglav-live-0.1.0-x86_64.iso \
  out/triglav-live-0.1.0-x86_64.iso.sha256 \
  --title "Triglav Live 0.1.0" \
  --notes "Первый rescue-образ: BIOS+UEFI, TriglavCode, triglav-* скрипты."
```

Лимит размера одного asset на GitHub — 2 ГБ; ISO ~1.3 ГБ.
