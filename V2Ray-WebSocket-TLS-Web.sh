#!/bin/bash

#Installation options
nginx_version="nginx-1.19.6"
openssl_version="openssl-openssl-3.0.0-alpha9"
v2ray_config="/usr/local/etc/v2ray/config.json"
nginx_prefix="/etc/nginx"
nginx_config="${nginx_prefix}/conf.d/v2ray.conf"
nginx_service="/etc/systemd/system/nginx.service"
temp_dir="/temp_install_update_v2ray_ws_tls"
v2ray_is_installed=""
nginx_is_installed=""
is_installed=""
update=""

#Configuration information
unset domain_list
unset domainconfig_list
unset pretend_list
protocol=""
tlsVersion=""
path=""
v2id=""

#System information
release=""
systemVersion=""
redhat_package_manager=""
redhat_version=""
mem_ok=""

#Define a few colors
purple()                           #Gay Purple
{
    echo -e "\033[35;1m${@}\033[0m"
}
tyblue()                           #Sky Blue
{
    echo -e "\033[36;1m${@}\033[0m"
}
green()                            #Teal Green
{
    echo -e "\033[32;1m${@}\033[0m"
}
yellow()                           #Duck feces yellow
{
    echo -e "\033[33;1m${@}\033[0m"
}
red()                              #Aunt Red
{
    echo -e "\033[31;1m${@}\033[0m"
}

if [ "$EUID" != "0" ]; then
    red "Please run this script as root user! !"
    exit 1
fi
if [[ ! -f '/etc/os-release' ]]; then
    red "The system version is too old, the official V2Ray script does not support"
    exit 1
fi
if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
    true
elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
    true
else
    red "Only support systems that use systemd!"
    exit 1
fi
if [[ ! -d /dev/shm ]]; then
    red "/dev/shm does not exist, unsupported system"
    exit 1
fi
if [ "$(cat /proc/meminfo | grep 'MemTotal' | awk '{print $3}' | tr [:upper:] [:lower:])" == "kb" ]; then
    if [ "$(cat /proc/meminfo | grep 'MemTotal' | awk '{print $2}')" -le 400000 ]; then
        mem_ok=0
    else
        mem_ok=1
    fi
else
    mem_ok=2
fi
if [ -e /usr/local/bin/v2ray ]; then
    v2ray_is_installed=1
else
    v2ray_is_installed=0
fi
if [ -e $nginx_config ] || [ -e $nginx_prefix/conf.d/xray.conf ]; then
    nginx_is_installed=1
else
    nginx_is_installed=0
fi
if [ $v2ray_is_installed -eq 1 ] && [ $nginx_is_installed -eq 1 ]; then
    is_installed=1
else
    is_installed=0
fi
if [ -e /usr/bin/v2ray ] && [ -e /etc/nginx ]; then
    yellow "The currently installed version of V2Ray is too old and the script is no longer supported!"
    yellow "Please select 1 option to reinstall"
    sleep 3s
fi

check_important_dependence_installed()
{
    if [ $release == "ubuntu" ] || [ $release == "other-debian" ]; then
        if ! dpkg -s $1 > /dev/null 2>&1; then
            if ! apt -y --no-install-recommends install $1; then
                apt update
                if ! apt -y --no-install-recommends install $1; then
                    yellow "Important component installation failed! !"
                    red "Unsupported system! !"
                    exit 1
                fi
            fi
        fi
    else
        if ! rpm -q $2 > /dev/null 2>&1; then
            if ! $redhat_package_manager -y install $2; then
                yellow "Important component installation failed! !"
                red "Unsupported system! !"
                exit 1
            fi
        fi
    fi
}
version_ge()
{
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}
#Get system information
get_system_info()
{
    if [[ "$(type -P apt)" ]]; then
        if [[ "$(type -P dnf)" ]] || [[ "$(type -P yum)" ]]; then
            red "Apt and yum exist at the same time/dnf"
            red "Unsupported system!"
            exit 1
        fi
        release="other-debian"
        redhat_package_manager="true"
    elif [[ "$(type -P dnf)" ]]; then
        release="other-redhat"
        redhat_package_manager="dnf"
    elif [[ "$(type -P yum)" ]]; then
        release="other-redhat"
        redhat_package_manager="yum"
    else
        red "Unsupported system or apt/yum/dnf is missing"
        exit 1
    fi
    check_important_dependence_installed lsb-release redhat-lsb-core
    if lsb_release -a 2>/dev/null | grep -qi "ubuntu"; then
        release="ubuntu"
    elif lsb_release -a 2>/dev/null | grep -qi "centos"; then
        release="centos"
    elif lsb_release -a 2>/dev/null | grep -qi "fedora"; then
        release="fedora"
    fi
    systemVersion=$(lsb_release -r -s)
    if [ $release == "fedora" ]; then
        if version_ge $systemVersion 28; then
            redhat_version=8
        elif version_ge $systemVersion 19; then
            redhat_version=7
        elif version_ge $systemVersion 12; then
            redhat_version=6
        else
            redhat_version=5
        fi
    else
        redhat_version=$systemVersion
    fi
}

#Check whether Nginx has been installed via apt/dnf/yum
check_nginx()
{
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
    red    "------------It is detected that Nginx has been installed and will conflict with this script------------"
    yellow " If you don’t remember that you have installed Nginx before, you may have installed it when using another one-click script."
    yellow " It is recommended to use a pure system to run this script"
    echo
    local choice=""
    while [ "$choice" != "y" -a "$choice" != "n" ]
    do
        tyblue "Are you trying to uninstall? (y/n)"
        read choice
    done
    if [ $choice == "n" ]; then
        exit 0
    fi
    apt -y purge nginx
    $redhat_package_manager -y remove nginx
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
    red "Uninstallation failed!"
    yellow "Please try to change the system, it is recommended to use the latest version of Ubuntu system"
    green  "Welcome to bug report(https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/issues),thank you for your support"
    exit 1
}

#Check SELinux
check_SELinux()
{
    turn_off_selinux()
    {
        check_important_dependence_installed selinux-utils libselinux-utils
        setenforce 0
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/sysconfig/selinux
        $redhat_package_manager -y remove libselinux-utils
        apt -y purge selinux-utils
    }
    if getenforce 2>/dev/null | grep -wqi Enforcing || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/sysconfig/selinux 2>/dev/null; then
        yellow "SELinux is detected to be turned on, the script may not run normally"
        choice=""
        while [[ "$choice" != "y" && "$choice" != "n" ]]
        do
            tyblue "Try to close SELinux?(y/n)"
            read choice
        done
        if [ $choice == y ]; then
            turn_off_selinux
        else
            exit 0
        fi
    fi
}

#Check if port 80 and port 443 are occupied
check_port()
{
    local i=2
    local temp_port=443
    while ((i!=0))
    do
        ((i--))
        if netstat -tuln | tail -n +3 | awk '{print $4}' | awk -F : '{print $NF}' | grep -wq "$temp_port"; then
            red "$temp_port port is occupied!"
            yellow "please check with lsof -i:$temp_port"
            exit 1
        fi
        temp_port=80
    done
}

