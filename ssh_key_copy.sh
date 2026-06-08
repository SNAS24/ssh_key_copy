
docker run --rm -it \
  --network host \
  -v "$HOME/.ssh/id_net_scanner.pub:/tmp/id_net_scanner.pub:ro" \
  -v "$(pwd)/.env:/app/.env:ro" \
  -v "$(pwd):/app" \
  --entrypoint /bin/bash \
  net-scanner -c '
    export $(sed "s/\r$//" .env | grep -v "^#" | xargs)
    PUB_KEY_PATH="/tmp/id_net_scanner.pub"

    if [ ! -f "$PUB_KEY_PATH" ]; then
        echo "Ошибка: Публичный ключ не найден в контейнере по пути $PUB_KEY_PATH"
        exit 1
    fi

    PUB_KEY=$(cat "$PUB_KEY_PATH")

    # while read -r IP || [ -n "$IP" ]; do
    while read -u 3 -r IP || [ -n "$IP" ]; do
        [[ -z "$IP" || "$IP" =~ ^# ]] && continue
        # Запускаем обработку этого IP в фоне
        (
            echo "----------------------------------------"
            echo "Настройка доступа для: $IP"
            
            SUCCESS=0
            for PASS in $SSH_PASSWORDS; do
                sshpass -p "$PASS" ssh-copy-id -f -i "$PUB_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=4 "$SSH_USER"@"$IP" 2>ssh_err.log
                if [ $? -eq 0 ]; then
                    echo " [УСПЕХ]: Ключ успешно скопирован на $IP"
                    SUCCESS=1
                    break
                fi
            done

            if [ $SUCCESS -eq 0 ]; then
                echo " [ОШИБКА]: Не удалось скопировать ключ на $IP. Лог последней ошибки:"
                cat ssh_err.log
            fi
        ) & 
    # done < ips.txt
    done 3< ips.txt
    rm -f ssh_err.log
  '
