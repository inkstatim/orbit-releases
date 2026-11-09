#!/bin/bash
# Установка и обновление Orbit одной командой (вставить в «Терминал» и нажать Enter):
#   curl -fsSL https://raw.githubusercontent.com/inkstatim/orbit-releases/main/install.sh | bash
# Скачивает последнюю версию, кладёт Orbit в «Программы» и запускает.
set -euo pipefail

URL="https://github.com/inkstatim/orbit-releases/releases/latest/download/Orbit.dmg"
DEST="${ORBIT_INSTALL_DIR:-/Applications}"
TMP="$(mktemp -d)"
MNT="$TMP/mnt"

cleanup() {
  hdiutil detach -quiet "$MNT" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() { echo "✗ $1" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "Orbit работает только на macOS."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "Нужна macOS 14 или новее, у вас $(sw_vers -productVersion)."

# Без прав администратора в /Applications не записать — ставим в свою папку «Программы».
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

echo "⬇ Скачиваю Orbit…"
curl -fL --progress-bar -o "$TMP/Orbit.dmg" "$URL" || fail "Не удалось скачать. Проверьте интернет и попробуйте ещё раз."

hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MNT" "$TMP/Orbit.dmg" || fail "Файл скачался с ошибкой. Попробуйте ещё раз."
codesign --verify --deep --strict "$MNT/Orbit.app" 2>/dev/null || fail "Подпись Orbit не прошла проверку — установка отменена."

# Обновление: закрыть запущенный Orbit, чтобы заменить его.
if pgrep -xq Orbit; then
  echo "Закрываю запущенный Orbit…"
  osascript -e 'tell application id "dev.inkstatim.orbit" to quit' >/dev/null 2>&1 || true
  for _ in {1..20}; do pgrep -xq Orbit || break; sleep 0.25; done
  pkill -x Orbit 2>/dev/null || true
fi

echo "📦 Устанавливаю в ${DEST}…"
rm -rf "$DEST/Orbit.app"
ditto "$MNT/Orbit.app" "$DEST/Orbit.app"
xattr -dr com.apple.quarantine "$DEST/Orbit.app" 2>/dev/null || true

open "$DEST/Orbit.app"
echo "✓ Готово! Orbit запущен. Чтобы видеть весь диск, дайте ему «Полный доступ к диску» — Orbit подскажет как."