#Convert the list of domain names into an array
get_all_domains()
{
    unset all_domains
    for ((i=0;i<${#domain_list[@]};i++))
    do
        if [ ${domainconfig_list[i]} -eq 1 ]; then
            all_domains+=("www.${domain_list[i]}")
            all_domains+=("${domain_list[i]}")
        else
            all_domains+=("${domain_list[i]}")
        fi
    done
}

#Configure sshd
check_ssh_timeout()
{
    if grep -q "#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script" /etc/ssh/sshd_config; then
        return 0
    fi
    echo -e "\n\n\n"
    tyblue "------------------------------------------"
    tyblue " Installation may take a long time (5-40 minutes)"
    tyblue " It will be troublesome if you disconnect halfway"
    tyblue " Setting the ssh connection timeout period will effectively reduce the possibility of disconnection"
    tyblue "------------------------------------------"
    choice=""
    while [ "$choice" != "y" -a "$choice" != "n" ]
    do
        tyblue "Whether to set the ssh connection timeout time?(y/n)"
        read choice
    done
    if [ $choice == y ]; then
        sed -i '/^[ \t]*ClientAliveInterval[ \t]/d' /etc/ssh/sshd_config
        sed -i '/^[ \t]*ClientAliveCountMax[ \t]/d' /etc/ssh/sshd_config
        echo >> /etc/ssh/sshd_config
        echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
        echo "ClientAliveCountMax 60" >> /etc/ssh/sshd_config
        echo "#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script" >> /etc/ssh/sshd_config
        service sshd restart
        green  "----------------------Configuration complete----------------------"
        tyblue " Please reconnect to ssh (re-login to the server) and run this script again"
        yellow " Press Enter to exit. . . ."
        read -s
        exit 0
    fi
}

#Delete firewall and Alibaba Cloud Shield
uninstall_firewall()
{
    green "The firewall is being deleted. . ."
    ufw disable
    apt -y purge firewalld
    apt -y purge ufw
    systemctl stop firewalld
    systemctl disable firewalld
    $redhat_package_manager -y remove firewalld
    green "Alibaba Cloud Shield and Tencent Cloud Shield are being deleted (Only valid for Alibaba Cloud and Tencent Cloud servers)。。。"
#Alibaba Cloud Shield
    if [ $release == "ubuntu" ] || [ $release == "other-debian" ]; then
        systemctl stop CmsGoAgent
        systemctl disable CmsGoAgent
        rm -rf /usr/local/cloudmonitor
        rm -rf /etc/systemd/system/CmsGoAgent.service
        systemctl daemon-reload
    else
        systemctl stop cloudmonitor
        /etc/rc.d/init.d/cloudmonitor remove
        rm -rf /usr/local/cloudmonitor
        systemctl daemon-reload
    fi

    systemctl stop aliyun
    systemctl disable aliyun
    rm -rf /etc/systemd/system/aliyun.service
    systemctl daemon-reload
    apt -y purge aliyun-assist
    $redhat_package_manager -y remove aliyun_assist
    rm -rf /usr/local/share/aliyun-assist
    rm -rf /usr/sbin/aliyun_installer
    rm -rf /usr/sbin/aliyun-service
    rm -rf /usr/sbin/aliyun-service.backup

    pkill -9 AliYunDun
    pkill -9 AliHids
    /etc/init.d/aegis uninstall
    rm -rf /usr/local/aegis
    rm -rf /etc/init.d/aegis
    rm -rf /etc/rc2.d/S80aegis
    rm -rf /etc/rc3.d/S80aegis
    rm -rf /etc/rc4.d/S80aegis
    rm -rf /etc/rc5.d/S80aegis
#Tencent Cloud Shield
    /usr/local/qcloud/stargate/admin/uninstall.sh
    /usr/local/qcloud/YunJing/uninst.sh
    /usr/local/qcloud/monitor/barad/admin/uninstall.sh
    systemctl daemon-reload
    systemctl stop YDService
    systemctl disable YDService
    rm -rf /lib/systemd/system/YDService.service
    systemctl daemon-reload
    sed -i 's#/usr/local/qcloud#rcvtevyy4f5d#g' /etc/rc.local
    sed -i '/rcvtevyy4f5d/d' /etc/rc.local
    rm -rf $(find /etc/udev/rules.d -iname *qcloud* 2>/dev/null)
    pkill -9 YDService
    pkill -9 YDLive
    pkill -9 sgagent
    pkill -9 /usr/local/qcloud
    pkill -9 barad_agent
    rm -rf /usr/local/qcloud
    rm -rf /usr/local/yd.socket.client
    rm -rf /usr/local/yd.socket.server
    mkdir /usr/local/qcloud
    mkdir /usr/local/qcloud/action
    mkdir /usr/local/qcloud/action/login_banner.sh
    mkdir /usr/local/qcloud/action/action.sh
}

#Upgrade system components
doupdate()
{
    updateSystem()
    {
        if ! [[ "$(type -P do-release-upgrade)" ]]; then
            if ! apt -y --no-install-recommends install ubuntu-release-upgrader-core; then
                apt update
                if ! apt -y --no-install-recommends install ubuntu-release-upgrader-core; then
                    red    "Script error!"
                    yellow "Press Enter to continue or Ctrl+c to exit"
                    read -s
                fi
            fi
        fi
        echo -e "\n\n\n"
        tyblue "------------------Please choose to upgrade the system version--------------------"
        tyblue " 1.The latest beta version (now 21.04) (2020.11)"
        tyblue " 2.The latest release (now 20.10) (2020.11)"
        tyblue " 3.The latest LTS version (now 20.04) (2020.11)"
        tyblue "-------------------------Imprint-------------------------"
        tyblue " Beta version: the beta version"
        tyblue " Release version: the stable version"
        tyblue " LTS version: long-term support version, can be understood as a super stable version"
        tyblue "-------------------------Precautions-------------------------"
        yellow " 1.If you encounter a question/dialog box during the upgrade process, if you don’t understand, select yes/y/ the first option"
        yellow " 2.After upgrading the system, it will restart. After restarting, please run this script again to complete the remaining installation"
        yellow " 3.It may take 15 minutes or more to upgrade the system"
        yellow " 4.Sometimes it is not possible to update to the selected version at one time, and may have to be updated multiple times"
        yellow " 5.After upgrading the system, the following configuration may restore the system default configuration:"
        yellow "     ssh port   ssh timeout    bbr acceleration (return to closed state)"
        tyblue "----------------------------------------------------------"
        green  " Your current system version is$systemVersion"
        tyblue "----------------------------------------------------------"
        echo
        choice=""
        while [ "$choice" != "1" -a "$choice" != "2" -a "$choice" != "3" ]
        do
            read -p "Your choices are:" choice
        done
        if ! [[ "$(cat /etc/ssh/sshd_config | grep -i '^[ '$'\t]*port ' | awk '{print $2}')" =~ ^("22"|"")$ ]]; then
            red "The ssh port number was detected to be modified"
            red "The ssh port number may be restored to the default value after upgrading the system(22)"
            yellow "Press Enter to continue. . ."
            read -s
        fi
        local i
        for ((i=0;i<2;i++))
        do
            sed -i '/^[ \t]*Prompt[ \t]*=/d' /etc/update-manager/release-upgrades
            echo 'Prompt=normal' >> /etc/update-manager/release-upgrades
            case "$choice" in
                1)
                    do-release-upgrade -d
                    do-release-upgrade -d
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -d
                    do-release-upgrade -d
                    sed -i 's/Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades
                    do-release-upgrade
                    do-release-upgrade
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade
                    do-release-upgrade
                    ;;
                2)
                    do-release-upgrade
                    do-release-upgrade
                    ;;
                3)
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade
                    do-release-upgrade
                    ;;
            esac
            if ! version_ge $systemVersion 20.04; then
                sed -i 's/Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades
                do-release-upgrade
                do-release-upgrade
            fi
            apt update
            apt -y --auto-remove --purge full-upgrade
        done
    }
    while ((1))
    do
        echo -e "\n\n\n"
        tyblue "-----------------------Do you want to update system components?-----------------------"
        green  " 1. Update the installed software and upgrade the system (for Ubuntu only)"
        green  " 2. Update only installed software"
        red    " 3. Do not update"
        if [ "$release" == "ubuntu" ]; then
            if [ $mem_ok == 2 ]; then
                echo
                yellow "If you want to upgrade the system, please make sure the memory of the server>=512MB"
                yellow "Otherwise it may not be able to boot"
            elif [ $mem_ok == 0 ]; then
                echo
                red "It is detected that the memory is too small, upgrading the system may result in failure to boot, please choose carefully"
            fi
        fi
        echo
        choice=""
        while [ "$choice" != "1" -a "$choice" != "2" -a "$choice" != "3" ]
        do
            read -p "Your choices are:" choice
        done
        if [ "$release" == "ubuntu" ] || [ $choice -ne 1 ]; then
            break
        fi
        echo
        yellow " The update system only supports Ubuntu!"
        sleep 3s
    done
    if [ $choice -eq 1 ]; then
        updateSystem
        apt -y --purge autoremove
        apt clean
    elif [ $choice -eq 2 ]; then
        tyblue "-----------------------Update soon-----------------------"
        yellow " Encountered a question/dialog box during the update process, if you don’t understand, select yes/y/ the first option"
        yellow " Press Enter to continue. . ."
        read -s
        $redhat_package_manager -y autoremove
        $redhat_package_manager -y update
        apt update
        apt -y --auto-remove --purge full-upgrade
        apt -y --purge autoremove
        apt clean
        $redhat_package_manager -y autoremove
        $redhat_package_manager clean all
    fi
}

#Enter the working directory
enter_temp_dir()
{
    rm -rf "$temp_dir"
    mkdir "$temp_dir"
    cd "$temp_dir"
}

