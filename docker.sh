#!/bin/bash
set -euo pipefail

# === Проверка root ===
if [ "$EUID" -ne 0 ]; then
  echo "Запусти скрипт от root (sudo)."
  exit 1
fi

# === Проверка, что это Ubuntu ===
if [ ! -f /etc/os-release ]; then
  echo "Не найден /etc/os-release. Скрипт только для Ubuntu."
  exit 1
fi
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ]; then
  echo "Обнаружена система: ${ID:-unknown}. Скрипт рассчитан только на Ubuntu."
  exit 1
fi

# === Пользователь, которого добавим в группу docker ===
TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  read -r -p "Логин пользователя для группы docker (пусто = пропустить): " TARGET_USER </dev/tty || true
fi

# === Если Docker уже стоит ===
if command -v docker >/dev/null 2>&1; then
  echo "Docker уже установлен: $(docker --version)"
  echo "Проверяю Compose plugin..."
else
  echo "Ставлю Docker Engine..."

  # Удаляем возможные старые/конфликтующие пакеты
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" >/dev/null 2>&1 || true
  done

  apt-get update -qq
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi

  ARCH="$(dpkg --print-architecture)"
  CODENAME="${VERSION_CODENAME:-$(. /etc/os-release && echo "$VERSION_CODENAME")}"

  echo \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "Docker установлен: $(docker --version)"
fi

# === Compose plugin ===
if docker compose version >/dev/null 2>&1; then
  echo "Compose plugin: $(docker compose version)"
else
  echo "Compose plugin не найден, ставлю..."
  apt-get install -y docker-compose-plugin
  echo "Compose plugin: $(docker compose version)"
fi

# === systemd: включаем и стартуем ===
systemctl enable docker.service >/dev/null 2>&1 || true
systemctl enable containerd.service >/dev/null 2>&1 || true
systemctl start docker.service

# === Добавление пользователя в группу docker ===
if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
  if id -nG "$TARGET_USER" | grep -qw docker; then
    echo "Пользователь $TARGET_USER уже в группе docker."
  else
    usermod -aG docker "$TARGET_USER"
    echo "Пользователь $TARGET_USER добавлен в группу docker."
    echo "Чтобы применилось без перелогина: newgrp docker (в его сессии) или перелогинься/новый ssh."
  fi
else
  echo "Пользователь для группы docker не указан или не найден — пропускаю."
fi

# === Проверка ===
echo ""
echo "Проверка установки:"
docker --version
docker compose version
if docker run --rm hello-world >/dev/null 2>&1; then
  echo "docker run hello-world: OK"
else
  echo "docker run hello-world не прошёл — проверь вывод: docker run hello-world"
fi

echo ""
echo "Готово!"
