# Финальная настройка прокси-машины
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
    server_name доменное.имя.прокси;

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
  server_name доменное.имя.прокси;

  # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
  ssl_certificate /etc/letsencrypt/live/доменное.имя.прокси/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/доменное.имя.прокси/privkey.pem;

  # VLESS WebSocket endpoint
    location /vlessws {
        if ($http_upgrade != "websocket") {
            return 404;
        }

        # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
        proxy_pass доменное.имя.основной.машины;
        
        # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
        proxy_set_header Host доменное.имя.основной.машины;
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_ssl_server_name on;
    }

    location / {
        # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
        proxy_pass https://доменное.имя.основной.машины;
        
        # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
        proxy_set_header Host доменное.имя.основной.машины;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_ssl_server_name on;
    }
}

```
### Docker compose - не трогаем, оставляем тот же.
### Стартуем:
```shell
docker compose up -d
```

### Скрипт для обновления сертификата
Нужно периодически перезапускать `certbot` и `nginx`, чтобы сертификат обновлялся прежде, чем истечёт его срок действия.

Создаём скрипт:
```shell
nano ssl-renew.sh
```

Прописываем:
```shell
#!/bin/bash
set -e

cd /home/admin/docker

# Запускаем certbot только на renew и удаляем контейнер после завершения
/usr/bin/docker compose -f docker-compose.yaml run --rm certbot renew --no-random-sleep-on-renew

# Перезагружаем nginx, чтобы он подхватил новые сертификаты
/usr/bin/docker compose -f docker-compose.yaml exec nginx nginx -s reload
```

Делаем скрипт исполняемым:
```shell
chmod +x ssl-renew.sh
```

Добавляем скрипт в cron, чтобы выполнялся по расписанию:
```shell
sudo crontab -e
```

Прописываем:
```shell
0 3 * * * /bin/bash /home/admin/docker/ssl-renew.sh >> /var/log/certbot-renew.log 2>&1
```

Готово. С прокси-машиной всё.

[Вернуться на главную](../README.md)