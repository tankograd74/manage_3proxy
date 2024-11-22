<?php

function runCommand($command) {
    echo "Running command: $command\n";
    $output = [];
    $return_var = 0;
    exec($command, $output, $return_var);
    if ($return_var !== 0) {
        echo "Command failed: $command\n";
        echo implode("\n", $output) . "\n";
        exit($return_var);
    }
    echo implode("\n", $output) . "\n";
}

function install3Proxy() {
    // Update package list and install dependencies
    runCommand('sudo apt-get update');
    runCommand('sudo apt-get install -y build-essential wget');

    // Download and extract 3proxy
    runCommand('wget https://github.com/3proxy/3proxy/archive/refs/tags/0.9.3.tar.gz');
    runCommand('tar xzf 0.9.3.tar.gz');

    // Build 3proxy
    chdir('3proxy-0.9.3');
    runCommand('make -f Makefile.Linux');

    // Create necessary directories and copy files
    runCommand('sudo mkdir -p /usr/local/3proxy/bin');
    runCommand('sudo mkdir -p /usr/local/3proxy/logs');
    runCommand('sudo mkdir -p /usr/local/3proxy/conf');
    runCommand('sudo cp src/3proxy /usr/local/3proxy/bin/');

    // Create a sample configuration file
    $config = <<<EOL
daemon
maxconn 1024
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
auth none
allow *
proxy -p8080
flush
EOL;
    file_put_contents('/tmp/3proxy.cfg', $config);
    runCommand('sudo mv /tmp/3proxy.cfg /usr/local/3proxy/conf/3proxy.cfg');

    // Create systemd service file
    $serviceFile = <<<EOL
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/3proxy/bin/3proxy /usr/local/3proxy/conf/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=always
Type=simple

[Install]
WantedBy=multi-user.target
EOL;
    file_put_contents('/tmp/3proxy.service', $serviceFile);
    runCommand('sudo mv /tmp/3proxy.service /etc/systemd/system/3proxy.service');

    // Reload systemd, enable and start 3proxy service
    runCommand('sudo systemctl daemon-reload');
    runCommand('sudo systemctl enable 3proxy');
    runCommand('sudo systemctl start 3proxy');

    echo "3proxy has been installed and started successfully.\n";
}

install3Proxy();

?>
