# server-scripts

Скрипты для автоустановки всякого говна на сервер. Без лишних вопросов — запустил и работает.

## Скрипты
### `get.sh`

Выпуск SSL-сертификата через `acme.sh` (Let's Encrypt), режим `--standalone`.

Что делает:
- ставит `acme.sh`, `curl`, `socat`, если их нет
- проверяет порт 80, предлагает остановить nginx если занят
- спрашивает домен и имя ключа
- кладёт сертификат в `/etc/certs/`
- настраивает автопродление (через acme.sh)

### `node.sh`
Выбор версии, AIO в одном месте что бы сразу пользоваться


### **`То ради чего тут`**
**Сертификаты**


```curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/get.sh | bash``` -> Получить сертификаты

**Volta**


```curl -fsSL https://raw.githubusercontent.com/xenon4313/scripts/main/node | bash``` -> Получить Volta, npm, node

## Лицензия

Я че вам манйкрафт что бы лицензии раздавать

https://i.pinimg.com/1200x/b5/b4/69/b5b469d4080463f29fd61c8fc5e3041f.jpg
