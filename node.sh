#!/bin/bash
set -euo pipefail

# === Проверка зависимостей ===
for bin in curl bash; do
  command -v "$bin" >/dev/null 2>&1 || { echo "$bin не найден. Установи вручную и перезапусти скрипт."; exit 1; }
done

# === Установка Volta ===
VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"

if [ -x "$VOLTA_HOME/bin/volta" ]; then
  echo "Volta уже установлена: $VOLTA_HOME"
else
  echo "Ставлю Volta..."
  curl https://get.volta.sh | bash
fi

# === Прописываем PATH в shell-профили ===
add_volta_path() {
  local rc_file="$1"
  local marker="# Volta"

  [ -f "$rc_file" ] || touch "$rc_file"

  if ! grep -q "$marker" "$rc_file" 2>/dev/null; then
    {
      echo ""
      echo "$marker"
      echo 'export VOLTA_HOME="$HOME/.volta"'
      echo 'export PATH="$VOLTA_HOME/bin:$PATH"'
    } >> "$rc_file"
    echo "Добавлено в $rc_file"
  else
    echo "$rc_file уже настроен."
  fi
}

add_volta_path "$HOME/.bashrc"
add_volta_path "$HOME/.profile"

# Подхватываем PATH в текущей сессии
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# === Проверка, что volta доступна ===
if ! command -v volta >/dev/null 2>&1; then
  echo ""
  echo "Volta установлена, но не подхватилась в текущем shell."
  echo "Открой новый tty/сессию или выполни: source ~/.bashrc"
  exit 0
fi

echo "Volta: $(volta --version)"

# === Установка Node + npm через Volta ===
read -p "Версия Node (например 20, 22, latest) [latest]: " NODE_VERSION
NODE_VERSION="${NODE_VERSION:-latest}"

echo "Ставлю Node $NODE_VERSION через Volta..."
volta install "node@${NODE_VERSION}"

echo "Ставлю npm (latest)..."
volta install npm@latest

echo ""
echo "Готово!"
echo "Node: $(volta run node -- --version 2>/dev/null || echo 'открой новый tty')"
echo "npm:  $(volta run npm -- --version 2>/dev/null || echo 'открой новый tty')"
echo ""
echo "Если версии не показались — открой новую tty-сессию (новый ssh/терминал)"
echo "или выполни: source ~/.bashrc"
