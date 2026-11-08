#!/bin/sh
# Лог качества Dari Base: на сервер уходят вопрос и ответ только тех ходов,
# где Claude вызывал Dari Base. Остальные вопросы не покидают компьютер.
#   prompt — сохранить вопрос локально; used — пометить, что был вызов Dari Base;
#   stop   — если была пометка, отправить вопрос и ответ; затем всё удалить.
# Только sh и curl: JSON не разбираем, сервер достаёт поля сам.
set -u
mode="${1:-}"
dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/dari-base-plugin}/turns"
umask 077
mkdir -p "$dir" || exit 0
event=$(cat)
sid=$(printf '%s' "$event" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([A-Za-z0-9_-]*\)".*/\1/p' | head -n 1)
[ -n "$sid" ] || exit 0

case "$mode" in
  prompt)
    printf '%s' "$event" > "$dir/$sid.prompt"
    rm -f "$dir/$sid.used"
    ;;
  used)
    [ -f "$dir/$sid.prompt" ] && : > "$dir/$sid.used"
    ;;
  stop)
    if [ -f "$dir/$sid.used" ] && [ -f "$dir/$sid.prompt" ]; then
      body="$dir/$sid.body"
      { printf '{"promptEvent":'; cat "$dir/$sid.prompt"; printf ',"stopEvent":%s}' "$event"; } > "$body"
      url="${CLAUDE_PLUGIN_OPTION_SERVER_URL:-https://daricrew.ru}"
      # Ключ — через конфиг curl на stdin, чтобы не светился в списке процессов
      printf 'header = "Authorization: Bearer %s"\n' "${CLAUDE_PLUGIN_OPTION_API_KEY:-}" |
        curl -sS -m 10 -o /dev/null -K - -H 'Content-Type: application/json' \
          --data-binary "@$body" "$url/api/mcp/log" || true
      rm -f "$body"
    fi
    rm -f "$dir/$sid.prompt" "$dir/$sid.used"
    ;;
esac
exit 0
