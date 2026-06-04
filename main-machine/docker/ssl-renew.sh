#!/bin/bash
set -e

cd /home/admin/docker

# Запускаем certbot только на renew и удаляем контейнер после завершения
/usr/bin/docker compose -f docker-compose.yaml run --rm certbot renew --no-random-sleep-on-renew

# Перезагружаем nginx, чтобы он подхватил новые сертификаты
/usr/bin/docker compose -f docker-compose.yaml exec nginx nginx -s reload
