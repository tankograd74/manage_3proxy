#!/bin/bash

# Прекращение выполнения при ошибке
set -e

# Цветной вывод
INFO="\033[1;32m[INFO]\033[0m"
ERROR="\033[1;31m[ERROR]\033[0m"
RESET="\033[0m"

echo -e "${INFO} Установка необходимых пакетов..."
apt update && apt install -y build-essential git openssl ufw curl

# Функция для настройки UFW
configure_ufw() {
    echo -e "${INFO} Настройка UFW..."
    ufw allow ssh
    ufw allow 3128/tcp
    ufw --force enable
    echo -e "${INFO} UFW настроен!"
}

# Скачивание и компиляция 3proxy
setup_3proxy() {
    echo -e "${INFO} Скачивание и компиляция 3proxy..."

    if [ -d "3proxy" ]; then
        echo -e "${INFO} Удаление старой версии 3proxy..."
        rm -rf 3proxy
    fi

    git clone https://github.com/z3APA3A/3proxy.git

    cd 3proxy
    make -C src CFLAGS="-Wno-format -Wno-unused-result"
    echo -e "${INFO} Компиляция 3proxy завершена."

    # Установка бинарных файлов
    mkdir -p /usr/local/bin /etc/3proxy /var/log/3proxy
    cp bin/3proxy /usr/local/bin/
    cp bin/mycrypt /usr/local/bin/
    cp bin/proxy /usr/local/bin/
    chmod +x /usr/local/bin/3proxy /usr/local/bin/mycrypt /usr/local/bin/proxy

    # Установка конфигурации
    cp examples/3proxy.cfg /etc/3proxy/3proxy.cfg
    chmod 644 /etc/3proxy/3proxy.cfg

    echo -e "${INFO} 3proxy успешно установлен."
    cd ..
}

# Настройка systemd службы
configure_systemd() {
    echo -e "${INFO} Создание службы systemd для 3proxy..."

    cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy proxy server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/3proxy.service
    systemctl daemon-reload
    systemctl enable 3proxy
    echo -e "${INFO} Служба 3proxy создана и активирована."
}

# Настройка пользователей
configure_users() {
    echo -e "${INFO} Настройка пользователей для 3proxy..."
    cat <<EOF > /etc/3proxy/usersfile
user1:CL:password1
user2:CL:password2
EOF
    chmod 600 /etc/3proxy/usersfile
    echo -e "${INFO} Пользователи добавлены."
}

# Добавление ротации логов
setup_log_rotation() {
    echo -e "${INFO} Настройка ротации логов..."
    cat <<EOF > /etc/logrotate.d/3proxy
/var/log/3proxy/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        systemctl restart 3proxy > /dev/null 2>&1 || true
    endscript
}
EOF
    echo -e "${INFO} Ротация логов настроена."
}

# Запуск службы
start_3proxy() {
    echo -e "${INFO} Запуск службы 3proxy..."
    systemctl start 3proxy
    systemctl status 3proxy --no-pager
    echo -e "${INFO} 3proxy запущен."
}

# Проверка доступности 3proxy
test_proxy() {
    echo -e "${INFO} Проверка доступности 3proxy..."
    curl -x http://127.0.0.1:3128 -U user1:password1 http://example.com
    if [ $? -eq 0 ]; then
        echo -e "${INFO} 3proxy успешно проверен. Прокси работает."
    else
        echo -e "${ERROR} Ошибка проверки 3proxy. Проверьте настройки."
    fi
}

# Основной процесс
main() {
    configure_ufw
    setup_3proxy
    configure_systemd
    configure_users
    setup_log_rotation
    start_3proxy
    test_proxy
    echo -e "${INFO} Установка и настройка 3proxy завершена успешно!"
}

# Запуск основного процесса
main
