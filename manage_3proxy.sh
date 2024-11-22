#!/bin/bash

set -e  # Остановить выполнение при ошибке

CONFIG_FILE="/etc/3proxy/3proxy.cfg"
SERVICE_FILE="/etc/systemd/system/3proxy.service"
LOG_FILE="/var/log/3proxy.log"

function check_installed() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "3proxy уже установлен на этом сервере."
        return 0
    else
        return 1
    fi
}

function install_3proxy() {
    echo "Установка необходимых пакетов..."
    sudo apt update
    sudo apt install -y git build-essential openssl ufw

    echo "Скачивание и компиляция 3proxy..."
    git clone https://github.com/3proxy/3proxy.git
    cd 3proxy
    make -f Makefile.Linux
    sudo make install

    echo "Создание папки для конфигурации..."
    sudo mkdir -p /etc/3proxy
    cd /etc/3proxy
}

function setup_proxy() {
    echo "Настройка конфигурации 3proxy..."

    # Вопросы для установки
    read -p "Сколько серверов будет в цепочке? (1-10): " SERVER_COUNT
    read -p "Какой по счету сервер вы сейчас настраиваете? (1-$SERVER_COUNT): " CURRENT_SERVER
    if [[ "$CURRENT_SERVER" -eq "$SERVER_COUNT" ]]; then
        read -p "Введите имя хоста для TLS (например, proxy.example.com): " TLS_HOST
        sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/3proxy/3proxy.key -out /etc/3proxy/3proxy.crt -days 365 -nodes
    else
        read -p "Введите IP следующего сервера в цепочке: " NEXT_SERVER_IP
    fi

    read -p "Введите порт для текущего сервера (по умолчанию: 1080): " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-1080}

    # Логирование
    read -p "Включить логирование? (y/n): " ENABLE_LOG
    if [[ "$ENABLE_LOG" == "y" ]]; then
        LOG_CONFIG="log $LOG_FILE D
logformat \"L%d-%m-%Y %H:%M:%S %p %E %u %C:%c %R:%r %O %I %h %T\""
    else
        LOG_CONFIG=""
    fi

    # Генерация конфигурации
    if [[ "$CURRENT_SERVER" -eq "$SERVER_COUNT" ]]; then
        cat <<EOF | sudo tee "$CONFIG_FILE"
$LOG_CONFIG

nserver 1.1.1.1
nserver 8.8.8.8
timeouts 1 5 30
auth none
socks -p$PROXY_PORT -n

tls hostname=$TLS_HOST cert /etc/3proxy/3proxy.crt key /etc/3proxy/3proxy.key
EOF
    else
        cat <<EOF | sudo tee "$CONFIG_FILE"
$LOG_CONFIG

nserver 1.1.1.1
nserver 8.8.8.8
timeouts 1 5 30
auth none
socks -p$PROXY_PORT -n

proxy -p3128 -n -a -e$NEXT_SERVER_IP
EOF
    fi

    echo "Создание службы systemd..."
    cat <<EOF | sudo tee "$SERVICE_FILE"
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy $CONFIG_FILE
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable 3proxy
    sudo systemctl start 3proxy

    echo "Установка завершена. Прокси запущен на порту $PROXY_PORT."
}

function configure_firewall() {
    echo "Закрытие всех портов, кроме используемого прокси и порта 22 (SSH)..."
    # Убедимся, что ufw установлен и активен
    sudo apt update
    sudo apt install -y ufw
    sudo ufw allow 22/tcp
    sudo ufw allow $PROXY_PORT/tcp
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable
    echo "Firewall настроен: открыт порт 22 и порт $PROXY_PORT."
}

