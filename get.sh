#!/bin/bash
set -euo pipefail

# === Проверка root ===
if [ "$EUID" -ne 0 ]; then
  echo "Запусти скрипт от root (sudo)."
  exit 1
fi

# === Установка зависимостей (curl, socat) ===
install_pkg() {
  local pkg="$1"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y "$pkg"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "$pkg"
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$pkg"
  else
    echo "Не удалось определить пакетный менеджер. Установи '$pkg' вручную."
    exit 1
  fi
}

for bin in curl socat cron; do
  case "$bin" in
    cron) command -v cron >/dev/null 2>&1 || command -v crond >/dev/null 2>&1 || { echo "cron не найден, устанавливаю..."; install_pkg cron || true; } ;;
    *) command -v "$bin" >/dev/null 2>&1 || { echo "$bin не найден, устанавливаю..."; install_pkg "$bin"; } ;;
  esac
done

# === Установка acme.sh, если его нет ===
ACME_HOME="${HOME:-/root}/.acme.sh"
if [ ! -f "$ACME_HOME/acme.sh" ]; then
  echo "acme.sh не найден. Устанавливаю..."
  read -r -p "Email для регистрации в Let's Encrypt (можно пустым): " ACME_EMAIL </dev/tty
  if [ -n "$ACME_EMAIL" ]; then
    curl https://get.acme.sh | sh -s email="$ACME_EMAIL"
  else
    curl https://get.acme.sh | sh
  fi
  echo "acme.sh установлен."
else
  echo "acme.sh уже установлен: $ACME_HOME/acme.sh"
fi

# Подключаем алиас acme.sh в текущей сессии, если он не в PATH
if ! command -v acme.sh >/dev/null 2>&1; then
  export PATH="$ACME_HOME:$PATH"
  alias acme.sh="$ACME_HOME/acme.sh"
fi
ACME_BIN="$ACME_HOME/acme.sh"

# По умолчанию используем Let's Encrypt как CA (можно сменить на zerossl)
"$ACME_BIN" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true

# === Проверка папки ===
if [ -d "/etc/certs" ]; then
  echo "Папка /etc/certs уже существует."
else
  echo "Создаю папку /etc/certs..."
  mkdir -p /etc/certs
fi

# === Проверка, не занят ли порт 80 ===
if ss -tuln | grep -q ':80 '; then
  echo "Порт 80 занят. Смотрим, кто:"
  ss -tulnp | grep ':80 '
  echo ""
  read -r -p "Остановить nginx? (y/n): " STOP_NGINX </dev/tty
  if [[ "$STOP_NGINX" =~ ^[Yy]$ ]]; then
    systemctl stop nginx 2>/dev/null || service nginx stop
    echo "nginx остановлен."
  else
    echo "Без свободного 80 порта --standalone не сработает. Выход."
    exit 1
  fi
else
  echo "Порт 80 свободен."
fi

# === Ввод данных ===
DOMAIN=""
while [ -z "$DOMAIN" ]; do
  read -r -p "Введи домен (например example.com): " DOMAIN </dev/tty
done

KEYNAME=""
while [ -z "$KEYNAME" ]; do
  read -r -p "Имя для ключа (без .key, например example): " KEYNAME </dev/tty
done

KEY_FILE="/etc/certs/${KEYNAME}.key"
FULLCHAIN_FILE="/etc/certs/fullchain.cer"

# === Проверка, есть ли уже серты ===
if [ -f "$KEY_FILE" ] || [ -f "$FULLCHAIN_FILE" ]; then
  echo ""
  echo "Внимание! Уже существуют файлы:"
  [ -f "$KEY_FILE" ] && echo "  - $KEY_FILE"
  [ -f "$FULLCHAIN_FILE" ] && echo "  - $FULLCHAIN_FILE"
  read -r -p "Перезаписать? (y/n): " OVERWRITE </dev/tty
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "Отмена."
    exit 0
  fi
fi

# === Выпуск сертификата ===
echo ""
echo "Выпускаю сертификат для $DOMAIN..."
"$ACME_BIN" --issue -d "$DOMAIN" --standalone --server letsencrypt \
  --key-file "$KEY_FILE" \
  --fullchain-file "$FULLCHAIN_FILE"

if [ $? -eq 0 ]; then
  echo ""
  echo "Готово!"
  echo "Ключ:      $KEY_FILE"
  echo "Fullchain: $FULLCHAIN_FILE"
  echo ""
  echo "Автопродление настроено acme.sh автоматически (через cron/systemd timer)."
else
  echo ""
  echo "Ошибка при выпуске. Смотри вывод выше."
  exit 1
fi
