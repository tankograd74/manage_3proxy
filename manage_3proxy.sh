#!/bin/bash

set -e  # Прерывать выполнение при ошибках

CONFIG_FILE="/etc/3proxy/3proxy.cfg"
SERVICE_FILE="/etc/systemd/system/3proxy.service"
LOG_FILE="/var/log/3proxy.log"
BIN_DIR="/usr/local/bin/3proxy"
DEFAULT_PROXY_PORT=1080

# Проверка root-прав
if [ "$(id -u)" -ne 0 ]; then
    echo "Скрипт должен быть запущен с правами суперпользователя (root)." >&2
    exit 1
fi

function install_dependencies() {
    echo "Установка необходимых пакетов..."
    apt update
    apt install -y build-essential git gcc make openssl ufw
}

function clone_and_build_3proxy() {
    echo "Скачивание и компиляция 3proxy..."
    if [ -d "3proxy" ]; then
        echo "Каталог '3proxy' уже существует. Удаляю старый каталог..."
        rm -rf 3proxy
    fi

    git clone https://github.com/3proxy/3proxy.git
    cd 3proxy
    make -f Makefile.Linux
    cd ..
}

function install_3proxy_binaries() {
    echo "Установка 3proxy..."
    mkdir -p $BIN_DIR
    cp -r 3proxy/bin/* $BIN_DIR/
}

function create_config_file() {
    echo "Создание конфигурационного файла..."
    PORT=${1:-$DEFAULT_PROXY_PORT}
    ENABLE_LOG=${2:-"y"}

    # Настройка логирования
    LOG_CONFIG=""
    if [ "$ENABLE_LOG" == "y" ]; then
        LOG_CONFIG="log $LOG_FILE D
logformat \"L%d-%m-%Y %H:%M:%S %p %E %u %C:%c %R:%r %O %I %h %T\""
    fi

    cat <<EOF > $CONFIG_FILE
$LOG_CONFIG

nserver 1.1.1.1
nserver 8.8.8.8
timeouts 1 5 30
auth none
socks -p$PORT -n
EOF
}

function create_systemd_service() {
    echo "Создание службы systemd..."
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=$BIN_DIR/3proxy $CONFIG_FILE
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable 3proxy
    systemctl start 3proxy
}

function configure_firewall() {
    echo "Настройка брандмауэра..."
    ufw allow 22/tcp
    ufw allow ${1:-$DEFAULT_PROXY_PORT}/tcp
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    echo "Firewall настроен: открыт порт 22 и порт ${1:-$DEFAULT_PROXY_PORT}."
}

function setup_3proxy() {
    echo "Начало настройки 3proxy..."

    # Скачивание и компиляция
    clone_and_build_3proxy

    # Установка бинарников
    install_3proxy_binaries

    # Создание файла конфигурации
    create_config_file "$DEFAULT_PROXY_PORT" "y"

    # Настройка службы systemd
    create_systemd_service

    # Настройка брандмауэра
    configure_firewall "$DEFAULT_PROXY_PORT"

    echo "3proxy успешно установлен и настроен."
}

# Проверка: если уже установлен, то ничего не делаем
if [ -f "$CONFIG_FILE" ]; then
    echo "3proxy уже установлен. Конфигурация находится в $CONFIG_FILE."
    echo "Вы можете изменить настройки вручную или удалить 3proxy перед повторной установкой."
    exit 0
fi

# Выполнение установки
install_dependencies
setup_3proxy
