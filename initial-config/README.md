# Первоначальная настройка + получение сертификата
[Вернуться на главную](../README.md)

## Готовим настройки машины

- Подключаемся по ssh с паролем, который получили от провайдера VPS:

```shell
ssh root@<ip_адрес>
```

### Создаём пользователя, чтобы не использовать root:

```shell
apt update
apt install sudo -y
adduser admin
usermod -aG sudo admin
su - admin
```

С этого момента новые подключения через admin, а не через root:

```shell
ssh admin@<ip_адрес>
```

### Устанавливаем docker 
по [официальной инструкции](https://docs.docker.com/engine/install/debian/)


## Получаем TLS-сертификаты

### Создаём папку, из которой будем запускать сервер:

```shell
cd /home/admin
mkdir docker
cd docker
```

### Добавляем первоначальный конфиг для nginx:

```shell
mkdir nginx
nano nginx/nginx.conf
```

В файл `nginx.conf` прописываем:

```nginx
server {
    listen 80;
    listen [::]:80;
    # НЕ ЗАБУДЬ ЗАМЕНИТЬ ИМЯ (адрес)
    server_name твоё.доменное.имя;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
}
```

> Для тех, кто не работал в `nano`:
> 
> `Ctrl+O -> enter` - сохранить изменения
> 
> `Ctrl+X` - закрыть файл

### Добавляем первоначальный docker compose для того, чтобы получить сертификат TLS:

```shell
nano docker-compose.yaml
```

В файл прописываем:

```yaml
services:
  nginx:
    container_name: nginx
    image: nginx:latest
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./nginx/:/etc/nginx/conf.d/:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    networks:
      - mynet

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

Рядом кладём файл с переменными:

```shell
nano .env
```

Прописываем:

```shell
DOMAIN_NAME=твоё.доменное.имя
EMAIL=почта_при_регистрации_домена@example.com
```

### Конфиг для сертификата готов. Запускаем:

```shell
sudo docker compose up
```

Читаем вывод в терминал от certbot. Должна появиться инфа о том, что сертификат получен и сохранён:
```shell
certbot  | Successfully received certificate.
```
Останавливаем контейнеры (Ctrl+C).

Если выдал ошибку вида
```shell
certbot  | Certbot failed to authenticate some domains (authenticator: webroot). The Certificate Authority reported these problems:
...
certbot  | Hint: The Certificate Authority failed to download the temporary challenge files created by Certbot. Ensure that the listed identifiers serve their content from the provided --webroot-path/-w and that files created there can be downloaded from the internet.
```
Нужно просто запустить ещё раз (`sudo docker compose up`).

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


## Далее

[Итоговая настройка основной машины](../main-machine/README.md)

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
