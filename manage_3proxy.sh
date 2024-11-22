#!/bin/bash

# Проверка root-прав
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Этот скрипт необходимо запускать с root-правами!"
    exit 1
fi

echo "[INFO] Установка и настройка Squid Proxy..."

# Установка Squid
install_squid() {
    echo "[INFO] Установка Squid..."
    apt update && apt install squid -y
    if [ $? -ne 0 ]; then
        echo "[ERROR] Ошибка установки Squid!"
        exit 1
    fi
    echo "[INFO] Squid успешно установлен."
}

# Настройка Squid
configure_squid() {
    local port
    echo -n "Введите порт для Squid [по умолчанию 3128]: "
    read -r port
    port=${port:-3128}

    echo "[INFO] Настройка конфигурации Squid..."
    cat <<EOL > /etc/squid/squid.conf
http_port $port
cache_mem 256 MB
cache_dir ufs /var/spool/squid 100 16 256
access_log none
acl allowed_ips src 127.0.0.1
http_access allow allowed_ips
http_access deny all
EOL
    systemctl restart squid
    echo "[INFO] Конфигурация Squid обновлена."
}

# Показать список пользователей
show_users() {
    echo "[INFO] Список пользователей в Squid:"
    cat /etc/squid/passwords 2>/dev/null || echo "[INFO] Список пользователей пуст."
}

# Добавить пользователя
add_user() {
    echo -n "Введите имя пользователя: "
    read -r username
    echo -n "Введите пароль для пользователя: "
    read -r -s password
    echo
    htpasswd -b /etc/squid/passwords "$username" "$password"
    echo "[INFO] Пользователь $username добавлен."
}

# Добавить разрешенные IP
add_allowed_ips() {
    echo -n "Введите IP-адреса для добавления в разрешенный список (через пробел): "
    read -r ip_list
    for ip in $ip_list; do
        sed -i "/acl allowed_ips src/a\  $ip" /etc/squid/squid.conf
    done
    echo "[INFO] IP-адреса добавлены."
    systemctl restart squid
}

# Удалить разрешенные IP
remove_allowed_ips() {
    echo -n "Введите IP-адреса для удаления из разрешенного списка (через пробел): "
    read -r ip_list
    for ip in $ip_list; do
        sed -i "/$ip/d" /etc/squid/squid.conf
    done
    echo "[INFO] IP-адреса удалены."
    systemctl restart squid
}

# Показать разрешенные IP
show_allowed_ips() {
    echo "[INFO] Разрешенные IP:"
    grep "acl allowed_ips src" /etc/squid/squid.conf | awk '{print $4}'
}

# Показать запрещенные IP
show_blocked_ips() {
    echo "[INFO] Эта функция в разработке."
}

# Изменить тип подключения
change_connection_type() {
    echo -n "Введите новый тип подключения (all/список IP): "
    read -r connection_type
    if [[ "$connection_type" == "all" ]]; then
        sed -i "s/^acl allowed_ips src .*/acl allowed_ips src all/" /etc/squid/squid.conf
    else
        echo -n "Введите IP-адреса для разрешенного подключения: "
        read -r ip_list
        sed -i "s/^acl allowed_ips src .*/acl allowed_ips src $ip_list/" /etc/squid/squid.conf
    fi
    systemctl restart squid
    echo "[INFO] Тип подключения изменён."
}

# Изменить порт подключения
change_port() {
    echo -n "Введите новый порт для подключения: "
    read -r new_port
    sed -i "s/^http_port .*/http_port $new_port/" /etc/squid/squid.conf
    systemctl restart squid
    echo "[INFO] Порт изменён."
}

# Включить/отключить логирование
toggle_logging() {
    echo -n "Включить логирование (y/n)? "
    read -r enable_logging
    if [[ "$enable_logging" == "y" ]]; then
        sed -i '/access_log none/d' /etc/squid/squid.conf
        echo "access_log /var/log/squid/access.log" >> /etc/squid/squid.conf
        touch /var/log/squid/access.log
        chmod 600 /var/log/squid/access.log
        echo "[INFO] Логирование включено."
    else
        sed -i '/access_log/d' /etc/squid/squid.conf
        echo "access_log none" >> /etc/squid/squid.conf
        echo "[INFO] Логирование отключено."
    fi
    systemctl restart squid
}

# Удалить Squid
remove_squid() {
    echo "[WARNING] Вы собираетесь удалить Squid Proxy. Продолжить (y/n)? "
    read -r confirm
    if [[ "$confirm" == "y" ]]; then
        systemctl stop squid
        apt remove --purge squid -y
        rm -rf /etc/squid /var/spool/squid
        echo "[INFO] Squid успешно удалён."
    else
        echo "[INFO] Удаление отменено."
    fi
}

# Переустановить Squid
reinstall_squid() {
    remove_squid
    install_squid
    configure_squid
    echo "[INFO] Squid переустановлен."
}

# Меню управления Squid
show_menu() {
    while true; do
        echo "[INFO] Squid уже установлен на этом сервере. Выберите действие:"
        echo "0. Показать список пользователей"
        echo "1. Добавить пользователя"
        echo "2. Добавить разрешенные IP для подключения к прокси"
        echo "3. Удалить разрешенные IP для подключения к прокси"
        echo "4. Показать список разрешенных IP"
        echo "5. Показать список запрещенных IP"
        echo "6. Изменить тип подключения к прокси"
        echo "7. Изменить порт подключения к прокси"
        echo "8. Включить/отключить логирование"
        echo "9. Удалить прокси сервер"
        echo "10. Переустановить сервер"
        echo "11. Выйти"
        echo -n "Выберите номер действия: "
        read -r action

        case $action in
        0) show_users ;;
        1) add_user ;;
        2) add_allowed_ips ;;
        3) remove_allowed_ips ;;
        4) show_allowed_ips ;;
        5) show_blocked_ips ;;
        6) change_connection_type ;;
        7) change_port ;;
        8) toggle_logging ;;
        9) remove_squid; break ;;
        10) reinstall_squid ;;
        11) echo "[INFO] Завершение работы."; break ;;
        *) echo "[ERROR] Неверный ввод. Повторите попытку." ;;
        esac
    done
}

# Основной блок
if systemctl is-active --quiet squid; then
    show_menu
else
    install_squid
    configure_squid
    toggle_logging
    echo "[INFO] Squid установлен и настроен."
fi
