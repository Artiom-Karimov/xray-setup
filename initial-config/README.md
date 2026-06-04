# Первоначальная настройка + получение первого сертификата
[Вернуться на главную](../README.md)

## Готовим настройки машины

- Подключаемся по ssh с паролем, который получили от провайдера VPS:

```shell
ssh root@<ip_адрес>
```

- Устанавливаем docker по официальной инструкции: https://docs.docker.com/engine/install/debian/

- Создаём пользователя, чтобы не использовать root:

```shell
apt install sudo -y
adduser admin
usermod -aG sudo admin
usermod -aG docker admin
su - admin
```

Теперь подключаемся не как root, а как admin:

```shell
shh admin@<ip_адрес>
```

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

Читаем вывод в терминал от certbot. Должна появиться инфа о том, что сертификат получен и сохранён.

Останавливаем контейнеры (Ctrl+C).

## Далее

[Итоговая настройка основной машины](../main-machine/README.md)

[Итоговая настройка прокси-машины](../proxy-machine/README.md)

[Вернуться на главную](../README.md)