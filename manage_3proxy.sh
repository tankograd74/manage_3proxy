#!/bin/bash

# Функция для проверки наличия установленного Squid
check_proxy_installed() {
    if dpkg -l | grep -q squid; then
        echo "Proxy уже установлен на этом сервере."
        return 0
    else
        return 1
    fi
}

# Функция для установки Squid
install_proxy() {
    echo "[INFO] Установка Squid..."
    apt update && apt install squid -y
    echo "[INFO] Squid успешно установлен."
}

# Функция для настройки Squid
configure_proxy() {
    echo "Настройка Squid..."
    read -p "Введите порт для Squid [по умолчанию 3128]: " port
    port=${port:-3128}
    read -p "Разрешить доступ с определенных IP (y/n)? " allow_ip_choice
    if [[ $allow_ip_choice == "y" ]]; then
        read -p "Введите список разрешенных IP через пробел: " allowed_ips
    else
        allowed_ips="all"
    fi
    read -p "Включить логирование (y/n)? " enable_logs

    # Генерация конфигурации
    cat <<EOL > /etc/squid/squid.conf
http_port $port
acl allowed_ips src $allowed_ips
http_access allow allowed_ips
http_access deny all
cache_mem 256 MB
cache_dir ufs /var/spool/squid 100 16 256
EOL

    # Управление логированием
    if [[ $enable_logs == "n" ]]; then
        echo "access_log none" >> /etc/squid/squid.conf
    fi

    echo "[INFO] Конфигурация Squid обновлена."
    systemctl restart squid
}

# Меню управления сервером
manage_proxy() {
    while true; do
        echo "Меню управления прокси:"
        echo "0. Показать список пользователей."
        echo "1. Добавить пользователя с выбором типа прокси и авторизации."
        echo "2. Добавить разрешенные IP для подключения к прокси."
        echo "3. Удалить разрешенные IP для подключения к прокси."
        echo "4. Показать список разрешенных IP для подключения к прокси."
        echo "5. Показать список запрещенных IP для подключения к прокси."
        echo "6. Изменить тип подключения к прокси (IP из белого списка/все IP)."
        echo "7. Изменить порт подключения к прокси (socks5/https)."
        echo "8. Включить/отключить логирование."
        echo "9. Удалить прокси сервер."
        echo "10. Выйти из меню."
        read -p "Выберите опцию: " choice

        case $choice in
        0)
            echo "Список пользователей:"
            cat /etc/squid/passwords 2>/dev/null || echo "Нет пользователей."
            ;;
        1)
            read -p "Введите имя пользователя: " username
            read -sp "Введите пароль: " password
            echo "$username:$password" >> /etc/squid/passwords
            echo "Пользователь $username добавлен."
            ;;
        2)
            read -p "Введите IP для добавления в белый список: " ip
            echo "acl allowed_ips src $ip" >> /etc/squid/squid.conf
            systemctl restart squid
            echo "IP $ip добавлен в белый список."
            ;;
        3)
            read -p "Введите IP для удаления из белого списка: " ip
            sed -i "/$ip/d" /etc/squid/squid.conf
            systemctl restart squid
            echo "IP $ip удален из белого списка."
            ;;
        4)
            echo "Список разрешенных IP:"
            grep "acl allowed_ips src" /etc/squid/squid.conf || echo "Нет разрешенных IP."
            ;;
        5)
            echo "Список запрещенных IP:"
            grep "http_access deny" /etc/squid/squid.conf || echo "Нет запрещенных IP."
            ;;
        6)
            read -p "Разрешить доступ всем IP (y/n)? " access_choice
            if [[ $access_choice == "y" ]]; then
                sed -i "/acl allowed_ips src/d" /etc/squid/squid.conf
                echo "acl allowed_ips src all" >> /etc/squid/squid.conf
                echo "Доступ разрешен всем IP."
            else
                echo "Оставьте текущую настройку IP."
            fi
            systemctl restart squid
            ;;
        7)
            read -p "Введите новый порт для подключения (socks5/https): " new_port
            sed -i "s/http_port .*/http_port $new_port/" /etc/squid/squid.conf
            systemctl restart squid
            echo "Порт изменен на $new_port."
            ;;
        8)
            read -p "Отключить логирование (y/n)? " log_choice
            if [[ $log_choice == "y" ]]; then
                sed -i "/access_log/d" /etc/squid/squid.conf
                echo "access_log none" >> /etc/squid/squid.conf
                echo "Логирование отключено."
            else
                echo "Логирование включено."
            fi
            systemctl restart squid
            ;;
        9)
            apt remove --purge squid -y
            rm -rf /etc/squid
            echo "Прокси сервер удален."
            break
            ;;
        10)
            echo "Выход из меню."
            break
            ;;
        *)
            echo "Неверный выбор. Попробуйте снова."
            ;;
        esac
    done
}

# Основной процесс
main() {
    echo "Добро пожаловать в скрипт установки и управления прокси."
    read -p "Сколько серверов будет в цепочке (максимум 10)? " chain_count
    read -p "Какой по счету сервер сейчас настраивается? " server_position

    if [[ $server_position -gt $chain_count || $server_position -lt 1 ]]; then
        echo "Неверный номер сервера. Завершение."
        exit 1
    fi

    check_proxy_installed
    if [[ $? -eq 0 ]]; then
        echo "Прокси уже установлен. Переход в меню управления."
        manage_proxy
    else
        install_proxy
        configure_proxy
        echo "Установка и настройка завершены. Теперь вы можете использовать прокси."
    fi
}

main
