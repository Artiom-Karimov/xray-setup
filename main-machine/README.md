# Финальная настройка основной машины
[Вернуться на главную](../README.md)

### Мы получили сертификат, теперь переписываем конфиг nginx на боевой:

```shell
nano nginx/nginx.conf
```

Заменяем содержимое файла:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
    server_name доменное.имя.машины;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
  listen 443 ssl;
  listen [::]:443 ssl;
  http2 on;

  # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
  server_name доменное.имя.машины;

  # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
  ssl_certificate /etc/letsencrypt/live/доменное.имя.машины/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/доменное.имя.машины/privkey.pem;

  # Здесь будет жить наш websocket с vless
  location /vlessws {
    if ($http_upgrade != "websocket") {
      return 404;
    }

    proxy_pass http://xray:10000;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_buffering off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
  }

  # Это станица-заглушка. при желании можно разместить сайт-визитку
  location / {
    proxy_pass http://website:80;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}

```

### Нам нужен ещё один конфиг - для xray:
```shell
mkdir xray
nano xray/config.json
```
В файл прописываем:
```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "be6142bf-0cb1-4e4a-b62c-c9817b990237"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vlessws"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}

```
**ВАЖНО**: Содержимое поля `"id"` нам нужно для подключения. Сгенерировать можно [здесь](https://www.uuidgenerator.net/).

<br/>

### Теперь заменяем содержимое docker-compose:
```shell
nano docker-compose.yaml
```
Прописываем:
```yaml
services:
  # Это сайт-заглушка, который будет открываться на обычный запрос
  website:
    container_name: website
    image: nginx:latest
    restart: unless-stopped
    networks:
      - mynet

  # Это основной прокси, за которым спрятано всё остальное
  nginx:
    container_name: nginx
    image: nginx:latest
    restart: unless-stopped
    depends_on:
      - xray
      - website
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./nginx/:/etc/nginx/conf.d/:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    networks:
      - mynet

  # Это VLESS-сервер, который перенаправляет наш трафик
  xray:
    container_name: xray
    image: teddysun/xray:latest
    restart: unless-stopped
    volumes:
      - ./xray/config.json:/etc/xray/config.json:ro
    networks:
      - mynet

  # Это бот, который будет обновлять сертификаты
  certbot:
    container_name: certbot
    image: certbot/certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt:rw
      - ./certbot/www:/var/www/certbot:rw
    command: certonly --webroot -w /var/www/certbot --email ${EMAIL} -d ${DOMAIN_NAME} --agree-tos --no-eff-email

networks:
  mynet:
    driver: bridge

```

### Конфиги готовы. Стартуем
```shell
sudo docker compose up
```
Читаем логи. Ошибок быть не должно. Для того, чтобы всё продолжило работать, нажимаем `d` (detach).

Готово. С основной машиной всё.

## Далее

[Вернуться на главную](../README.md)

## Полезные команды

### Linux
- Перейти в папку: `cd <путь/к/папке>`
- Узнать, где ты находишься: `pwd`
- Показать содержимое текущей папки: `ls` или `ls -la`, если нужны скрытые файлы
- Создать пустой файл: `touch имя_файла`
- Редактировать файл: `nano имя_файла`
- Удалить файл: `rm имя_файла`
- Скопировать файл: `cp имя_файла новый/путь/новое_имя_файла`
- Создать папку: `mkdir имя_папки`
- Скопировать папку: `cp -r имя_папки новый/путь`
- Удалить папку: `rm -r имя_папки`

### Docker
- Стартовать compose: `sudo docker compose up`. Важно: надо находиться в одной папке с `docker-compose.yaml`
- Стартовать и отключиться от консоли: `docker compose up -d`
- Остановить compose: `sudo docker compose down`
- Посмотреть статус запущенных контейнеров: `sudo docker ps`
- Перезапустить контейнер: `sudo docker restart имя_контейнера`
- Остановить контейнер: `sudo docker stop имя_контейнера`
- Посмотреть нагрузку (потребляемые ресурсы): `docker stats`
- Выгрузить логи контейнера в файл: `sudo docker logs имя_контейнера > имя_контейнера.log`

Чтобы не набирать каждый раз `sudo`, можно добавить пользователя в группу:
```shell
sudo usermod -aG docker admin
```
При следующих подключениях для docker не нужно будет добавлять sudo.
