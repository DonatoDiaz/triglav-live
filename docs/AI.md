# AI-ремонт одним промптом

## Настройка

```bash
triglav-ai-setup
```

Скрипт спрашивает:

- **Base URL** — любой OpenAI-совместимый endpoint (`.../v1`),
  например aitunnel, OpenRouter, OpenAI, локальный Ollama (`http://localhost:11434/v1`), vLLM.
- **Model ID** — идентификатор модели у провайдера.
- **API key** — ключ (для локального Ollama можно любой).

Записывается:

- `/root/.config/triglav/ai.env` (chmod 600) — ключ и модель.
- `/root/.config/opencode/opencode.jsonc` — провайдер `triglav` + модель по умолчанию.

Проверка:

```bash
triglavcode run -m triglav/<model> "ответь ok"
```

## Запуск

```bash
triglav ask "не грузится, висит на Loading Linux..."
```

Что происходит:

1. `triglav-doctor` собирает полный отчёт.
2. Формируется `/root/triglav-work/request.md`.
3. Запускается `triglavcode run` в каталоге `/root/triglav-work` с `AGENTS.md`,
   где описаны доступные команды и правила безопасности.
4. Агент читает `doctor.txt`/`lsblk.txt`, предлагает план, выполняет
   read-only шаги и просит подтверждение перед опасными.

Полезные флаги:

```bash
triglav ask --short "..."        # быстрый контекст
triglav ask --save-only "..."    # только собрать промпт
triglav ask --model triglav/gpt-4o-mini "..."
triglav ask --auto "..."         # без подтверждений (опасно)
```

## Без сети / без ключа

AI требует сеть. Если сети нет:

```bash
triglav-doctor
triglav-collect
# перенести архив на рабочую машину и отдать AI там
```

Можно также использовать локальный Ollama в сети: подключитесь к Wi-Fi и укажите
`http://<host>:11434/v1` в `triglav-ai-setup`.

## Безопасность

- `--auto` позволяет агенту выполнять команды без подтверждений.
- Опасные операции (`fsck` с ремонтом, `mkfs`, `dd`, переустановка загрузчика,
  удаление файлов) требуют явного согласия.
- Делайте `triglav-repair snapshot` на btrfs перед изменениями.
- Для важных данных сначала `triglav-repair rescue-disks`.
