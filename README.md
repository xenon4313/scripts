# server-scripts

Скрипты для автоустановки всякого говна на сервер. Без лишних вопросов — запустил и работает.

## Скрипты

### `issue-cert.sh`

Выпуск SSL-сертификата через `acme.sh` (Let's Encrypt), режим `--standalone`.

Что делает:
- ставит `acme.sh`, `curl`, `socat`, если их нет
- проверяет порт 80, предлагает остановить nginx если занят
- спрашивает домен и имя ключа
- кладёт сертификат в `/etc/certs/`
- настраивает автопродление (через acme.sh)

**Использование:**

```bash
chmod +x issue-cert.sh
sudo ./issue-cert.sh
```

Требования: root, свободный порт 80 (или согласие остановить nginx).

Результат:
```
/etc/certs/<имя>.key
/etc/certs/fullchain.cer
```

## Требования

- Debian/Ubuntu, CentOS/RHEL, Fedora или Alpine
- root-доступ

## Лицензия

MIT
