#!/bin/bash

# Экспортируем переменные окружения, убирая Windows-переносы строк (\r)
export $(sed 's/\r$//' /app/.env | grep -v '^#' | xargs)
PUB_KEY_PATH="/tmp/id_net_scanner.pub"

if [ ! -f "$PUB_KEY_PATH" ]; then
    echo "❌ Ошибка: Публичный ключ не найден по пути $PUB_KEY_PATH"
    exit 1
fi

# Функция обработки одного IP-адреса
process_ip() {
    local IP=$1
    local PASSWORDS=$2
    local USER=$3
    local KEY_PATH=$4
    
    # Игнорируем пустые строки и комментарии
    [[ -z "$IP" || "$IP" =~ ^# ]] && return

    echo "[~] [$IP] Начало настройки..."
    
    for PASS in $PASSWORDS; do
        # Использование ssh-copy-id с защитой stdin (< /dev/null)
        sshpass -p "$PASS" ssh-copy-id -f -i "$KEY_PATH" \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
          -o ConnectTimeout=4 \
          "$USER@$IP" >/dev/null 2>"/tmp/ssh_err_${IP}.log"
        
        if [ $? -eq 0 ]; then
            echo "✅ [$IP] Ключ успешно скопирован!"
            rm -f "/tmp/ssh_err_${IP}.log"
            return 0
        fi
    done

    echo "❌ [$IP] Не удалось скопировать ключ. Последняя ошибка:"
    if [ -f "/tmp/ssh_err_${IP}.log" ]; then
        sed "s/^/  [$IP] /" "/tmp/ssh_err_${IP}.log"
        rm -f "/tmp/ssh_err_${IP}.log"
    fi
}

# Экспортируем функцию для работы внутри xargs / подпроцессов
export -f process_ip

# Интерактивный выбор метода запуска
echo "----------------------------------------"
echo " Выберите метод параллельного запуска:"
echo " 1) Фоновые процессы Bash (знак &)"
echo " 2) Утилита xargs (Способ Б)"
echo "----------------------------------------"
read -p "Введите номер (1 или 2): " METHOD

START_TIME=$(date +%s)

if [ "$METHOD" == "1" ]; then
    echo -e "\n🚀 Запуск через фоновые процессы Bash...\n"
    while read -r IP || [ -n "$IP" ]; do
        # Запускаем в фоне & и принудительно отвязываем stdin
        process_ip "$IP" "$SSH_PASSWORDS" "$SSH_USER" "$PUB_KEY_PATH" < /dev/null &
    done < /app/ips.txt
    wait # Ждем завершения всех фоновых процессов

elif [ "$METHOD" == "2" ]; then
    echo -e "\n🚀 Запуск через xargs (10 потоков)...\n"
    # Очищаем список от комментариев и пустых строк, затем передаем в xargs
    grep -v '^#' /app/ips.txt | grep -v '^$' | xargs -I {} -P 10 bash -c 'process_ip "{}" "$SSH_PASSWORDS" "$SSH_USER" "$PUB_KEY_PATH"'
    
else
    echo "❌ Неверный выбор. Выход."
    exit 1
fi

END_TIME=$(date +%s)
echo "----------------------------------------"
echo "🎉 Работа завершена за $((END_TIME - START_TIME)) сек."