function manage_proxy() {
    while true; do
        echo "Меню управления 3proxy:"
        echo "0. Показать список пользователей"
        echo "1. Добавить пользователя с выбором типа прокси и авторизации"
        echo "2. Удалить пользователя"
        echo "3. Добавить разрешенные IP для подключения к прокси"
        echo "4. Удалить разрешенные IP для подключения к прокси"
        echo "5. Показать список разрешенных IP для подключения к прокси"
        echo "6. Показать список запрещенных IP для подключения к прокси"
        echo "7. Изменить тип подключения к прокси (IP из белого списка/все IP)"
        echo "8. Изменить порт подключения к прокси (socks5/https)"
        echo "9. Включить/отключить логирование"
        echo "10. Закрыть все порты, кроме используемого прокси и 22"
        echo "11. Удалить прокси сервер"
        echo "12. Выход"
        read -p "Выберите действие: " ACTION

        case $ACTION in
        0)
            echo "Список пользователей:"
            grep "^users" "$CONFIG_FILE" || echo "Пользователи не настроены."
            ;;
        1)
            read -p "Введите имя пользователя: " USERNAME
            read -p "Введите пароль: " PASSWORD
            echo "users $USERNAME:CL:$PASSWORD" | sudo tee -a "$CONFIG_FILE"
            sudo systemctl restart 3proxy
            echo "Пользователь $USERNAME добавлен."
            ;;
        2)
            read -p "Введите имя пользователя для удаления: " USERNAME
            sudo sed -i "/users $USERNAME:/d" "$CONFIG_FILE"
            sudo systemctl restart 3proxy
            echo "Пользователь $USERNAME удалён."
            ;;
        3)
            read -p "Введите IP для разрешения: " ALLOWED_IP
            echo "allow * * $ALLOWED_IP" | sudo tee -a "$CONFIG_FILE"
            sudo systemctl restart 3proxy
            echo "IP $ALLOWED_IP добавлен в белый список."
            ;;
        4)
            read -p "Введите IP для удаления из разрешенных: " REMOVED_IP
            sudo sed -i "/allow \* \* $REMOVED_IP/d" "$CONFIG_FILE"
            sudo systemctl restart 3proxy
            echo "IP $REMOVED_IP удален из белого списка."
            ;;
        5)
            echo "Список разрешенных IP:"
            grep "^allow" "$CONFIG_FILE" || echo "Разрешенные IP отсутствуют."
            ;;
        6)
            echo "Список запрещенных IP:"
            grep "^deny" "$CONFIG_FILE" || echo "Запрещенные IP отсутствуют."
            ;;
        7)
            read -p "Разрешить подключение для всех IP? (y/n): " ALLOW_ALL
            if [[ "$ALLOW_ALL" == "y" ]]; then
                sudo sed -i "/allow/d" "$CONFIG_FILE"
                echo "allow *" | sudo tee -a "$CONFIG_FILE"
                echo "Подключение разрешено для всех IP."
            else
                echo "Текущие настройки белого списка IP сохранены."
            fi
            sudo systemctl restart 3proxy
            ;;
        8)
            read -p "Введите новый порт подключения (по умолчанию 1080): " NEW_PORT
            NEW_PORT=${NEW_PORT:-1080}
            sudo sed -i "s/-p[0-9]\+/ -p$NEW_PORT/" "$CONFIG_FILE"
            sudo systemctl restart 3proxy
            echo "Порт изменен на $NEW_PORT."
            ;;
        9)
            read -p "Включить логирование? (y/n): " ENABLE_LOG
            if [[ "$ENABLE_LOG" == "y" ]]; then
                echo "log $LOG_FILE D" | sudo tee -a "$CONFIG_FILE"
                echo "logformat \"L%d-%m-%Y %H:%M:%S %p %E %u %C:%c %R:%r %O %I %h %T\"" | sudo tee -a "$CONFIG_FILE"
                echo "Логирование включено."
            else
                sudo sed -i "/log /d" "$CONFIG_FILE"
                sudo sed -i "/logformat/d" "$CONFIG_FILE"
                echo "Логирование отключено."
            fi
            sudo systemctl restart 3proxy
            ;;
        10)
            configure_firewall
            ;;
        11)
            echo "Удаление 3proxy..."
            sudo systemctl stop 3proxy
            sudo systemctl disable 3proxy
            sudo rm -f "$CONFIG_FILE" "$SERVICE_FILE" "$LOG_FILE"
            echo "3proxy удален."
            ;;
        12)
            echo "Выход."
            break
            ;;
        *)
            echo "Некорректный ввод. Повторите попытку."
            ;;
        esac
    done
}

if check_installed; then
    manage_proxy
else
    install_3proxy
    setup_proxy
fi
