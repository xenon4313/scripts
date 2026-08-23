#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Использование:
  get.sh [флаги]

По умолчанию запускается интерактивный выпуск через Let's Encrypt и
HTTP standalone challenge.

Флаги:
  --preset NAME       standalone (default), staging или webroot
  --domain DOMAIN     домен сертификата; без флага будет вопрос
  --key-name NAME     имя ключа без .key; без флага будет вопрос
  --cert-dir PATH     каталог сертификатов. Пусто, пробел, . и ./ означают текущий каталог
  --webroot PATH      webroot для preset webroot
  --email EMAIL       email для регистрации acme.sh
  --stop-nginx        автоматически остановить nginx, если порт 80 занят
  --force             перезаписать существующие файлы без вопроса
  -h, --help          показать эту справку

Примеры:
  curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | sudo bash -s -- --domain example.com --key-name example
  curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | sudo bash -s -- --preset webroot --webroot /var/www/html --domain example.com --key-name example --cert-dir ./
  curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | sudo bash -s -- --preset staging --domain example.com --key-name example --force
EOF
}

normalize_cert_dir() {
  local path="$1"

  # В shell-скрипте легко передать пустоту и одиночный пробел через флаг.
  # Для удобства они, как . и ./, обозначают текущую директорию.
  if [[ "$path" =~ ^[[:space:]]*$ || "$path" == "." || "$path" == "./" ]]; then
    pwd -P
  else
    printf '%s\n' "$path"
  fi
}

PRESET="standalone"
DOMAIN=""
KEYNAME=""
CERT_DIR="/etc/certs"
WEBROOT=""
ACME_EMAIL=""
STOP_NGINX=0
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --preset) PRESET="${2:?Для --preset нужно значение}"; shift 2 ;;
    --domain) DOMAIN="${2:?Для --domain нужно значение}"; shift 2 ;;
    --key-name) KEYNAME="${2:?Для --key-name нужно значение}"; shift 2 ;;
    --cert-dir) CERT_DIR="${2-}"; shift 2 ;;
    --webroot) WEBROOT="${2:?Для --webroot нужно значение}"; shift 2 ;;
    --email) ACME_EMAIL="${2:?Для --email нужно значение}"; shift 2 ;;
    --stop-nginx) STOP_NGINX=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Неизвестный флаг: $1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$PRESET" in
  standalone)
    ACME_SERVER="letsencrypt"
    CHALLENGE="standalone"
    ;;
  staging)
    ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
    CHALLENGE="standalone"
    ;;
  webroot)
    ACME_SERVER="letsencrypt"
    CHALLENGE="webroot"
    if [ -z "$WEBROOT" ]; then
      echo "Для preset webroot укажи --webroot PATH." >&2
      exit 1
    fi
    ;;
  *)
    echo "Неизвестный preset: $PRESET. Доступны: standalone, staging, webroot." >&2
    exit 1
    ;;
esac

CERT_DIR="$(normalize_cert_dir "$CERT_DIR")"

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

for bin in curl cron; do
  case "$bin" in
    cron) command -v cron >/dev/null 2>&1 || command -v crond >/dev/null 2>&1 || { echo "cron не найден, устанавливаю..."; install_pkg cron || true; } ;;
    *) command -v "$bin" >/dev/null 2>&1 || { echo "$bin не найден, устанавливаю..."; install_pkg "$bin"; } ;;
  esac
done

if [ "$CHALLENGE" = "standalone" ] && ! command -v socat >/dev/null 2>&1; then
  echo "socat не найден, устанавливаю..."
  install_pkg socat
fi

# === Установка acme.sh, если его нет ===
ACME_HOME="${HOME:-/root}/.acme.sh"
if [ ! -f "$ACME_HOME/acme.sh" ]; then
  echo "acme.sh не найден. Устанавливаю..."
  if [ -z "$ACME_EMAIL" ]; then
    read -r -p "Email для регистрации в Let's Encrypt (можно пустым): " ACME_EMAIL </dev/tty
  fi
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

