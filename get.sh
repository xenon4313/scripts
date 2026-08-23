#!/bin/bash

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
  read -p "Остановить nginx? (y/n): " STOP_NGINX
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
read -p "Введи домен (например example.com): " DOMAIN
read -p "Имя для ключа (без .key, например example): " KEYNAME

KEY_FILE="/etc/certs/${KEYNAME}.key"
FULLCHAIN_FILE="/etc/certs/fullchain.cer"

# === Проверка, есть ли уже серты ===
if [ -f "$KEY_FILE" ] || [ -f "$FULLCHAIN_FILE" ]; then
  echo ""
  echo "Внимание! Уже существуют файлы:"
  [ -f "$KEY_FILE" ] && echo "  - $KEY_FILE"
  [ -f "$FULLCHAIN_FILE" ] && echo "  - $FULLCHAIN_FILE"
  read -p "Перезаписать? (y/n): " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "Отмена."
    exit 0
  fi
fi

# === Выпуск сертификата ===
echo ""
echo "Выпускаю сертификат для $DOMAIN..."
acme.sh --issue -d "$DOMAIN" --standalone --server letsencrypt \
  --key-file "$KEY_FILE" \
  --fullchain-file "$FULLCHAIN_FILE"

if [ $? -eq 0 ]; then
  echo ""
  echo "Готово!"
  echo "Ключ:      $KEY_FILE"
  echo "Fullchain: $FULLCHAIN_FILE"
else
  echo ""
  echo "Ошибка при выпуске. Смотри вывод выше."
fi