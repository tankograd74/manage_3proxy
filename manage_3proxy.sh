#!/bin/bash

set -e

VERSION="0.9.4"
BASE_URL="https://github.com/z3APA3A/3proxy/archive/"
CONFIG_URL="https://github.com/SnoyIatk/3proxy/raw/master/"
INIT_SCRIPT_URL="https://raw.github.com/SnoyIatk/3proxy/master/3proxy"
INSTALL_DIR="/etc/3proxy"
LOG_DIR="/var/log/3proxy"

INFO="\033[1;32m[INFO]\033[0m"
ERROR="\033[1;31m[ERROR]\033[0m"

# Установка необходимых пакетов
echo -e "${INFO} Установка необходимых пакетов..."
apt update && apt install -y gcc make git wget

# Скачивание и распаковка 3proxy
echo -e "${INFO} Скачивание и распаковка 3proxy версии ${VERSION}..."
wget --no-check-certificate -O "3proxy-${VERSION}.tar.gz" "${BASE_URL}${VERSION}.tar.gz"
tar xzf "3proxy-${VERSION}.tar.gz"

# Компиляция 3proxy
echo -e "${INFO} Компиляция 3proxy..."
cd "3proxy-${VERSION}"
make -f Makefile.Linux

# Создание директорий
echo -e "${INFO} Создание директорий..."
mkdir -p "${INSTALL_DIR}" "${LOG_DIR}"

# Перемещение файлов
echo -e "${INFO} Перемещение файлов 3proxy..."
mv src/3proxy "${INSTALL_DIR}/"

# Скачивание конфигурации
echo -e "${INFO} Скачивание конфигурации..."
wget --no-check-certificate "${CONFIG_URL}3proxy.cfg" -O "${INSTALL_DIR}/3proxy.cfg"
chmod 600 "${INSTALL_DIR}/3proxy.cfg"

wget --no-check-certificate "${CONFIG_URL}.proxyauth" -O "${INSTALL_DIR}/.proxyauth"
chmod 600 "${INSTALL_DIR}/.proxyauth"

# Настройка службы
echo -e "${INFO} Настройка службы 3proxy..."
wget --no-check-certificate "${INIT_SCRIPT_URL}" -O /etc/init.d/3proxy
chmod +x /etc/init.d/3proxy
update-rc.d 3proxy defaults

# Удаление временных файлов
cd ..
rm -rf "3proxy-${VERSION}" "3proxy-${VERSION}.tar.gz"

# Запуск 3proxy
echo -e "${INFO} Запуск 3proxy..."
/etc/init.d/3proxy start

# Проверка статуса
if pgrep -x "3proxy" > /dev/null; then
    echo -e "${INFO} 3proxy успешно установлен и запущен."
else
    echo -e "${ERROR} Ошибка запуска 3proxy. Проверьте конфигурацию."
fi