# По умолчанию используем Let's Encrypt как CA; preset staging переключает на тестовый endpoint.
"$ACME_BIN" --set-default-ca --server "$ACME_SERVER" >/dev/null 2>&1 || true

# === Проверка папки ===
if [ -d "$CERT_DIR" ]; then
  echo "Папка $CERT_DIR уже существует."
else
  echo "Создаю папку $CERT_DIR..."
  mkdir -p "$CERT_DIR"
fi

# === Проверка, не занят ли порт 80 ===
if [ "$CHALLENGE" = "standalone" ] && ss -tuln | grep -q ':80 '; then
  echo "Порт 80 занят. Смотрим, кто:"
  ss -tulnp | grep ':80 '
  echo ""
  if [ "$STOP_NGINX" -eq 1 ]; then
    systemctl stop nginx 2>/dev/null || service nginx stop
    echo "nginx остановлен."
  else
    echo "Без свободного 80 порта --standalone не сработает. Выход."
    exit 1
  fi
elif [ "$CHALLENGE" = "standalone" ]; then
  echo "Порт 80 свободен."
else
  echo "Использую webroot: $WEBROOT"
fi

# === Ввод данных ===
while [ -z "$DOMAIN" ]; do
  read -r -p "Введи домен (например example.com): " DOMAIN </dev/tty
done

while [ -z "$KEYNAME" ]; do
  read -r -p "Имя для ключа (без .key, например example): " KEYNAME </dev/tty
done

KEY_FILE="${CERT_DIR}/${KEYNAME}.key"
FULLCHAIN_FILE="${CERT_DIR}/fullchain.cer"

# === Проверка, есть ли уже серты ===
if [ -f "$KEY_FILE" ] || [ -f "$FULLCHAIN_FILE" ]; then
  echo ""
  echo "Внимание! Уже существуют файлы:"
  [ -f "$KEY_FILE" ] && echo "  - $KEY_FILE"
  [ -f "$FULLCHAIN_FILE" ] && echo "  - $FULLCHAIN_FILE"
  if [ "$FORCE" -eq 0 ]; then
    read -r -p "Перезаписать? (y/n): " OVERWRITE </dev/tty
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
      echo "Отмена."
      exit 0
    fi
  fi
fi

# === Выпуск сертификата ===
echo ""
echo "Выпускаю сертификат для $DOMAIN..."
if [ "$CHALLENGE" = "standalone" ]; then
  "$ACME_BIN" --issue -d "$DOMAIN" --standalone --server "$ACME_SERVER" \
    --key-file "$KEY_FILE" \
    --fullchain-file "$FULLCHAIN_FILE"
else
  "$ACME_BIN" --issue -d "$DOMAIN" -w "$WEBROOT" --server "$ACME_SERVER" \
    --key-file "$KEY_FILE" \
    --fullchain-file "$FULLCHAIN_FILE"
fi

if [ $? -eq 0 ]; then
  echo ""
  echo "Готово!"
  echo "Ключ:      $KEY_FILE"
  echo "Fullchain: $FULLCHAIN_FILE"
  echo ""
  # acme.sh использует cron, не systemd timer. Проверяем, что джоба реально есть.
  if crontab -l 2>/dev/null | grep -q 'acme.sh'; then
    echo "Автопродление: cron-джоба acme.sh найдена (crontab -l)."
  else
    echo "ВНИМАНИЕ: cron-джоба acme.sh не найдена в crontab -l."
    echo "Ставлю вручную: $ACME_BIN --install-cronjob"
    "$ACME_BIN" --install-cronjob || echo "Не удалось поставить cron-джобу. Настрой вручную: $ACME_BIN --install-cronjob"
  fi
else
  echo ""
  echo "Ошибка при выпуске. Смотри вывод выше."
  exit 1
fi
