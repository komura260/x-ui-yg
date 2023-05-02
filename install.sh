#!/bin/bash
xuiygV="23.5.1 V 2.0 大更新！
建议在/etc/x-ui-yg路径中导出x-ui-yg.db数据文件，做好备份哦"
remoteV=`wget -qO- https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh | sed  -n 2p | cut -d '"' -f 2`
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
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
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统" && exit
fi
if [[ $release = Centos ]]; then
[[ ! ${vsid} =~ 7|8 ]] && yellow "当前系统版本号：Centos $vsid \n当前版本仅支持Centos 7/8系统 " && exit 
elif [[ $release = Ubuntu ]]; then
[[ ! ${vsid} =~ 18|19|20|22 ]] && yellow "当前系统版本号：Ubuntu $vsid \n当前版本仅支持 Ubuntu 18.04/20.04/22.04系统 " && exit 
elif [[ $release = Debian ]]; then
[[ ! ${vsid} =~ 9|10|11 ]] && yellow "当前系统版本号：Debian $vsid \n当前版本仅支持 Debian 9/10/11系统 " && exit 
fi
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1}'`
minor=`uname -r | awk -F . '{print $2}'`
vi=`systemd-detect-virt`
bit=`uname -m`
if [[ $bit = aarch64 ]]; then
cpu=arm64
elif [[ $bit = x86_64 ]]; then
cpu=amd64
else
red "目前脚本不支持$bit架构" && exit
fi

yumaptcheck(){
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
if [[ ! $(type -P curl) ]]; then
$yumapt update;$yumapt install curl
fi
if [[ ! $(type -P yum) ]]; then
if [[ ! $(type -P cron) ]]; then
$yumapt update;$yumapt install cron
fi
else
$yumapt update;$yumapt install cronie
fi
}

tun(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
cat <<EOF > /root/tun.sh
#!/bin/bash
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
}

close(){
green "开放端口，关闭防火墙"
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
}

