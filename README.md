# Чего ты ожидаешь тут увидеть?

Скрипты для автоустановки всякого говна на сервер. Без лишних вопросов — запустил и работает.

## Скрипты
### `get.sh`

Выпуск SSL-сертификата через `acme.sh` (Let's Encrypt), режим `--standalone`.

Что делает:
- ставит `acme.sh`, `curl`, `socat`, если их нет
- проверяет порт 80, предлагает остановить nginx если занят
- спрашивает домен и имя ключа
- кладёт сертификат в `/etc/certs/` (или в каталог из `--cert-dir`)
- настраивает автопродление (через acme.sh)

Обычный запуск остался интерактивным. Для автоматизации есть presets и флаги:

```bash
# Выпуск без вопросов (подходит и для curl | bash)
curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | sudo bash -s -- \
  --domain example.com --key-name example --cert-dir ./

# Проверка выпуска через тестовый Let's Encrypt endpoint
curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | sudo bash -s -- \
  --preset staging --domain example.com --key-name example

# Webroot вместо временной остановки сервера на 80 порту
curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | sudo bash -s -- \
  --preset webroot --webroot /var/www/html --domain example.com --key-name example
```

`--cert-dir` принимает обычный путь. Пустое значение, один пробел, `.` и `./` означают текущую директорию. Для занятого 80 порта добавь `--stop-nginx`: nginx остановится только на время выпуска, а те же hooks сохранятся для автопродления. Для уже существующих файлов добавь `--force`.

### `node.sh`
Выбор версии, AIO в одном месте что бы сразу пользоваться


### **`То ради чего тут`**
**Сертификаты**


```curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | bash``` -> Получить сертификаты

**Volta**


```curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/node.sh | bash``` -> Получить Volta, npm, node

**Docker**
```bash <(curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/install-docker.sh)``` -> docker

## Лицензия

Я че вам манйкрафт что бы лицензии раздавать

![description](https://i.pinimg.com/1200x/b5/b4/69/b5b469d4080463f29fd61c8fc5e3041f.jpg)
