#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} you must to run this script from root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
    echo -e "${red}The script does not support alpine systems at this time!${plain}\n" && exit 1
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Failed to detect the architecture and use the default architecture:${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit system (x86), please use 64-bit system (x86_64), if the detection error, please contact the author!"
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}Note: CentOS 7 cannot use the hysteria1/2 protocol!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
        yum install ca-certificates wget -y
        update-ca-trust force-enable
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
        apt-get install ca-certificates wget -y
        update-ca-certificates
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/V2bX.service ]]; then
        return 2
    fi
    temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_V2bX() {
    if [[ -e /usr/local/V2bX/ ]]; then
        rm -rf /usr/local/V2bX/
    fi

    mkdir /usr/local/V2bX/ -p
    cd /usr/local/V2bX/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/QuLOVE/V2bX-English/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Detecting the V2bX version failed, it may be beyond the Github API limit, please try again later, or manually specify the V2bX version to install.${plain}"
            exit 1
        fi
        echo -e "The latest version of V2bX is detected: ${last_version}，starting installation."
        wget -q -N --no-check-certificate -O /usr/local/V2bX/V2bX-linux.zip https://github.com/QuLOVE/V2bX-English/releases/download/${last_version}/V2bX-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading V2bX failed, make sure that your server can download GitHub files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/QuLOVE/V2bX-English/releases/download/${last_version}/V2bX-linux-${arch}.zip"
        echo -e "Starting Installation V2bX $1"
        wget -q -N --no-check-certificate -O /usr/local/V2bX/V2bX-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading V2bX $1 failed, make sure that this version exists${plain}"
            exit 1
        fi
    fi

    unzip V2bX-linux.zip
    rm V2bX-linux.zip -f
    chmod +x V2bX
    mkdir /etc/V2bX/ -p
    rm /etc/systemd/system/V2bX.service -f
    file="https://github.com/QuLOVE/V2bX-script/raw/master/V2bX.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/V2bX.service ${file}
    #cp -f V2bX.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop V2bX
    systemctl enable V2bX
    echo -e "${green}V2bX ${last_version}${plain} installation is complete, boot-up has been set"
    cp geoip.dat /etc/V2bX/
    cp geosite.dat /etc/V2bX/

    if [[ ! -f /etc/V2bX/config.json ]]; then
        cp config.json /etc/V2bX/
        echo -e ""
        echo -e "New installation, please refer to the tutorial first：https://github.com/QuLOVE/V2bX-English/tree/master/example，then configure the necessary"
        first_install=true
    else
        systemctl start V2bX
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}V2bX reboot successful${plain}"
        else
            echo -e "${red}V2bX may fail to start, please use V2bX log to check the log information later, if it fails to start, the configuration format may have been changed, please go to the Wiki page to check: https://github.com/V2bX-project/V2bX/wiki${plain}"
        fi
        first_install=false
    fi

    if [[ ! -f /etc/V2bX/dns.json ]]; then
        cp dns.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/route.json ]]; then
        cp route.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/V2bX/
    fi
    curl -o /usr/bin/V2bX -Ls https://raw.githubusercontent.com/QuLOVE/V2bX-script/master/V2bX.sh
    chmod +x /usr/bin/V2bX
    if [ ! -L /usr/bin/v2bx ]; then
        ln -s /usr/bin/V2bX /usr/bin/v2bx
        chmod +x /usr/bin/v2bx
    fi
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "V2bX management script usage (compatible with V2bX command execution, case insensitive)"
    echo "------------------------------------------"
    echo "V2bX              - Display Admin Menu"
    echo "V2bX start        - Start"
    echo "V2bX stop         - Stop"
    echo "V2bX restart      - Restart"
    echo "V2bX status       - Check status"
    echo "V2bX enable       - Enable boot"
    echo "V2bX disable      - Disable boot"
    echo "V2bX log          - View log"
    echo "V2bX x25519       - Generate x25519 key"
    echo "V2bX generate     - Generate of configure file"
    echo "V2bX update       - Update"
    echo "V2bX update x.x.x - Update to specified version"
    echo "V2bX install      - Install"
    echo "V2bX uninstall    - Uninstall"
    echo "V2bX version      - View version"
    echo "------------------------------------------"
    # The first installation asks whether to generate configuration file
    if [[ $first_install == true ]]; then
        read -rp "Detecting that you are installing V2bX for the first time. Does it automatically generate the configuration file directly?(y/n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            curl -o ./initconfig.sh -Ls https://raw.githubusercontent.com/QuLOVE/V2bX-script/master/initconfig.sh
            source initconfig.sh
            rm initconfig.sh -f
            generate_config_file
            read -rp "Is the bbr kernel installed? (y/n): " if_install_bbr
            if [[ $if_install_bbr == [Yy] ]]; then
                install_bbr
            fi
        fi
    fi
}

echo -e "${green}Starting Installation${plain}"
install_base
install_V2bX $1
