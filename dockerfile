FROM alpine:3.18

# Устанавливаем необходимые системные утилиты
RUN apk add --no-cache \
    bash \
    openssh-client \
    sshpass \
    nmap \
    iproute2

# Создаем рабочую директорию
WORKDIR /app

# Копируем скрипт внутрь контейнера
COPY scanner.sh .
RUN chmod +x scanner.sh

# Запуск скрипта по умолчанию
CMD ["./scanner.sh"]
