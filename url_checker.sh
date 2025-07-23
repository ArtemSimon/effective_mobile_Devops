#!/bin/bash

echo "$(date '+%Y-%m-%d %H:%M:%S') - Start script"

# Функция срабатывает при получении SIGTERM
cleanup_and_exit() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') SIGTERM received. Performing cleanup..."
  touch "$STATUS_FILE"
  exit 0 
}

# Обрабатываем отсутствие обязательных параметров 
declare -a REQUIRED_VARIABLES=("URL" "LOG_FILE")
for var in "${REQUIRED_VARIABLES[@]}"; do
    if [ -z "${!var}" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Error: param $var not found" >&2
        exit 1
    fi
done

# Инициализация файлов
[ -f "$LOG_FILE" ] || { touch "$LOG_FILE" && chmod 644 "$LOG_FILE"; } # проверяем если нет файла такого то создать, если есть, у нас дата изменения файла меняется
[ -f "$STATUS_FILE" ] && {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Url_checker restarted" >> "$LOG_FILE"
    rm "$STATUS_FILE"
}

# Установка обработчика SIGTERM
trap cleanup_and_exit SIGTERM

# Делаем запрос на проверку сервиса мониторинга каждую минуту
while true; do
    HTTP_RESPONSE=$(curl -sSfL --max-time 5 -o /dev/null -w "%{http_code}" "$URL" 2>&1)
    CURL_EXIT_CODE=$?

    # Ловим ошибку с curl (нет сети, сервис не доступен и тд)
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') -Error checking monitoring service (URL: $URL, Code: $CURL_EXIT_CODE, Error: $HTTP_RESPONSE)" >> "$LOG_FILE"
    # Ловим коды ошибок 4**/5**
    elif [[ ! "$HTTP_RESPONSE" =~ ^[23][0-9]{2}$ ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - The monitoring service returned an error (URL: $URL, HTTP-code: $HTTP_RESPONSE)" >> "$LOG_FILE"
    fi
    sleep 60
done 
   
