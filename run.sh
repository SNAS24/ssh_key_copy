#!/bin/bash
# ssh-keygen -t ed25519 -f ~/.ssh/id_net_scanner -N ""

# Проверяем наличие ключа на хосте перед запуском
if [ ! -f "$HOME/.ssh/id_net_scanner.pub" ]; then
    echo "❌ Ошибка на хосте: Файл $HOME/.ssh/id_net_scanner.pub не найден."
    exit 1
fi

# Запуск Docker контейнера
# -it необходим для интерактивного выбора (read -p) внутри контейнера
docker run --rm -it \
  --network host \
  -v "$HOME/.ssh/id_net_scanner.pub:/tmp/id_net_scanner.pub:ro" \
  -v "$(pwd)/.env:/app/.env:ro" \
  -v "$(pwd)/ips.txt:/app/ips.txt:ro" \
  -v "$(pwd)/setup_ssh.sh:/app/setup_ssh.sh:ro" \
  --entrypoint /bin/bash \
  net-scanner /app/setup_ssh.sh