#Install bbr
install_bbr()
{
    #输出：latest_kernel_version 和 your_kernel_version
    get_kernel_info()
    {
        green "The latest version of the kernel version number is being obtained. . . .(Automatically skipped if it is not successfully obtained within 60 seconds)"
        local kernel_list
        local kernel_list_temp=($(timeout 60 wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[0-9]/{print $2}' | cut -d '"' -f1 | cut -d '/' -f1 | sort -rV))
        if [ ${#kernel_list_temp[@]} -le 1 ]; then
            latest_kernel_version="error"
            your_kernel_version=$(uname -r | cut -d - -f 1)
            return 1
        fi
        local i=0
        local i2=0
        local i3=0
        local kernel_rc=""
        local kernel_list_temp2
        while ((i2<${#kernel_list_temp[@]}))
        do
            if [[ "${kernel_list_temp[i2]}" =~ "rc" ]] && [ "$kernel_rc" == "" ]; then
                kernel_list_temp2[i3]="${kernel_list_temp[i2]}"
                kernel_rc="${kernel_list_temp[i2]%%-*}"
                ((i3++))
                ((i2++))
            elif [[ "${kernel_list_temp[i2]}" =~ "rc" ]] && [ "${kernel_list_temp[i2]%%-*}" == "$kernel_rc" ]; then
                kernel_list_temp2[i3]=${kernel_list_temp[i2]}
                ((i3++))
                ((i2++))
            elif [[ "${kernel_list_temp[i2]}" =~ "rc" ]] && [ "${kernel_list_temp[i2]%%-*}" != "$kernel_rc" ]; then
                for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
                do
                    kernel_list[i]=${kernel_list_temp2[i3]}
                    ((i++))
                done
                kernel_rc=""
                i3=0
                unset kernel_list_temp2
            elif version_ge "$kernel_rc" "${kernel_list_temp[i2]}"; then
                if [ "$kernel_rc" == "${kernel_list_temp[i2]}" ]; then
                    kernel_list[i]=${kernel_list_temp[i2]}
                    ((i++))
                    ((i2++))
                fi
                for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
                do
                    kernel_list[i]=${kernel_list_temp2[i3]}
                    ((i++))
                done
                kernel_rc=""
                i3=0
                unset kernel_list_temp2
            else
                kernel_list[i]=${kernel_list_temp[i2]}
                ((i++))
                ((i2++))
            fi
        done
        if [ "$kernel_rc" != "" ]; then
            for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
            do
                kernel_list[i]=${kernel_list_temp2[i3]}
                ((i++))
            done
        fi
        latest_kernel_version=${kernel_list[0]}
        your_kernel_version=$(uname -r | cut -d - -f 1)
        check_fake_version()
        {
            local temp=${1##*.}
            if [ ${temp} -eq 0 ]; then
                return 0
            else
                return 1
            fi
        }
        while check_fake_version ${your_kernel_version}
        do
            your_kernel_version=${your_kernel_version%.*}
        done
        if [ $release == "ubuntu" ] || [ $release == "other-debian" ]; then
            local rc_version=$(uname -r | cut -d - -f 2)
            if [[ $rc_version =~ "rc" ]]; then
                rc_version=${rc_version##*'rc'}
                your_kernel_version=${your_kernel_version}-rc${rc_version}
            fi
        else
            latest_kernel_version=${latest_kernel_version%%-*}
        fi
    }
    #Unload excess kernel
    remove_other_kernel()
    {
        if [ $release == "ubuntu" ] || [ $release == "other-debian" ]; then
            local kernel_list_image=($(dpkg --list | grep 'linux-image' | awk '{print $2}'))
            local kernel_list_modules=($(dpkg --list | grep 'linux-modules' | awk '{print $2}'))
            local kernel_now=$(uname -r)
            local ok_install=0
            for ((i=${#kernel_list_image[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_image[$i]}" =~ "$kernel_now" ]]; then     
                    unset kernel_list_image[$i]
                    ((ok_install++))
                fi
            done
            if [ $ok_install -lt 1 ]; then
                red "The kernel in use is not found, it may have been uninstalled"
                yellow "Press Enter to continue. . ."
                read -s
                return 1
            fi
            ok_install=0
            for ((i=${#kernel_list_modules[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_modules[$i]}" =~ "$kernel_now" ]]; then
                    unset kernel_list_modules[$i]
                    ((ok_install++))
                fi
            done
            if [ $ok_install -lt 1 ]; then
                red "The kernel in use is not found, it may have been uninstalled"
                yellow "Press Enter to continue. . ."
                read -s
                return 1
            fi
            if [ ${#kernel_list_modules[@]} -eq 0 ] && [ ${#kernel_list_image[@]} -eq 0 ]; then
                yellow "No kernel to unload"
                return 0
            fi
            apt -y purge ${kernel_list_image[@]} ${kernel_list_modules[@]}
        else
            local kernel_list=($(rpm -qa |grep '^kernel-[0-9]\|^kernel-ml-[0-9]'))
            local kernel_list_devel=($(rpm -qa | grep '^kernel-devel\|^kernel-ml-devel'))
            if version_ge $redhat_version 8; then
                local kernel_list_modules=($(rpm -qa |grep '^kernel-modules\|^kernel-ml-modules'))
                local kernel_list_core=($(rpm -qa | grep '^kernel-core\|^kernel-ml-core'))
            fi
            local kernel_now=$(uname -r)
            local ok_install=0
            for ((i=${#kernel_list[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list[$i]}" =~ "$kernel_now" ]]; then
                    unset kernel_list[$i]
                    ((ok_install++))
                fi
            done
            if [ $ok_install -lt 1 ]; then
                red "The kernel in use is not found, it may have been uninstalled"
                yellow "Press Enter to continue. . ."
                read -s
                return 1
            fi
            for ((i=${#kernel_list_devel[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_devel[$i]}" =~ "$kernel_now" ]]; then
                    unset kernel_list_devel[$i]
                fi
            done
            if version_ge $redhat_version 8; then
                ok_install=0
                for ((i=${#kernel_list_modules[@]}-1;i>=0;i--))
                do
                    if [[ "${kernel_list_modules[$i]}" =~ "$kernel_now" ]]; then
                        unset kernel_list_modules[$i]
                        ((ok_install++))
                    fi
                done
                if [ $ok_install -lt 1 ]; then
                    red "The kernel in use is not found, it may have been uninstalled"
                    yellow "Press Enter to continue. . ."
                    read -s
                    return 1
                fi
                ok_install=0
                for ((i=${#kernel_list_core[@]}-1;i>=0;i--))
                do
                    if [[ "${kernel_list_core[$i]}" =~ "$kernel_now" ]]; then
                        unset kernel_list_core[$i]
                        ((ok_install++))
                    fi
                done
                if [ $ok_install -lt 1 ]; then
                    red "The kernel in use is not found, it may have been uninstalled"
                    yellow "Press Enter to continue. . ."
                    read -s
                    return 1
                fi
            fi
            if ([ ${#kernel_list[@]} -eq 0 ] && [ ${#kernel_list_devel[@]} -eq 0 ]) && (! version_ge $redhat_version 8 || ([ ${#kernel_list_modules[@]} -eq 0 ] && [ ${#kernel_list_core[@]} -eq 0 ])); then
                yellow "No kernel to unload"
                return 0
            fi
            if version_ge $redhat_version 8; then
                $redhat_package_manager -y remove ${kernel_list[@]} ${kernel_list_modules[@]} ${kernel_list_core[@]} ${kernel_list_devel[@]}
            else
                $redhat_package_manager -y remove ${kernel_list[@]} ${kernel_list_devel[@]}
            fi
        fi
        green "-------------------Uninstall complete-------------------"
    }
    local your_kernel_version
    local latest_kernel_version
    get_kernel_info
    if ! grep -q "#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script" /etc/sysctl.conf; then
        echo >> /etc/sysctl.conf
        echo "#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script" >> /etc/sysctl.conf
    fi
    while ((1))
    do
        echo -e "\n\n\n"
        tyblue "------------------Please select the bbr version to use------------------"
        green  " 1. Upgrade the latest version of the kernel and enable bbr (recommended)"
        if version_ge $your_kernel_version 4.9; then
            tyblue " 2. Enable bbr"
        else
            tyblue " 2. Upgrade the kernel to enable bbr"
        fi
        tyblue " 3. Enable bbr2 (need to replace the third-party kernel)"
        tyblue " 4. Enable bbrplus/bbr magic revision/violent bbr magic revision/ruise (need to replace third-party kernel)"
        tyblue " 5. Unload excess kernel"
        tyblue " 6. Exit bbr installation"
        tyblue "------------------Instructions on installing bbr acceleration------------------"
        green  " Bbr acceleration can greatly increase the network speed, it is recommended to install"
        yellow " Replacing the third-party kernel may cause system instability and even unable to boot"
        yellow " You need to restart to replace/upgrade the kernel. After restarting, please run this script again to complete the remaining installation"
        tyblue "---------------------------------------------------------"
        tyblue " Current kernel version：${your_kernel_version}"
        tyblue " The latest kernel version: ${latest_kernel_version}"
        tyblue " Does the current kernel support bbr："
        if version_ge $your_kernel_version 4.9; then
            green "     yes"
        else
            red "     No, need to upgrade the kernel"
        fi
        tyblue "  bbr enabled status:"
        if sysctl net.ipv4.tcp_congestion_control | grep -Eq "bbr|nanqinlang|tsunami"; then
            local bbr_info=$(sysctl net.ipv4.tcp_congestion_control)
            bbr_info=${bbr_info#*=}
            if [ $bbr_info == nanqinlang ]; then
                bbr_info="Violent bbr magic revision"
            elif [ $bbr_info == tsunami ]; then
                bbr_info="bbr magic revision"
            fi
            green "   is using: ${bbr_info}"
        else
            red "   bbr is not enabled"
        fi
        echo
        choice=""
        while [ "$choice" != "1" -a "$choice" != "2" -a "$choice" != "3" -a "$choice" != "4" -a "$choice" != "5" -a "$choice" != "6" ]
        do
            read -p "Your choices are:" choice
        done
        if [ $choice -eq 1 ]; then
            sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
            sed -i '/^[ \t]*net.ipv4.tcp_congestion_control[ \t]*=/d' /etc/sysctl.conf
            echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
            echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
            sysctl -p
            if ! wget -O update-kernel.sh https://github.com/kirin10000/update-kernel/raw/master/update-kernel.sh; then
                red    "Failed to get kernel upgrade script"
                yellow "Press Enter to continue or press ctrl+c to terminate"
                read -s
            fi
            chmod +x update-kernel.sh
            ./update-kernel.sh
            if ! sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
                red "Failed to open bbr"
                red "If you just installed the kernel, please reboot first"
                red "If restarting still does not work, please try to select 2 options"
            else
                green "--------------------bbr is installed--------------------"
            fi
        elif [ $choice -eq 2 ]; then
            sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
            sed -i '/^[ \t]*net.ipv4.tcp_congestion_control[ \t]*=/d' /etc/sysctl.conf
            echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
            echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
            sysctl -p
            sleep 1s
            if ! sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
                if ! wget -O bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh; then
                    red    "Failed to get bbr script"
                    yellow "Press Enter to continue or press ctrl+c to terminate"
                    read -s
                fi
                chmod +x bbr.sh
                ./bbr.sh
            else
                green "--------------------bbr is installed--------------------"
            fi
        elif [ $choice -eq 3 ]; then
            tyblue "--------------------Bbr2 acceleration is about to be installed, and the server will restart after the installation is complete--------------------"
            tyblue " After restarting, please select this option again to complete the remaining part of bbr2 installation (open bbr and ECN)"
            yellow " Press Enter to continue.  . ."
            read -s
            local temp_bbr2
            if [ $release == "ubuntu" ] || [ $release == "other-debian" ]; then
                local temp_bbr2="https://github.com/yeyingorg/bbr2.sh/raw/master/bbr2.sh"
            else
                local temp_bbr2="https://github.com/jackjieYYY/bbr2/raw/master/bbr2.sh"
            fi
            if ! wget -O bbr2.sh $temp_bbr2; then
                red    "Failed to get bbr2 script"
                yellow "Press Enter to continue or press ctrl+c to terminate"
                read -s
            fi
            chmod +x bbr2.sh
            ./bbr2.sh
        elif [ $choice -eq 4 ]; then
            if ! wget -O tcp.sh "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"; then
                red    "Failed to get script"
                yellow "Press Enter to continue or press ctrl+c to terminate"
                read -s
            fi
            chmod +x tcp.sh
            ./tcp.sh
        elif [ $choice -eq 5 ]; then
            tyblue " This operation will unload the remaining kernels except the kernel currently in use"
            tyblue "    The kernel you are using is:$(uname -r)"
            choice=""
            while [[ "$choice" != "y" && "$choice" != "n" ]]
            do
                read -p "Whether to continue? (y/n)" choice
            done
            if [ $choice == y ]; then
                remove_other_kernel
            fi
        else
            break
        fi
        sleep 3s
    done
}

#Read domain name
readDomain()
{
    check_domain()
    {
        local temp=${1%%.*}
        if [ "$temp" == "www" ]; then
            red "Do not bring www in front of the domain name!"
            return 0
        elif [ "$1" == "" ]; then
            return 0
        else
            return 1
        fi
    }
    local domain=""
    local domainconfig=""
    local pretend=""
    echo -e "\n\n\n"
    tyblue "--------------------Please select domain name resolution--------------------"
    tyblue " 1. 一Both the first-level domain name and www.first-level domain name resolve to this server"
    green  "    Such as: 123.com and www.123.com are both resolved to this server"
    tyblue " 2. Only a certain domain name resolves to this server"
    green  "    For example: one of 123.com or www.123.com or xxx.123.com resolves to this server"
    echo
    while [ "$domainconfig" != "1" -a "$domainconfig" != "2" ]
    do
        read -p "Your choices are:" domainconfig
    done
    local queren=""
    while [ "$queren" != "y" ]
    do
        echo
        if [ $domainconfig -eq 1 ]; then
            tyblue '---------Please enter the first-level domain name (without "www.", "http://" or "https://" in front)---------'
            read -p "Please enter the domain name:" domain
            while check_domain $domain
            do
                read -p "Please enter the domain name:" domain
            done
        else
            tyblue '-------Please enter the domain name resolved to this server (without "http://" or "https://" in front)-------'
            read -p "Please enter the domain name:" domain
        fi
        echo
        queren=""
        while [ "$queren" != "y" -a "$queren" != "n" ]
        do
            tyblue "The domain name you entered is\"$domain\"，Are you sure?(y/n)"
            read queren
        done
    done
    echo -e "\n\n\n"
    tyblue "------------------------------Please select the website page to be disguised------------------------------"
    tyblue " 1. 403 pages (simulating the background of the website)"
    green  "    Note: Almost all large websites use the website backend. For example, every video of bilibili is created by"
    green  "    If another domain name is provided, directly accessing the root directory of that domain name will return a 403 or other error page"
    tyblue " 2. Mirror Tencent video website"
    green  "    Note: It is a real mirror site, non-linked redirection, default is Tencent Video, you can modify it yourself after the construction is completed, which may constitute infringement"
    tyblue " 3. nextcloud landing page"
    green  "    Note: Nextclound is an open source private network disk service, pretending that you have built a private network disk (can be replaced with other custom websites)"
    echo
    while [[ x"$pretend" != x"1" && x"$pretend" != x"2" && x"$pretend" != x"3" ]]
    do
        read -p "Your choices are:" pretend
    done
    domain_list+=("$domain")
    domainconfig_list+=("$domainconfig")
    pretend_list+=("$pretend")
}

#Choose tls configuration
readTlsConfig()
{
    echo -e "\n\n\n"
    tyblue "----------------------------------------------------------------"
    tyblue "                      speed                        Anti-blockade"
    tyblue " TLS1.2+1.3：  ++++++++++++++++++++          ++++++++++++++++++++"
    tyblue " 仅TLS1.3：    ++++++++++++++++++++          ++++++++++++++++++"
    tyblue "----------------------------------------------------------------"
    tyblue " After testing, when TLS1.2 and TLS1.3 coexist, v2ray will give priority to TLS1.3 for connection"
    green  " Recommend TLS1.2+1.3"
    echo
    tyblue " 1.TLS1.2+1.3"
    tyblue " 2.TLS1 only.3"
    tlsVersion=""
    while [ "$tlsVersion" != "1" -a "$tlsVersion" != "2" ]
    do
        read -p "Your choices are:"  tlsVersion
    done
}

#读取v2ray_protocol配置
readProtocolConfig()
{
    echo -e "\n\n\n"
    tyblue "---------------------Please select the protocol to be used by V2Ray---------------------"
    tyblue " 1. VLESS"
    green  "    Suitable for direct connection/trusted CDN"
    tyblue " 2. VMess"
    green  "    Suitable for untrusted CDN (such as domestic CDN)"
    red    " 3. socks(5) (Not recommended)"
    echo
    yellow " 注："
    yellow "   1.Theoretical speed comparison of each protocol: https://github.com/badO1a5A90/v2ray-doc/blob/main/performance_test/Xray/speed_test_2020119.md"
    yellow "   2.The VLESS protocol is used for CDN, and CDN can see the transmitted plaintext"
    echo
    protocol=""
    while [[ "$protocol" != "1" && "$protocol" != "2" && "$protocol" != "3" ]]
    do
        read -p "Your choices are:" protocol
    done
}

#Back up domain names to disguise websites
backup_domains_web()
{
    local i
    mkdir "${temp_dir}/domain_backup"
    for i in ${!domain_list[@]}
    do
        if [ "$1" == "cp" ]; then
            cp -rf ${nginx_prefix}/html/${domain_list[i]} "${temp_dir}/domain_backup" 2>/dev/null
        else
            mv ${nginx_prefix}/html/${domain_list[i]} "${temp_dir}/domain_backup" 2>/dev/null
        fi
    done
}

#Uninstall v2ray and nginx
remove_v2ray()
{
    systemctl stop v2ray
    systemctl disable v2ray
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
    rm -rf /usr/bin/v2ray
    rm -rf /etc/v2ray
    rm -rf /usr/local/bin/v2ray
    rm -rf /usr/local/etc/v2ray
    rm -rf /etc/systemd/system/v2ray.service
    rm -rf /etc/systemd/system/v2ray@.service
    systemctl daemon-reload
}
remove_nginx()
{
    systemctl stop nginx
    ${nginx_prefix}/sbin/nginx -s stop
    pkill -9 nginx
    systemctl disable nginx
    rm -rf $nginx_service
    systemctl daemon-reload
    rm -rf ${nginx_prefix}
}

#Install nginx
install_nginx()
{
    green "Compiling and installing nginx. . . ."
    if ! wget -O ${nginx_version}.tar.gz https://nginx.org/download/${nginx_version}.tar.gz; then
        red    "Failed to get nginx"
        yellow "Press Enter to continue or press ctrl+c to terminate"
        read -s
    fi
    tar -zxf ${nginx_version}.tar.gz
    if ! wget -O ${openssl_version}.tar.gz https://github.com/openssl/openssl/archive/${openssl_version#*-}.tar.gz; then
        red    "Failed to get openssl"
        yellow "Press Enter to continue or press ctrl+c to terminate"
        read -s
    fi
    tar -zxf ${openssl_version}.tar.gz
    cd ${nginx_version}
    sed -i "s/OPTIMIZE[ \t]*=>[ \t]*'-O'/OPTIMIZE          => '-O3'/g" src/http/modules/perl/Makefile.PL
    ./configure --prefix=${nginx_prefix} --with-openssl=../$openssl_version --with-openssl-opt="enable-ec_nistp_64_gcc_128 shared threads zlib-dynamic sctp" --with-mail=dynamic --with-mail_ssl_module --with-stream=dynamic --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module=dynamic --with-stream_ssl_preread_module --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-pcre --with-libatomic --with-compat --with-cpp_test_module --with-google_perftools_module --with-file-aio --with-threads --with-poll_module --with-select_module --with-cc-opt="-Wno-error -g0 -O3"
    if ! make; then
        red    "nginx compilation failed!"
        yellow "Please try to change the system, it is recommended to use the latest version of Ubuntu system"
        green  "Welcome Bug report(https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/issues)，thank you for your support"
        exit 1
    fi
    if [ $update == 1 ]; then
        backup_domains_web
    fi
    remove_nginx
    make install
    cd ..
}
config_service_nginx()
{
    systemctl disable nginx
    rm -rf $nginx_service
cat > $nginx_service << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
User=root
ExecStartPre=/bin/rm -rf /dev/shm/nginx_tcmalloc
ExecStartPre=/bin/mkdir /dev/shm/nginx_tcmalloc
ExecStartPre=/bin/chmod 0777 /dev/shm/nginx_tcmalloc
ExecStart=${nginx_prefix}/sbin/nginx
ExecStop=${nginx_prefix}/sbin/nginx -s stop
ExecStopPost=/bin/rm -rf /dev/shm/nginx_tcmalloc
PrivateTmp=true
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 $nginx_service
    systemctl daemon-reload
    systemctl enable nginx
}

#Install/update V2Ray
install_update_v2ray()
{
    green "V2Ray is being installed/updated. . . ."
    if ! bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) && ! bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh); then
        red    "Failed to install/update V2Ray"
        yellow "Press Enter to continue or press ctrl+c to terminate"
        read -s
        return 1
    fi
    if ! grep -q '#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script' /etc/systemd/system/v2ray.service /etc/systemd/system/v2ray@.service; then
        local temp="/etc/systemd/system/v2ray.service"
        local i=2
        while ((i!=0))
        do
            echo >> $temp
            echo "[Service]" >> $temp
            echo "ExecStartPre=/bin/rm -rf /dev/shm/v2ray_unixsocket" >> $temp
            echo "ExecStartPre=/bin/mkdir /dev/shm/v2ray_unixsocket" >> $temp
            echo "ExecStartPre=/bin/chmod 711 /dev/shm/v2ray_unixsocket" >> $temp
            echo "ExecStopPost=/bin/rm -rf /dev/shm/v2ray_unixsocket" >> $temp
            #Solve transparent proxy Too many files problem
            #https://guide.v2fly.org/app/tproxy.html#%E8%A7%A3%E5%86%B3-too-many-open-files-%E9%97%AE%E9%A2%98
            if ! grep -qE 'LimitNPROC|LimitNOFILE' $temp; then
                echo "LimitNPROC=10000" >> $temp
                echo "LimitNOFILE=1000000" >> $temp
            fi
            echo >> $temp
            echo "#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script" >> $temp
            temp="/etc/systemd/system/v2ray@.service"
            ((i--))
        done
        systemctl daemon-reload
        sleep 1s
        if systemctl is-active v2ray > /dev/null 2>&1; then
            systemctl restart v2ray
        fi
    fi
}

#Obtaining certificate parameters: domain domainconfig
get_cert()
{
    if [ $2 -eq 1 ]; then
        local temp="-d www.$1"
    else
        local temp=""
    fi
    if ! $HOME/.acme.sh/acme.sh --issue -d $1 $temp -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --pre-hook "mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --post-hook "mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --ocsp; then
        $HOME/.acme.sh/acme.sh --issue -d $1 $temp -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --pre-hook "mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --post-hook "mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --ocsp --debug
    fi
    if ! $HOME/.acme.sh/acme.sh --installcert -d $1 --key-file ${nginx_prefix}/certs/${1}.key --fullchain-file ${nginx_prefix}/certs/${1}.cer --reloadcmd "sleep 2s && systemctl restart nginx" --ecc; then
        yellow "The certificate installation failed. Please check your domain name to make sure that port 80 is not open and not occupied. And after the installation is complete, use option 9 to repair"
        yellow "Press Enter to continue. . ."
        read -s
    fi
}
get_all_certs()
{
    local i
    for ((i=0;i<${#domain_list[@]};i++))
    do
        get_cert ${domain_list[i]} ${domainconfig_list[i]}
    done
}

#Configuration nginx
config_nginx_init()
{
cat > ${nginx_prefix}/conf/nginx.conf <<EOF

user  root root;
worker_processes  auto;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;
google_perftools_profiles /dev/shm/nginx_tcmalloc/tcmalloc;

events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    #                  '\$status \$body_bytes_sent "\$http_referer" '
    #                  '"\$http_user_agent" "\$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  1200s;

    #gzip  on;

    include       $nginx_config;
    #server {
        #listen       80;
        #server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        #location / {
        #    root   html;
        #    index  index.html index.htm;
        #}

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        #error_page   500 502 503 504  /50x.html;
        #location = /50x.html {
        #    root   html;
        #}

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \\.php\$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \\.php\$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts\$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\\.ht {
        #    deny  all;
        #}
    #}


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}
EOF
}
config_nginx()
{
    config_nginx_init
    local i
    get_all_domains
cat > $nginx_config<<EOF
server {
    listen 80 reuseport default_server;
    listen [::]:80 reuseport default_server;
    return 301 https://${all_domains[0]};
}
server {
    listen 80;
    listen [::]:80;
    server_name ${all_domains[@]};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2 reuseport default_server;
    listen [::]:443 ssl http2 reuseport default_server;
    ssl_certificate         ${nginx_prefix}/certs/${domain_list[0]}.cer;
    ssl_certificate_key     ${nginx_prefix}/certs/${domain_list[0]}.key;
EOF
    if [ $tlsVersion -eq 1 ]; then
        echo "    ssl_protocols           TLSv1.3 TLSv1.2;" >> $nginx_config
        echo "    ssl_ciphers             ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;" >> $nginx_config
    else
        echo "    ssl_protocols           TLSv1.3;" >> $nginx_config
    fi
    echo "    return 301 https://${all_domains[0]};" >> $nginx_config
    echo "}" >> $nginx_config
    for ((i=0;i<${#domain_list[@]};i++))
    do
cat >> $nginx_config<<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
EOF
        if [ ${domainconfig_list[i]} -eq 1 ]; then
            echo "    server_name www.${domain_list[i]} ${domain_list[i]};" >> $nginx_config
        else
            echo "    server_name ${domain_list[i]};" >> $nginx_config
        fi
cat >> $nginx_config<<EOF
    ssl_certificate         ${nginx_prefix}/certs/${domain_list[i]}.cer;
    ssl_certificate_key     ${nginx_prefix}/certs/${domain_list[i]}.key;
EOF
        if [ $tlsVersion -eq 1 ]; then
            echo "    ssl_protocols           TLSv1.3 TLSv1.2;" >> $nginx_config
            echo "    ssl_ciphers             ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;" >> $nginx_config
        else
            echo "    ssl_protocols           TLSv1.3;" >> $nginx_config
        fi
cat >> $nginx_config<<EOF
    ssl_stapling            on;
    ssl_stapling_verify     on;
    ssl_trusted_certificate ${nginx_prefix}/certs/${domain_list[i]}.cer;
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload" always;
EOF
        if [ ${pretend_list[i]} -eq 3 ]; then
            echo "    root ${nginx_prefix}/html/${domain_list[i]};" >> $nginx_config
        fi
cat >> $nginx_config<<EOF
    location = $path {
        proxy_redirect off;
        proxy_pass http://unix:/dev/shm/v2ray_unixsocket/ws.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
EOF
        if [ ${pretend_list[i]} -eq 2 ]; then
cat >> $nginx_config<<EOF
    location / {
        proxy_pass https://v.qq.com;
        proxy_set_header referer "https://v.qq.com";
    }
EOF
        elif [ ${pretend_list[i]} -eq 1 ]; then
cat >> $nginx_config<<EOF
    location / {
        return 403;
    }
EOF
        fi
        echo "}" >> $nginx_config
    done
}

#Configuration v2ray
config_v2ray()
{
cat > $v2ray_config <<EOF
{
    "log": {
        "loglevel": "none"
    },
    "inbounds": [
        {
            "listen": "/dev/shm/v2ray_unixsocket/ws.sock",
EOF
    if [ $protocol -eq 1 ]; then
cat >> $v2ray_config <<EOF
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$v2id"
                    }
                ],
                "decryption": "none"
            },
EOF
    elif [ $protocol -eq 2 ]; then
cat >> $v2ray_config <<EOF
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$v2id"
                    }
                ]
            },
EOF
    elif [ $protocol -eq 3 ]; then
cat >> $v2ray_config <<EOF
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": false
            },
EOF
    fi
cat >> $v2ray_config <<EOF
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "$path"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

#Download nextcloud template for disguise    Parameters: domain pretend
get_web()
{
    if [ $2 -eq 3 ]; then
        rm -rf ${nginx_prefix}/html/$1
        mkdir ${nginx_prefix}/html/$1
        if ! wget -O ${nginx_prefix}/html/$1/Website-Template.zip https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/raw/master/Website-Template.zip; then
            red    "Failed to get website template"
            yellow "Press Enter to continue or press ctrl+c to terminate"
            read -s
        fi
        unzip -q -d ${nginx_prefix}/html/$1 ${nginx_prefix}/html/$1/Website-Template.zip
        rm -rf ${nginx_prefix}/html/$1/Website-Template.zip
    fi
}
get_all_webs()
{
    local i
    for ((i=0;i<${#domain_list[@]};i++))
    do
        get_web ${domain_list[i]} ${pretend_list[i]}
    done
}

echo_end()
{
    get_all_domains
    echo -e "\n\n\n"
    tyblue "------------------------ V2Ray-WebSocket+TLS+Web -----------------------"
    if [ $protocol -ne 3 ]; then
        if [ $protocol -eq 1 ]; then
            tyblue " Server type            ：VLESS"
        else
            tyblue " Server type            ：VMess"
        fi
        if [ ${#all_domains[@]} -eq 1 ]; then
            tyblue " address(address)         ：${all_domains[@]}"
        else
            tyblue " address(address)         ：${all_domains[@]} \033[35m(任选其一)"
        fi
        purple "  (Qv2ray:Host)"
        tyblue " port(port)            ：443"
        tyblue " id(User ID/UUID)       ：${v2id}"
        if [ $protocol -eq 1 ]; then
            tyblue " flow(Flow Control)            ：empty"
            tyblue " encryption(encryption)      ：none"
        else
            tyblue " alterId(Extra ID)       ：0"
            tyblue " security(encryption method)    ：use CDN，recommend auto;do not use CDN，recommend none"
            purple "  (Qv2ray: security option; Shadowrocket: algorithm)"
        fi
        tyblue " ---Transport/StreamSettings(underlying transmission mode/stream settings)---"
        tyblue "  network(transmission protocol)             ：ws"
        purple "   (Shadowrocket: transmission method: websocket)"
        tyblue "  path(path)                    ：${path}"
        tyblue "  Host                          ：empty"
        purple "   (V2RayN(G):camouflage domain name;Qv2ray: protocol setting-request header)"
        tyblue "  security(transport layer encryption)          ：tls"
        purple "   (V2RayN(G):underlying transmission security;Qv2ray:TLS setting-security type)"
        tyblue "  serverName(verification server certificate domain name)：empty"
        purple "   (V2RayN(G):camouflage domain name;Qv2ray:TLS setting-server address;Shadowrocket:Peer name)"
        tyblue "  allowInsecure                 ：false"
        purple "   (Qv2ray:Allow insecure certificates (not tick);Shadowrocket:Allow insecure (closed))"
        tyblue " ------------------------other-----------------------"
        tyblue "  Mux(Multiplex)                 ：It is recommended to close"
        tyblue "  Sniffing(traffic detection)            ：recommended to open"
        purple "   (Qv2ray:Preferences-Inbound Settings-SOCKS Settings-Sniffing)"
        tyblue "------------------------------------------------------------------------"
        echo
        if [ $protocol -eq 2 ]; then
            yellow " Please upgrade V2Ray to v4.28.0+To enable VMessAEAD"
        else
            yellow " Please make sure the client V2Ray version is v4.30.0+(VLESS在4.30.UDP transmission has been updated once in version 0, and it is not backward compatible)"
        fi
    else
        echo_end_socks
    fi
    echo
    tyblue " To enable VMessAEAD"
    tyblue " modify $nginx_config"
    tyblue " modify v.qq.com to the website you want to mirror"
    echo
    tyblue " Script Last updated: 2020.12.01"
    echo
    red    " This script is only for communication and learning, please do not use this script to commit illegal things. If you do illegal things in places outside the illegal network, you will be subject to legal sanctions.!!!!"
    tyblue " 2019.11"
}
echo_end_socks()
{
    tyblue "Copy the following paragraph of text and save it in a text file"
    tyblue "Modify the four words "your domain name" to one of your domain names (keep the quotation marks), that is, how to fill in the "address" column in the original configuration, and how to fill in here"
    tyblue "And rename the text file to config.json"
    tyblue "Then in V2RayN/V2RayNG, select Import custom configuration, select config.json"
    yellow "---------------The following is the text---------------"
cat <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": 10808,
            "protocol": "socks",
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls"]
            },
            "settings": {
                "auth": "noauth",
                "userLevel": 10,
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "socks",
            "settings": {
                "servers": [
                    {
EOF
if [ ${#all_domains[@]} -eq 1 ]; then
    echo '                        "address": "'${all_domains[@]}'",'
else
    echo '                        "address": "'${all_domains[@]}' (Choose one)",'
fi
cat <<EOF
                        "level": 10,
                        "port": 443
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "wsSettings": {
                    "path": "$path"
                },
                "sockopt": {
                    "tcpFastOpen": true
                }
            },
            "mux": {
                "enabled": true,
                "concurrency": 8
            }
        }
    ]
}
EOF
    yellow "----------------------------------------"
    tyblue "------------------------------------------------------------------------"
}

#Delete all domains
remove_all_domains()
{
    for i in ${!domain_list[@]}
    do
        rm -rf ${nginx_prefix}/html/${domain_list[$i]}
    done
    unset domain_list
    unset domainconfig_list
    unset pretend_list
}

#Get configuration information path v2id protocol tlsVersion
get_base_information()
{
    path=`grep path $v2ray_config`
    path=${path##*' '}
    path=${path#*'"'}
    path=${path%'"'*}
    if grep -m 1 "ssl_protocols" $nginx_config | grep -q "TLSv1.2"; then
        tlsVersion=1
    else
        tlsVersion=2
    fi
    if grep -q "id" $v2ray_config; then
        v2id=`grep id $v2ray_config`
        v2id=${v2id##*' '}
        v2id=${v2id#*'"'}
        v2id=${v2id%'"'*}
        if grep -q "vless" $v2ray_config; then
            protocol=1
        else
            protocol=2
        fi
    else
        v2id=""
        protocol=3
    fi
}

#Get a list of domain names
get_domainlist()
{
    unset domain_list
    unset domainconfig_list
    unset pretend_list
    domain_list=($(grep '^[ '$'\t]*server_name[ '$'\t].*;' $nginx_config | cut -d ';' -f 1 | awk 'NR>1 {print $NF}'))
    local line
    local i
    for i in ${!domain_list[@]}
    do
        line=$(grep -n "server_name www.${domain_list[i]} ${domain_list[i]};" $nginx_config | tail -n 1 | awk -F : '{print $1}')
        if [ "$line" == "" ]; then
            line=$(grep -n "server_name ${domain_list[i]};" $nginx_config | tail -n 1 | awk -F : '{print $1}')
            domainconfig_list[i]=2
        else
            domainconfig_list[i]=1
        fi
        if awk 'NR=='"$(($line+18-$tlsVersion))"' {print $0}' $nginx_config | grep -q "proxy_pass"; then
            pretend_list[i]=2
        elif awk 'NR=='"$(($line+18-$tlsVersion))"' {print $0}' $nginx_config | grep -q "return 403"; then
            pretend_list[i]=1
        else
            pretend_list[i]=3
        fi
    done
}

#Install v2ray_ws_tls_web
install_update_v2ray_ws_tls()
{
    install_dependence()
    {
        if [ $release == "ubuntu" ] || [ $release == "other-debian" ]; then
            if ! apt -y --no-install-recommends install $1; then
                apt update
                if ! apt -y --no-install-recommends install $1; then
                    yellow "Dependency installation failed! !"
                    green  "Welcome to bug report(https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/issues),thank you for your support"
                    yellow "Press Enter to continue or Ctrl+c to exit"
                    read -s
                fi
            fi
        else
            if $redhat_package_manager --help | grep -q "\-\-enablerepo="; then
                local temp_redhat_install="$redhat_package_manager -y --enablerepo="
            else
                local temp_redhat_install="$redhat_package_manager -y --enablerepo "
            fi
            if ! $redhat_package_manager -y install $1; then
                if [ "$release" == "centos" ] && version_ge $systemVersion 8 && $temp_redhat_install"epel,PowerTools" install $1;then
                    return 0
                fi
                if $temp_redhat_install'*' install $1; then
                    return 0
                fi
                yellow "Dependency installation failed! !"
                green  "Welcome to bug report(https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/issues),thank you for your support"
                yellow "Press Enter to continue or Ctrl+c to exit"
                read -s
            fi
        fi
    }
    systemctl stop nginx
    systemctl stop v2ray
    check_port
    apt -y -f install
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_nginx
    check_SELinux
    check_ssh_timeout
    uninstall_firewall
    doupdate
    enter_temp_dir
    install_bbr
    apt -y -f install

#Read information
    if [ $update == 0 ]; then
        readDomain
        readTlsConfig
        readProtocolConfig
    else
        get_base_information
        get_domainlist
    fi

    green "The dependencies are being installed. . . ."
    if [ $release == "centos" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence "gperftools-devel libatomic_ops-devel pcre-devel zlib-devel libxslt-devel gd-devel perl-ExtUtils-Embed perl-Data-Dumper perl-IPC-Cmd geoip-devel lksctp-tools-devel libxml2-devel gcc gcc-c++ wget unzip curl make openssl crontabs"
        ##libxml2-devel optional
    else
        if [ "$release" == "ubuntu" ] && [ "$systemVersion" == "20.04" ] && [ "$(uname -m)" == "x86_64" ]; then
            install_dependence "gcc-10 g++-10"
            apt -y purge gcc g++ gcc-9 g++-9 gcc-8 g++-8 gcc-7 g++-7
            apt -y autopurge
            install_dependence "gcc-10 g++-10 libgoogle-perftools-dev libatomic-ops-dev libperl-dev libxslt-dev zlib1g-dev libpcre3-dev libgeoip-dev libgd-dev libxml2-dev libsctp-dev wget unzip curl make openssl cron"
            ln -s -f /usr/bin/gcc-10                         /usr/bin/gcc
            ln -s -f /usr/bin/gcc-10                         /usr/bin/cc
            ln -s -f /usr/bin/x86_64-linux-gnu-gcc-10        /usr/bin/x86_64-linux-gnu-gcc
            ln -s -f /usr/bin/g++-10                         /usr/bin/g++
            ln -s -f /usr/bin/g++-10                         /usr/bin/c++
            ln -s -f /usr/bin/x86_64-linux-gnu-g++-10        /usr/bin/x86_64-linux-gnu-g++
            ln -s -f /usr/bin/gcc-ar-10                      /usr/bin/gcc-ar
            ln -s -f /usr/bin/x86_64-linux-gnu-gcc-ar-10     /usr/bin/x86_64-linux-gnu-gcc-ar
            ln -s -f /usr/bin/gcc-nm-10                      /usr/bin/gcc-nm
            ln -s -f /usr/bin/x86_64-linux-gnu-gcc-nm-10     /usr/bin/x86_64-linux-gnu-gcc-nm
            ln -s -f /usr/bin/gcc-ranlib-10                  /usr/bin/gcc-ranlib
            ln -s -f /usr/bin/x86_64-linux-gnu-gcc-ranlib-10 /usr/bin/x86_64-linux-gnu-gcc-ranlib
            ln -s -f /usr/bin/cpp-10                         /usr/bin/cpp
            ln -s -f /usr/bin/x86_64-linux-gnu-cpp-10        /usr/bin/x86_64-linux-gnu-cpp
            ln -s -f /usr/bin/gcov-10                        /usr/bin/gcov
            ln -s -f /usr/bin/gcov-dump-10                   /usr/bin/gcov-dump
            ln -s -f /usr/bin/gcov-tool-10                   /usr/bin/gcov-tool
            ln -s -f /usr/bin/x86_64-linux-gnu-gcov-10       /usr/bin/x86_64-linux-gnu-gcov
            ln -s -f /usr/bin/x86_64-linux-gnu-gcov-dump-10  /usr/bin/x86_64-linux-gnu-gcov-dump
            ln -s -f /usr/bin/x86_64-linux-gnu-gcov-tool-10  /usr/bin/x86_64-linux-gnu-gcov-tool
        else
            install_dependence "gcc g++ libgoogle-perftools-dev libatomic-ops-dev libperl-dev libxslt-dev zlib1g-dev libpcre3-dev libgeoip-dev libgd-dev libxml2-dev libsctp-dev wget unzip curl make openssl cron"
            ##libxml2-dev optional
        fi
    fi
    apt clean
    $redhat_package_manager clean all

##Install nginx
    if [ $nginx_is_installed -eq 0 ]; then
        install_nginx
    else
        choice=""
        if [ $update -eq 1 ]; then
            while [ "$choice" != "y" ] && [ "$choice" != "n" ]
            do
                tyblue "Whether to update Nginx?(y/n)"
                read choice
            done
        else
            tyblue "---------------Detected that nginx already exists---------------"
            tyblue " 1. Try to use existing nginx"
            tyblue " 2. Uninstall the existing nginx and recompile and install"
            echo
            yellow " If Nginx fails to start after installation, please uninstall and reinstall"
            echo
            while [ "$choice" != "1" ] && [ "$choice" != "2" ]
            do
                read -p "Your choices are:" choice
            done
        fi
        if [ "$choice" == "y" ] || [ "$choice" == "2" ]; then
            install_nginx
        else
            [ $update -eq 1 ] && backup_domains_web
            local temp_domain_bak=("${domain_list[@]}")
            local temp_domainconfig_bak=("${domainconfig_list[@]}")
            local temp_pretend_bak=("${pretend_list[@]}")
            get_domainlist
            remove_all_domains
            domain_list=("${temp_domain_bak[@]}")
            domainconfig_list=("${temp_domainconfig_bak[@]}")
            pretend_list=("${temp_pretend_bak[@]}")
            rm -rf ${nginx_prefix}/conf.d
            rm -rf ${nginx_prefix}/certs
            rm -rf ${nginx_prefix}/html/issue_certs
            rm -rf ${nginx_prefix}/conf/issue_certs.conf
            cp ${nginx_prefix}/conf/nginx.conf.default ${nginx_prefix}/conf/nginx.conf
        fi
    fi
    mkdir ${nginx_prefix}/conf.d
    mkdir ${nginx_prefix}/certs
    mkdir ${nginx_prefix}/html/issue_certs
cat > ${nginx_prefix}/conf/issue_certs.conf << EOF
events {
    worker_connections  1024;
}
http {
    server {
        listen [::]:80 ipv6only=off;
        root ${nginx_prefix}/html/issue_certs;
    }
}
EOF
    config_service_nginx

#Install V2Ray
    remove_v2ray
    install_update_v2ray
    systemctl enable v2ray

    green "Obtaining certificate. . . ."
    if [ $update -eq 0 ]; then
        [ -e $HOME/.acme.sh/acme.sh ] && $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
        curl https://get.acme.sh | sh
    fi
    $HOME/.acme.sh/acme.sh --upgrade --auto-upgrade
    get_all_certs

    if [ $update == 0 ]; then
        path=$(cat /dev/urandom | head -c 8 | md5sum | head -c 7)
        path="/$path"
        v2id=$(cat /proc/sys/kernel/random/uuid)
    fi
    config_nginx
    config_v2ray
    if [ $update == 1 ]; then
        mv "${temp_dir}/domain_backup/"* ${nginx_prefix}/html 2>/dev/null
    else
        get_all_webs
    fi
    sleep 2s
    systemctl restart nginx
    systemctl restart v2ray
    if [ $update == 1 ]; then
        green "-------------------update completed-------------------"
    else
        green "-------------------The installation is complete-------------------"
    fi
    echo_end
    rm -rf "$temp_dir"
}

#Start Menu
start_menu()
{
    change_protocol()
    {
        get_base_information
        local old_protocol=$protocol
        readProtocolConfig
        if [ $old_protocol -eq $protocol ]; then
            red "The transmission protocol is not changed"
            return 0
        fi
        if [ $old_protocol -eq 3 ]; then
            v2id=`cat /proc/sys/kernel/random/uuid`
        fi
        get_domainlist
        config_v2ray
        systemctl restart v2ray
        green "Successful replacement! !"
        echo_end
    }
    change_dns()
    {
        red    "note! !"
        red    "1.Some cloud service providers (such as Alibaba Cloud) use the local server as the source of the package, and the source needs to be changed after modifying the dns! !"
        red    "  If you don’t understand, please modify dns after installation, and do not reinstall after modification"
        red    "2.The original dns may be restored after the Ubuntu system restarts"
        tyblue "This operation will modify the dns server to 1.1.1.1 and 1.0.0.1 (cloudflare public dns)"
        choice=""
        while [ "$choice" != "y" -a "$choice" != "n" ]
        do
            tyblue "Do you want to continue?(y/n)"
            read choice
        done
        if [ $choice == y ]; then
            if ! grep -q "#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script" /etc/resolv.conf; then
                sed -i 's/^[ \t]*nameserver[ \t][ \t]*/#&/' /etc/resolv.conf
                echo >> /etc/resolv.conf
                echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
                echo 'nameserver 1.0.0.1' >> /etc/resolv.conf
                echo '#This file has been edited by v2ray-WebSocket-TLS-Web-setup-script' >> /etc/resolv.conf
            fi
            green "The modification is complete! !"
        fi
    }
    if [ $v2ray_is_installed -eq 1 ]; then
        local v2ray_status="\033[32m installed"
    else
        local v2ray_status="\033[31m not installed"
    fi
    if systemctl is-active v2ray > /dev/null 2>&1; then
        v2ray_status="${v2ray_status}                \033[32m running"
    else
        v2ray_status="${v2ray_status}                \033[31m not running"
    fi
    if [ $nginx_is_installed -eq 1 ]; then
        local nginx_status="\033[32m installed"
    else
        local nginx_status="\033[31m not installed"
    fi
    if systemctl is-active nginx > /dev/null 2>&1; then
        nginx_status="${nginx_status}                \033[32m running"
    else
        nginx_status="${nginx_status}                \033[31m not running"
    fi
    tyblue "-------------- V2Ray-WebSocket(ws)+TLS(1.3)+Web Build/manage script --------------"
    echo
    tyblue "            V2Ray：            ${v2ray_status}"
    echo
    tyblue "            Nginx：            ${nginx_status}"
    echo
    tyblue " Official website: https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script"
    echo
    tyblue "----------------------------------Precautions----------------------------------"
    yellow " 1. This script requires a domain name that resolves to this server"
    tyblue " 2. This script takes a long time to install. For detailed reasons, see:"
    tyblue "       https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script#安装时长说明"
    green  " 3. It is recommended to use a pure system (VPS console-reset system)"
    green  " 4. Recommend to use the latest version of Ubuntu system"
    tyblue "----------------------------------------------------------------------------"
    echo
    echo
    tyblue " -----------Install/upgrade/uninstall-----------"
    if [ $is_installed -eq 0 ]; then
        green  "   1. Install V2Ray-WebSocket+TLS+Web"
    else
        green  "   1. Reinstall V2Ray-WebSocket+TLS+Web"
    fi
    green  "   2. Upgrade V2Ray-WebSocket+TLS+Web"
    tyblue "   3. Install bbr only(Contains bbr2/bbrplus/bbr magic revision / violence bbr magic revision / sharp speed)"
    tyblue "   4. Only upgrade V2Ray"
    red    "   5. Uninstall V2Ray-WebSocket+TLS+Web"
    echo
    tyblue " --------------start stop-------------"
    if systemctl is-active v2ray > /dev/null 2>&1 && systemctl is-active nginx > /dev/null 2>&1; then
        tyblue "   6. Restart V2Ray-WebSocket+TLS+Web"
    else
        tyblue "   6. Start V2Ray-WebSocket+TLS+Web"
    fi
    tyblue "   7. Stop V2Ray-WebSocket+TLS+Web"
    echo
    tyblue " ----------------management----------------"
    tyblue "   8. View configuration information"
    tyblue "   9. Reset domain name and TLS configuration"
    tyblue "      (The original domain name configuration will be overwritten. During the installation process, the domain name was entered incorrectly, causing V2Ray to fail to start. You can use this option to repair)"
    tyblue "  10. Add domain name"
    tyblue "  11. Delete domain name"
    tyblue "  12. Modify id(User ID/UUID)"
    tyblue "  13. Modify path"
    tyblue "  14. Modify the V2Ray transmission protocol"
    echo
    tyblue " ----------------other----------------"
    tyblue "  15. Try to fix the problem that the backspace key cannot be used"
    tyblue "  16. Modify dns"
    yellow "  17. Exit script"
    echo
    echo
    choice=""
    while [[ "$choice" != "1" && "$choice" != "2" && "$choice" != "3" && "$choice" != "4" && "$choice" != "5" && "$choice" != "6" && "$choice" != "7" && "$choice" != "8" && "$choice" != "9" && "$choice" != "10" && "$choice" != "11" && "$choice" != "12" && "$choice" != "13" && "$choice" != "14" && "$choice" != "15" && "$choice" != "16" && "$choice" != "17" ]]
    do
        read -p "Your choices are:" choice
    done
    if [ $choice -eq 1 ]; then
        install_update_v2ray_ws_tls
    elif [ $choice -eq 2 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        yellow "Upgrade bbr/system may need to restart, after restart, please select'Upgrade V2Ray-WebSocket+TLS+Web again'"
        yellow "Press Enter to continue, or ctrl+c to abort"
        read -s
        rm -rf "$0"
        if ! wget -O "$0" "https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/raw/master/V2Ray-WebSocket(ws)+TLS(1.3)+Web-setup.sh" && ! wget -O "$0" "https://github.com/kirin10000/V2Ray-WebSocket-TLS-Web-setup-script/raw/master/V2Ray-WebSocket(ws)+TLS(1.3)+Web-setup.sh"; then
            red "Failed to get the latest script!"
            exit 1
        fi
        chmod +x "$0"
        "$0" --update
    elif [ $choice -eq 3 ]; then
        apt -y -f install
        get_system_info
        check_important_dependence_installed ca-certificates ca-certificates
        enter_temp_dir
        install_bbr
        apt -y -f install
        rm -rf "$temp_dir"
    elif [ $choice -eq 4 ]; then
        if install_update_v2ray; then
            green "V2Ray upgrade is complete!"
        else
            red   "V2Ray upgrade failed!"
        fi
    elif [ $choice -eq 5 ]; then
        choice=""
        while [ "$choice" != "y" -a "$choice" != "n" ]
        do
            yellow "You sure you want to delete it?(y/n)"
            read choice
        done
        if [ "$choice" == "n" ]; then
            exit 0
        fi
        remove_v2ray
        remove_nginx
        $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
        green "The deletion is complete!"
    elif [ $choice -eq 6 ]; then
        if systemctl is-active v2ray > /dev/null 2>&1 && systemctl is-active nginx > /dev/null 2>&1; then
            local temp_is_active=1
        else
            local temp_is_active=0
        fi
        systemctl restart nginx
        systemctl restart v2ray
        sleep 1s
        if ! systemctl is-active v2ray > /dev/null 2>&1; then
            red "V2Ray failed to start! !"
        elif ! systemctl is-active nginx > /dev/null 2>&1; then
            red "Nginx failed to start! !"
        else
            if [ $temp_is_active -eq 1 ]; then
                green "Successful restart! !"
            else
                green "Successfully started! !"
            fi
        fi
    elif [ $choice -eq 7 ]; then
        systemctl stop nginx
        systemctl stop v2ray
        green "stopped!"
    elif [ $choice -eq 8 ]; then
        get_base_information
        get_domainlist
        echo_end
    elif [ $choice -eq 9 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        yellow "Resetting the domain name will delete all existing domain names (including domain name certificates, fake websites, etc.)"
        choice=""
        while [[ "$choice" != "y" && "$choice" != "n" ]]
        do
            tyblue "Whether to continue?(y/n)"
            read choice
        done
        if [ $choice == n ]; then
            return 0
        fi
        green "Reset domain name. . ."
        $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
        curl https://get.acme.sh | sh
        $HOME/.acme.sh/acme.sh --upgrade --auto-upgrade
        get_base_information
        get_domainlist
        remove_all_domains
        readDomain
        readTlsConfig
        get_all_certs
        get_all_webs
        config_nginx
        sleep 2s
        systemctl restart nginx
        green "The domain name reset is complete! !"
        echo_end
    elif [ $choice -eq 10 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        get_base_information
        get_domainlist
        readDomain
        get_cert ${domain_list[-1]} ${domainconfig_list[-1]}
        get_web ${domain_list[-1]} ${pretend_list[-1]}
        config_nginx
        sleep 2s
        systemctl restart nginx
        green "The domain name is added! !"
        echo_end
    elif [ $choice -eq 11 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        get_base_information
        get_domainlist
        if [ ${#domain_list[@]} -le 1 ]; then
            red "Only one domain name"
            exit 1
        fi
        tyblue "-----------------------Please select the domain name to be deleted-----------------------"
        for i in ${!domain_list[@]}
        do
            if [ ${domainconfig_list[i]} -eq 1 ]; then
                tyblue " ${i}. www.${domain_list[i]} ${domain_list[i]}"
            else
                tyblue " ${i}. ${domain_list[i]}"
            fi
        done
        yellow " ${#domain_list[@]}. Do not delete"
        local delete=""
        while ! [[ "$delete" =~ ^([1-9][0-9]*|0)$ ]] || [ $delete -gt ${#domain_list[@]} ]
        do
            read -p "Your options are:" delete
        done
        if [ $delete -eq ${#domain_list[@]} ]; then
            exit 0
        fi
        $HOME/.acme.sh/acme.sh --remove --domain ${domain_list[$delete]} --ecc
        rm -rf $HOME/.acme.sh/${domain_list[$delete]}_ecc
        rm -rf ${nginx_prefix}/html/${domain_list[$delete]}
        unset domain_list[$delete]
        unset domainconfig_list[$delete]
        unset pretend_list[$delete]
        domain_list=(${domain_list[@]})
        domainconfig_list=(${domainconfig_list[@]})
        pretend_list=(${pretend_list[@]})
        config_nginx
        systemctl restart nginx
        green "The domain name deletion is complete! !"
        echo_end
    elif [ $choice -eq 12 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        get_base_information
        if [ $protocol -eq 3 ]; then
            red "Socks mode has no id! !"
            exit 1
        fi
        tyblue "Your current id is:$v2id"
        choice=""
        while [ "$choice" != "y" -a "$choice" != "n" ]
        do
            tyblue "Do you want to continue?(y/n)"
            read choice
        done
        if [ $choice == "n" ]; then
            exit 0
        fi
        tyblue "-------------Please enter a new id-------------"
        read v2id
        config_v2ray
        systemctl restart v2ray
        green "Successful replacement! !"
        green "New id:$v2id"
    elif [ $choice -eq 13 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        get_base_information
        tyblue "Your current path is: $path"
        choice=""
        while [ "$choice" != "y" -a "$choice" != "n" ]
        do
            tyblue "Do you want to continue?(y/n)"
            read choice
        done
        if [ $choice == "n" ]; then
            exit 0
        fi
        local temp_old_path="$path"
        tyblue "---------------Please enter a new path (with \"/\")---------------"
        read path
        config_v2ray
        sed -i s#"$temp_old_path"#"$path"# $nginx_config
        systemctl restart v2ray
        systemctl restart nginx
        green "Successful replacement! !"
        green "New path：$path"
    elif [ $choice -eq 14 ]; then
        if [ $is_installed == 0 ]; then
            red "Please install V2Ray first-WebSocket+TLS+Web！！"
            exit 1
        fi
        change_protocol
    elif [ $choice -eq 15 ]; then
        echo
        yellow "Try to fix the abnormal problem of the backspace key, please don't fix it if the backspace key is normal"
        yellow "Press Enter to continue or Ctrl+c to exit"
        read -s
        if stty -a | grep -q 'erase = ^?'; then
            stty erase '^H'
        elif stty -a | grep -q 'erase = ^H'; then
            stty erase '^?'
        fi
        green "The repair is complete! !"
        sleep 3s
        start_menu
    elif [ $choice -eq 16 ]; then
        change_dns
    fi
}

if ! [ "$1" == "--update" ]; then
    update=0
    start_menu
else
    update=1
    install_update_v2ray_ws_tls
fi
