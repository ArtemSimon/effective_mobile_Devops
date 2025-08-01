#!/bin/bash

# Проверка лог файла  
validate_log_file() {
    local log_file="$1"

    if [ -e "$log_file" ]; then
    # Проверка на то что лог файл является ссылкой
        if [ -L "$log_file" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Error: path is symlink" >&2
            return 1
        # Проверка на то что лог файл является директорией
        elif [ -d "$log_file" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Error: path leads to directory" >&2
            return 1 
        fi 
    # проверяем если нет файла такого то создать, если есть, у нас дата изменения файла меняется
    else
        [ -f "$log_file" ] || { touch "$log_file" && chmod 644 "$log_file"; }

    fi
    return 0

}

# Функция выводит подробную информацию при перезапуске процесса 
get_process_info() {
    local pid=$1

     # Проверка что процесс существует (в этом нет прям необходимости тк при перезапуске новый pid выдается, но может быть, что внезапно может случится ошибка)
    if ! ps -p "$pid" >/dev/null 2>&1; then
        echo "Process $pid does not exist" >> "$LOG_FILE"
        return 1
    fi

    cat <<EOF >> "$LOG_FILE"
=== Process Details ===
Name:    $PROCESS_NAME
PID:     $pid
Status:  $(ps -o stat= -p $pid)
Uptime:  $(ps -o etime= -p $pid)
CPU:     $(ps -o %cpu= -p $pid)%
Memory:  $(ps -o %mem= -p $pid)% (RSS: $(ps -o rss= -p $pid | awk '{printf "%.1f MB", $1/1024}'))
Threads: $(ps -o nlwp= -p $pid)
EOF
}

# Основная функция на проверку состояния и перезапуска процесса 
check_process() {
    
    local current_pid=$(pgrep -o "$PROCESS_NAME") # узнаем pid процесса -o ищет самый старый pid, тоесть родительский

    # Выполняем проверку на то, что если текущий pid пустой то пишем в лог, что процесс не запущен
    if [ -z "$current_pid" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S')- Process $PROCESS_NAME not running"
        return 1 
    fi

    # Проверяем существует ли файл, а затем сравниваем pid если он изменился значит процесс был перезапущен и пишем в лог
    if [ -f "$PID_FILE" ]; then
        local prev_pid=$(cat "$PID_FILE")
        if  [ -n "$prev_pid" ] && [ "$prev_pid" != "$current_pid" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Process $PROCESS_NAME was restarted (PID: $prev_pid -> $current_pid)" >> "$LOG_FILE"
            get_process_info "$current_pid" >> "$LOG_FILE" # добавляем информацию о процессе 
        fi
    fi

    # Проверяем состояние процесса через ps
    local process_state=$(ps -o stat= -p "$current_pid")
    if [[ "$process_state" =~ "Z" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Process $PROCESS_NAME in a zombie state (PID: $current_pid)" >> "$LOG_FILE"
    
    elif [[ "$process_state" =~ "T" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Process $PROCESS_NAME suspended (PID: $current_pid)" >> "$LOG_FILE"
    fi

    # Переопределяем переменную в файл 
    echo "$current_pid" > "$PID_FILE"
    return 0
}

# Функция делает запрос после того как будет известно работает процесс, если нет то не сработает 
check_monitoring_service() {
    
    HTTP_RESPONSE=$(curl -sSfL --max-time 5 -o /dev/null -w "%{http_code}" "$URL" 2>&1)
    CURL_EXIT_CODE=$?

    # Ловим ошибку с curl (нет сети, сервис не доступен и тд)
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error checking monitoring service (URL: $URL, Code: $CURL_EXIT_CODE, Error: $HTTP_RESPONSE)" >> "$LOG_FILE"
    # Ловим коды ошибок 4**/5**
    elif [[ ! "$HTTP_RESPONSE" =~ ^[23][0-9]{2}$ ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - The monitoring service returned an error (URL: $URL, HTTP-code: $HTTP_RESPONSE)" >> "$LOG_FILE"
    fi
}

# --- Главная функция ---
main() {
    # Обрабатываем отсутствие обязательных параметров 
    declare -a REQUIRED_VARIABLES=("PROCESS_NAME" "URL" "LOG_FILE")
    for var in "${REQUIRED_VARIABLES[@]}"; do
        if [ -z "${!var}" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Error: param $var not found" >&2
            exit 1
        fi
    done

    PID_FILE="/var/run/${PROCESS_NAME}_monitor.pid"

    [ -f "$PID_FILE" ] || { touch "$PID_FILE" && chmod 644 "$PID_FILE"; } # проверяем если нет файла такого то создать, если есть, у нас дата изменения файла меняется

    # Проверяем что лог файл валиден, иначе завершаем код 
    if ! validate_log_file "$LOG_FILE"; then
        exit 1 
    fi 

    # Основной цикл 
    while true; do
        if check_process; then
            check_monitoring_service
        fi
        sleep 60
    done
}
trap "echo '$(date) - Service stopped' >> '$LOG_FILE'; exit 0" SIGTERM SIGINT
main 