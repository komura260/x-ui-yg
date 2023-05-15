#!/bin/bash
[[ $EUID -ne 0 ]] && echo "请以root模式运行脚本" && exit
if [[ -f /etc/redhat-release ]]; then
release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
release="centos"
else
echo "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统" && exit
fi
bit=`uname -m`
if [[ $bit = aarch64 ]]; then
wget -O /root/xuiyg.sh https://gitlab.com/rwkgyg/x-ui-yg/-/raw/main/version/install.sh.a >/dev/null 2>&1
chmod +x /root/xuiyg.sh
./xuiyg.sh
elif [[ $bit = x86_64 ]]; then
wget -O /root/xuiyg.sh https://gitlab.com/rwkgyg/x-ui-yg/-/raw/main/version/install.sh >/dev/null 2>&1
chmod +x /root/xuiyg.sh
./xuiyg.sh
else
echo "目前脚本不支持$bit架构" && exit
fi
rm -rf /root/install.sh
