# URL Monitoring Service

Скрипт на bash для мониторинга процесса test в среде linux.

# Файлы проекта

    Основной скрипт: url_checker.sh

    Systemd service: url_checker.service

    Конфигурационный файл: /etc/default/url_checker

# Установка
1. Скопируйте файлы:

```
sudo cp url_checker.sh /usr/local/bin/
sudo cp url_checker.service /etc/systemd/system/
sudo cp url_checker /etc/default/
```

2. Установите права:

```
sudo chmod +x /usr/local/bin/url_checker.sh
sudo chmod 644 /etc/default/url_checker
```

3. Активируйте сервис:

```
sudo systemctl daemon-reload
sudo systemctl enable url_checker.service
sudo systemctl start url_checker.service
```

# Проверка работы

Статус сервиса:

```    
systemctl status url_checker
```

Просмотр логов:

```
tail -f /var/log/monitoring.log
```

Тест остановки:

```
sudo systemctl stop url_checker
cat /tmp/url_checker_stopped  
```