v6(){
wgcfv46=$(curl -sm5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
if [[ ! $wgcfv46 =~ on|plus ]]; then
v4=$(curl -s4m6 ip.sb -k)
if [ -z $v4 ]; then
echo -e "nameserver 2001:67c:2960::64\nnameserver 2001:67c:2960::6464" > /etc/resolv.conf
fi
fi
}

baseinstall() {
if [[ $release = Centos ]]; then
if [[ ${vsid} =~ 8 ]]; then
yum clean all && yum makecache
fi
yum install epel-release -y && yum install wget curl tar -y
else
apt update && apt install wget curl tar -y
fi
}

serinstall(){
cd /usr/local/
wget -N --no-check-certificate -O /usr/local/x-ui-linux-${cpu}.tar.gz https://gitlab.com/rwkgyg/x-ui-yg/raw/main/x-ui-linux-${cpu}.tar.gz
tar zxvf x-ui-linux-${cpu}.tar.gz
rm x-ui-linux-${cpu}.tar.gz -f
cd x-ui
chmod +x x-ui bin/xray-linux-${cpu}
cp -f x-ui.service /etc/systemd/system/
mv /root/install.sh /usr/bin/x-ui
chmod +x /usr/bin/x-ui
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui
cd
}

userinstall(){
echo
readp "设置x-ui登录用户名，必须为6位字符以上（回车跳过为随机6位字符）：" username
sleep 1
if [[ -z ${username} ]]; then
username=`date +%s%N |md5sum | cut -c 1-6`
else
if [[ 6 -ge ${#username} ]]; then
until [[ 6 -le ${#username} ]]
do
[[ 6 -ge ${#username} ]] && yellow "\n用户名必须为6位字符以上！请重新输入" && readp "\n设置x-ui登录用户名：" username
done
fi
fi
sleep 1
green "x-ui登录用户名：${username}"
echo -e ""
readp "设置x-ui登录密码，必须为6位字符以上（回车跳过为随机6位字符）：" password
sleep 1
if [[ -z ${password} ]]; then
password=`date +%s%N |md5sum | cut -c 1-6`
else
if [[ 6 -ge ${#password} ]]; then
until [[ 6 -le ${#password} ]]
do
[[ 6 -ge ${#password} ]] && yellow "\n用户名必须为6位字符以上！请重新输入" && readp "\n设置x-ui登录密码：" password
done
fi
fi
sleep 1
/usr/local/x-ui/x-ui setting -username ${username} -password ${password} >/dev/null 2>&1
green "x-ui登录密码：${password}"
}

portinstall(){
echo
readp "设置x-ui登录端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" port
sleep 1
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义x-ui端口:" port
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义x-ui端口:" port
done
fi
sleep 1
/usr/local/x-ui/x-ui setting -port $port >/dev/null 2>&1
green "x-ui登录端口：${port}"
}

resinstall(){
echo "----------------------------------------------------------------------"
restart
echo
xuilogin(){
v4=$(curl -s4m5 ip.sb -k)
v6=$(curl -s6m5 ip.sb -k)
if [[ -z $v4 ]]; then
int="请在浏览器地址栏输入 [$v6]:$port 进入x-ui登录界面\n
x-ui用户名：${username}\n
x-ui密码：${password}\n"
elif [[ -n $v4 && -n $v6 ]]; then
int="请在浏览器地址栏输入 $v4:$port 或者 [$v6]:$port 进入x-ui登录界面\n
x-ui用户名：${username}\n
x-ui密码：${password}\n"
else
int="请在浏览器地址栏输入 $v4:$port 进入x-ui登录界面\n
x-ui用户名：${username}\n
x-ui密码：${password}\n"
fi
}
sleep 3
green "设置定时任务：" && sleep 1
green "1、每天自动更新geoip/geosite文件" && sleep 1
green "2、每分钟执行x-ui监测守护" && sleep 1
green "3、每月1日重启一次x-ui" && sleep 1
xuigo
cronxui
echo "----------------------------------------------------------------------"
yellow "x-ui-yg $remoteV 安装成功，请稍等3秒，输出x-ui登录信息……"
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
xuilogin
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
xuilogin
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
echo
blue "$int"
echo
echo
show_usage
}

xuiinstall(){
tun && yumaptcheck && close && v6
baseinstall
serinstall
blue "以下设置内容建议自定义，防止账号密码及端口被恶意扫描而泄露"
userinstall
portinstall
resinstall
}

update() {
yellow "建议先在/etc/x-ui-yg路径中导出x-ui-yg.db数据文件，做好备份哦"
readp "确定升级，请按回车(退出请按ctrl+c):" ins
if [[ -z $ins ]]; then
systemctl stop x-ui
wget -N https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh
rm /usr/local/x-ui/ -rf
serinstall && sleep 2
restart
green "x-ui更新完成"
else
red "输入有误" && update
fi
}

uninstall() {
yellow "本次卸载将清除所有数据，建议在/etc/x-ui-yg路径中导出x-ui-yg.db数据文件，做好备份哦"
readp "确定卸载，请按回车(退出请按ctrl+c):" ins
if [[ -z $ins ]]; then
systemctl stop x-ui
systemctl disable x-ui
rm /etc/systemd/system/x-ui.service -f
systemctl daemon-reload
systemctl reset-failed
rm /etc/x-ui-yg/ -rf
rm /usr/local/x-ui/ -rf
rm /usr/bin/x-ui -f
uncronxui
green "x-ui已卸载完成"
else
red "输入有误" && uninstall
fi
}

reset_config() {
/usr/local/x-ui/x-ui setting -reset
sleep 1 
portinstall
}

stop() {
systemctl stop x-ui
check_status
if [[ $? == 1 ]]; then
crontab -l > /tmp/crontab.tmp
sed -i '/goxui.sh/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
green "x-ui停止成功"
else
red "x-ui停止失败，请运行 x-ui log 查看日志并反馈" && exit
fi
}

restart() {
systemctl restart x-ui
sleep 2
check_status
if [[ $? == 0 ]]; then
crontab -l > /tmp/crontab.tmp
sed -i '/goxui.sh/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
crontab -l > /tmp/crontab.tmp
echo "* * * * * /usr/local/x-ui/goxui.sh" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
green "x-ui重启成功"
else
red "x-ui重启失败，请运行 x-ui log 查看日志并反馈" && exit
fi
}

show_log() {
journalctl -u x-ui.service -e --no-pager -f
}

acme() {
bash <(curl -L -s https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
if [[ $# == 0 ]]; then
show_menu
fi
}

bbr() {
bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
if [[ $# == 0 ]]; then
show_menu
fi
}

cfwarp() {
wget -N https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh && bash CFwarp.sh
if [[ $# == 0 ]]; then
show_menu
fi
}

status() {
systemctl status x-ui -l
}

xuirestop(){
echo
readp "1. 停止 x-ui \n2. 重启 x-ui \n3. 返回主菜单\n请选择：" action
if [[ $action == "1" ]]; then
stop
elif [[ $action == "2" ]]; then
restart
elif [[ $action == "3" ]]; then
show_menu
else
red "输入错误,请重新选择" && xuirestop
fi
}

xuichange(){
echo
readp "1. 更改 x-ui 用户名与密码 \n2. 更改 x-ui 面板登录端口 \n3. 重置 x-ui 面板设置（面板设置选项中所有设置都装恢复出厂设置，登录端口将重新自定义，账号密码不变）\n4. 返回主菜单\n请选择：" action
if [[ $action == "1" ]]; then
userinstall && restart
elif [[ $action == "2" ]]; then
portinstall && restart
elif [[ $action == "3" ]]; then
reset_config && restart
elif [[ $action == "4" ]]; then
show_menu
else
red "输入错误,请重新选择" && xuichange
fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
return 2
fi
temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ x"${temp}" == x"running" ]]; then
return 0
else
return 1
fi
}

check_enabled() {
temp=$(systemctl is-enabled x-ui)
if [[ x"${temp}" == x"enabled" ]]; then
return 0
else
return 1
fi
}

check_uninstall() {
check_status
if [[ $? != 2 ]]; then
yellow "x-ui已安装，可先选择2卸载，再安装" && sleep 3
if [[ $# == 0 ]]; then
show_menu
fi
return 1
else
return 0
fi
}

check_install() {
check_status
if [[ $? == 2 ]]; then
yellow "未安装x-ui，请先安装x-ui" && sleep 3
if [[ $# == 0 ]]; then
show_menu
fi
return 1
else
return 0
fi
}

show_status() {
check_status
case $? in
0)
white "x-ui状态: \c";blue "已运行"
show_enable_status
;;
1)
white "x-ui状态: \c";yellow "未运行"
show_enable_status
;;
2)
white "x-ui状态: \c";red "未安装"
esac
show_xray_status
}

show_enable_status() {
check_enabled
if [[ $? == 0 ]]; then
white "x-ui自启: \c";blue "是"
else
white "x-ui自启: \c";red "否"
fi
}

check_xray_status() {
count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
if [[ count -ne 0 ]]; then
return 0
else
return 1
fi
}

show_xray_status() {
check_xray_status
if [[ $? == 0 ]]; then
white "xray状态: \c";blue "已启动"
else
white "xray状态: \c";red "未启动"
fi
}

show_usage() {
white "x-ui 快捷命令如下 "
white "------------------------------------------"
white "x-ui              - 显示 x-ui 管理菜单"
white "x-ui status       - 查看 x-ui 状态"
white "x-ui log          - 查看 x-ui 日志"
white "------------------------------------------"
}

xuigo(){
cat>/usr/local/x-ui/goxui.sh<<-\EOF
#!/bin/bash
xui=`ps -aux |grep "x-ui" |grep -v "grep" |wc -l`
xray=`ps -aux |grep "xray" |grep -v "grep" |wc -l`
if [ $xui = 0 ];then
x-ui restart
fi
if [ $xray = 0 ];then
x-ui restart
fi
EOF
chmod +x /usr/local/x-ui/goxui.sh
}

cronxui(){
uncronxui
crontab -l > /tmp/crontab.tmp
echo "0 3 * * * wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O /usr/local/x-ui/bin/geoip.dat" >> /tmp/crontab.tmp
echo "0 3 * * * wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O /usr/local/x-ui/bin/geosite.dat" >> /tmp/crontab.tmp
echo "* * * * * /usr/local/x-ui/goxui.sh" >> /tmp/crontab.tmp
echo "0 1 1 * * x-ui restart" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

uncronxui(){
crontab -l > /tmp/crontab.tmp
sed -i '/geoip.dat/d' /tmp/crontab.tmp
sed -i '/geosite.dat/d' /tmp/crontab.tmp
sed -i '/goxui.sh/d' /tmp/crontab.tmp
sed -i '/x-ui restart/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

show_menu(){
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Github项目  ：github.com/yonggekkk"
white "甬哥blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. 安装 x-ui"
green " 2. 卸载 x-ui"
echo "----------------------------------------------------------------------------------"
green " 3. 更新 x-ui"
green " 4. 停止、重启 x-ui"
green " 5. 变更 x-ui 设置（1.用户名密码 2.登录端口 3.还原面板设置）"
green " 6. 查看 x-ui 运行日志"
echo "----------------------------------------------------------------------------------"
green " 7. ACME证书管理菜单"
green " 8. 安装BBR+FQ加速"
green " 9. 安装WARP脚本"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [[ -f /etc/x-ui-yg/x-ui-yg.db ]]; then
echo -e "提示：备份文件路径：${bblue}/etc/x-ui-yg/x-ui-yg.db${plain}\n"
fi
if [ "${xuiygV}" = "${remoteV}" ]; then
echo -e "当前 x-ui-yg 脚本版本号：${bblue}${xuiygV}${plain} 已是最新版本\n"
else
echo -e "当前 x-ui-yg 脚本版本号：${bblue}${xuiygV}${plain}"
echo -e "检测到最新 x-ui-yg 脚本版本号：${yellow}${remoteV}${plain}"
echo -e "${yellow}$(wget -qO- https://gitlab.com/rwkgyg/x-ui-yg/raw/main/version)${plain}"
echo -e "可选择3进行更新\n"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white "VPS系统信息如下："
white "操作系统:   $(blue "$op")" && white "内核版本:   $(blue "$version")" && white "CPU架构 :   $(blue "$cpu")" && white "虚拟化类型: $(blue "$vi")"
echo "------------------------------------------"
show_status
wgcfv46=$(curl -sm5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
if [[ ! $wgcfv46 =~ on|plus ]]; then
wgcf=未启用
else
wgcf=启用中
fi
white "WARP状态：\c" && blue $wgcf
echo "------------------------------------------"
acp=$(/usr/local/x-ui/x-ui setting -show 2>/dev/null)
if [[ -n $acp ]]; then
white "x-ui登录信息如下：" && blue "$acp" 
else
white "x-ui登录信息如下：" && red "未安装x-ui，无显示"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp " 请输入数字:" Input
case "$Input" in     
 1 ) check_uninstall && xuiinstall;;
 2 ) check_install && uninstall;;
 3 ) check_install && update;;
 4 ) check_install && xuirestop;;
 5 ) check_install && xuichange;;
 6 ) check_install && show_log;;
 7 ) acme;;
 8 ) bbr;;
 9 ) cfwarp;;
 * ) exit 
esac
}

if [[ $# > 0 ]]; then
case $1 in
"status") check_install 0 && status 0
;;
"log") check_install 0 && show_log 0
;;
*) show_usage
esac
else
show_menu
fi
