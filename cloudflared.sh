#!/bin/sh
##################################################################
## 本启动脚本上传至/etc/storage/文件夹里 并赋予执行权限chmod +x   ##
## 运行的CF程序文件放在U盘里 /media/u盘名/cloudflared/文件夹里    ##
## 如果没有u盘是下载到内存/tmp/cloudflared/文件夹里               ##
## 带进程守护开机自启                                            ##
##  /etc/storage/cloudflared.sh stop     停止运行               ##
##  /etc/storage/cloudflared.sh restart  重新启动               ##
##################################################################

#######下面填写自己 CF隧道令牌token值 #######

token="eyJhIjoiYjZkMTFhYWRjZmY2MWNmNDJjNzNmOTkyNzk5Y2ViNzMiLCJ0Ijoi.........................."

upanPath="`df -m | grep /dev/mmcb | grep -E "$(echo $(/usr/bin/find /dev/ -name 'mmcb*') | sed -e 's@/dev/ /dev/@/dev/@g' | sed -e 's@ @|@g')" | grep "/media" | awk '{print $NF}' | sort -u | awk 'NR==1' `"
[ -z "$upanPath" ] && upanPath="`df -m | grep /dev/sd | grep -E "$(echo $(/usr/bin/find /dev/ -name 'sd*') | sed -e 's@/dev/ /dev/@/dev/@g' | sed -e 's@ @|@g')" | grep "/media" | awk '{print $NF}' | sort -u | awk 'NR==1' `"
if [ -z "$upanPath" ] ; then
cloudflared=/tmp/cloudflared/cloudflared
[ ! -d /tmp/cloudflared ] && mkdir -p /tmp/cloudflared
else
cloudflared="$upanPath/cloudflared/cloudflared"
[ ! -d "$upanPath/cloudflared" ] && mkdir -p $upanPath/cloudflared
fi
if [ -s /etc_ro/script.tgz ] ; then
source /etc/storage/script/init.sh
if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep cloudflared)" ]  && [ ! -s /tmp/script/_cloudflared ]; then
        mkdir -p /tmp/script
        { echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_cloudflared
        chmod 777 /tmp/script/_cloudflared
fi
fi
D="/etc/storage/cron/crontabs"
F="$D/`nvram get http_username`"

cf_keep () {
logger -t "【cloudflared】" "守护进程启动"
if [ -s /etc_ro/script.tgz ] ; then 
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【cloudflared】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
        [ -z "\`pidof cloudflared\`" ]  && logger -t "【cloudflared】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【cloudflared】|^$/d' /tmp/script/_opt_script_check # 【cloudflared】
OSC
sed -Ei '/cloudflared开机自启|^$/d' /etc/storage/started_script.sh
cat >> "/etc/storage/started_script.sh" <<-OSC

/etc/storage/cloudflared.sh start & #cloudflared开机自启

OSC
fi
else
sed -Ei '/cloudflared守护进程|^$/d' "$F"
cat >> "$F" <<-OSC
*/1 * * * * test -z "\`pidof cloudflared\`"  && /etc/storage/cloudflared.sh restart #cloudflared守护进程
OSC
fi
}

cf_start () {
if [ -s /etc_ro/script.tgz ] ; then 
sed -Ei '/【cloudflared】|^$/d' /tmp/script/_opt_script_check
else
  sed -Ei '/cloudflared守护进程|^$/d' "$F"
fi
killall cloudflared
killall -9 cloudflared
Available_A="$(df -m | grep "% /tmp" | awk 'NR==1' | awk '{print $4}'| tr -d 'M' | cut -f1 -d".")"
Available_B=$(df -m | grep "% /tmp" | awk 'NR==1' | awk -F' ' '{print $2}'| tr -d 'M' | tr -d '' | cut -f1 -d".")
Available_B=`expr $Available_B + 20`
if [ "$Available_A" -lt 15 ];then
   logger -t "【cloudflared】" "未挂载储存设备，当前/tmp分区$Available_A M较小，临时增加tmp分区容量为$Available_B M"
   mount -t tmpfs -o remount,rw,size="$Available_B"M tmpfs /tmp
   Available_A=$(df -m | grep "% /tmp" | awk 'NR==1' | awk -F' ' '{print $4}')
   echo $Available_A
   Available_A="$(echo "$Available_A" | tr -d 'M' | tr -d '')"
fi
[ ! -d /etc/init.d ] && mkdir -p /etc/init.d
[ ! -f /etc/storage/cloudflared/lib/cloudflared ] && touch /etc/storage/cloudflared/lib/cloudflared
rm -rf /etc/init.d/cloudflared && ln -sf /etc/storage/cloudflared/lib/cloudflared /etc/init.d/cloudflared
if [ ! -s "$cloudflared" ] ; then
   [ ! -d /tmp/cloudflared ] && mkdir -p /tmp/cloudflared
   rm -rf /tmp/var/cfMD5.txt
   logger -t "【cloudflared】" "未找到$cloudflared ,开始下载"
   curl -# -L -k -S -o  /tmp/var/cfMD5.txt --connect-timeout 10 --retry 3 https://github.com/dearxjoe/cloudflared_mipsle_mips/releases/download/2025.10.0/MD5_cloudflared-linux-mipsle.txt
   [ -s /tmp/var/cfMD5.txt ] && curl -# -L -k -S -o  "$cloudflared" --connect-timeout 10 --retry 3 "https://github.com/dearxjoe/cloudflared_mipsle_mips/releases/download/2025.10.0/cloudflared-linux-mipsle"
   [ ! -s /tmp/var/cfMD5.txt ] && rm -rf "$cloudflared" && cf_dl
   if [ -s "$cloudflared" ] && [ -s /tmp/var/cfMD5.txt ] ; then
       chmod 777 "$cloudflared"
       cfmd5="$(cat /tmp/var/cfMD5.txt)"
       echo "$cfmd5"
       eval $(md5sum "$cloudflared" | awk '{print "MD5_down="$1;}') && echo "$MD5_down"
       if [ "$cfmd5"x = "$MD5_down"x ] ; then
            logger -t "【cloudflared】" "程序下载完成，MD5匹配，开始安装至$cloudflared "
       else
            tar -xzvf /tmp/cloudflared/cloudflared.tar.gz -C /tmp/cloudflared
            [ ! -s "$cloudflared" ] && logger -t "【cloudflared】" "程序下载完成，MD5不匹配，删除..."
            rm -rf "$cloudflared" /tmp/var/cfMD5.txt
       fi
   else
       rm -rf "$cloudflared" && logger -t "【cloudflared】" "下载程序不完整，删除重新下载"
   fi
   [ ! -f "$cloudflared" ] && cf_dl
fi
chmod 777 "$cloudflared"
ver=$($cloudflared -v | awk '{print $3}' | tr -d ' ')
[[ "$($cloudflared -h 2>&1 | wc -l)" -lt 2 ]] && logger -t "【cloudflared】" "程序不完整，删除..." && rm -rf "$cloudflared" && cf_dl
cmd="$cloudflared --no-autoupdate tunnel run --token $token"
logger -t "【cloudflared】" "cloudflared_$ver 准备启动"
eval "$cmd" &
sleep 10
[ ! -z "`pidof cloudflared`" ] && logger -t "【cloudflared】" "cloudflared_$ver 启动成功" && logger -t "【cloudflared】" "添加配置请前往 https://one.dash.cloudflare.com/access/tunnels "
[ -z "`pidof cloudflared`" ] && logger -t "【cloudflared】" "cloudflared启动失败,20 秒后自动尝试重新启动" && cf_dl
cf_keep
exit 0
}

cf_dl () {
sleep 20
cf_start
}


cf_close () {
if [ -s /etc_ro/script.tgz ] ; then 
sed -Ei '/【cloudflared】|^$/d' /tmp/script/_opt_script_check
sed -Ei '/cloudflared开机自启|^$/d' /etc/storage/started_script.sh
else
  sed -Ei '/cloudflared守护进程|^$/d' "$F"
fi
  killall cloudflared
  killall -9 cloudflared
  sleep 8
  [ -z "`pidof cloudflared`" ] && logger -t "【cloudflared】" "已关闭!"
}

cf_restart () {
  logger -t "【cloudflared】" "重新启动"
  cf_close
  cf_start
}

case $1 in
start)
        cf_start
        ;;
restart)
        cf_restart
        ;;
stop)
        cf_close
        ;;
*)
        cf_restart
        ;;
esac
