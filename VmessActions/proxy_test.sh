GITHUB='https://github.com'
OS='linux-amd64'
USER='Dreamacro'
APP='clash'
REPO=$USER/$APP
FILE=$APP.gz
CLASH_CONFIG=VmessActions/subscribe/clash_cn.yaml
FINAL_CONFIG=clash_cn_final.yaml
CLASH_PID='clash.pid'
CLASH_LOG='clash.log'

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}
VERSION=$(get_latest_release $REPO)

ip_foward() {
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && sysctl -p
	echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf && sysctl -p
	
	echo "当前ip_forward $(cat /proc/sys/net/ipv4/ip_forward)"
}

firwall_set() {
  # ROUTE RULES
  sudo ip rule add fwmark 1 table 100
  sudo ip route add local 0.0.0.0/0 dev lo table 100

  # CREATE TABLE
  sudo iptables -t mangle -N clash

  # RETURN LOCAL AND LANS
  sudo iptables -t mangle -A clash -d 0.0.0.0/8 -j RETURN
  sudo iptables -t mangle -A clash -d 10.0.0.0/8 -j RETURN
  sudo iptables -t mangle -A clash -d 10.1.0.0/16 -j RETURN
  sudo iptables -t mangle -A clash -d 127.0.0.0/8 -j RETURN
  sudo iptables -t mangle -A clash -d 169.254.0.0/16 -j RETURN
  sudo iptables -t mangle -A clash -d 172.16.0.0/12 -j RETURN
  sudo iptables -t mangle -A clash -d 172.17.0.0/24 -j RETURN  
  sudo iptables -t mangle -A clash -d 192.168.50.0/16 -j RETURN
  sudo iptables -t mangle -A clash -d 192.168.9.0/16 -j RETURN
  
  sudo iptables -t mangle -A clash -d 224.0.0.0/4 -j RETURN
  sudo iptables -t mangle -A clash -d 240.0.0.0/4 -j RETURN

  # FORWARD ALL
  sudo iptables -t mangle -A clash -p udp -j TPROXY --on-port 7893 --tproxy-mark 1
  sudo iptables -t mangle -A clash -p tcp -j TPROXY --on-port 7893 --tproxy-mark 1

  # REDIRECT
  sudo iptables -t mangle -A PREROUTING -j clash
 
}

get_config() {
	cat $1 | sed '/全球直连/d' > $2
	sed -i '1 i\tproxy-port: 7893' $2
	sed -i "/mode:/c\mode: Global" $2
	
	curl -s -L https://raw.githubusercontent.com/wp-statistics/GeoLite2-Country/master/GeoLite2-Country.mmdb.gz -o mmdb.gz
	gzip -d mmdb.gz
	mv mmdb Country.mmdb
}


get_clash() {
 
	CLASH=`pwd`/VmessActions/clash
	if [ -e ${CLASH} ]; then
		echo ${CLASH} 已经存在
		unset CLASH
		return
	fi

        curl -L -s ${GITHUB}/${USER}/${APP}/releases/download/${VERSION}/${APP}-${OS}-${VERSION}.gz -o ${FILE}
        gzip -d ${FILE}
	chmod 755 clash
  echo ${CLASH} 部署成功
  
	unset CLASH
}

clash_help() {
	echo "how to manage clash:"
	echo "clash start config pid"
	echo "clash restart config pid"
	echo "clash stop config pid"
}

clash() {
	LOG=${CLASH_LOG}
	#CLASH=$(get_clash)
	CLASH='./VmessActions/clash'
	
	sudo setcap cap_net_bind_service,cap_net_admin+ep ${CLASH}
	
	if [[ $1 == 'start' && -n $2 && -n $3 ]]; then
		nohup ${CLASH} -f $2 > ${LOG} 2>&1 &
		echo "$!" > $3
	elif [[ $1 == 'stop' && -n $2 && -n $3 ]]; then
		kill `cat $3`
	elif [[ $1 == 'restart' && -n $2 && -n $3 ]]; then
		kill `cat $3`
		nohup ${CLASH} -f $2 > ${LOG} 2>&1 &
		echo "$!" > $3
	else
		clash_help
	fi

	unset CONFIG
	unset PID
	unset LOG
	unset CLASH
}


echo -e "本地流量转发"
ip_foward

echo -e "iptables防火墙配置"
firwall_set

echo -e "部署clash环境"
get_clash

echo -e "获取clash配置文件"
if [ ! -e ${CLASH_CONFIG} ]; then
  echo "配置文件不存在"
  exit 0
fi

get_config ${CLASH_CONFIG} ${FINAL_CONFIG}

echo -e "启动CLASH"
clash start ${FINAL_CONFIG} ${CLASH_PID}

sleep 3

i=0
while [[ $[i] -lt 5 ]]
do
	echo -e "测试网络连通性 ($[i])"
	STATUS=$(curl -s -i https://connect.rom.miui.com/generate_204 | grep 204)
	if [[ -z ${STATUS} ]]; then
		echo -e "网络连通测试失败"
	fi

	IP=$(curl -s -L https://api.ipify.org)
	COUNTRY=$(curl -s -L https://ipapi.co/${IP}/country/)
	CITY=$(curl -s -L https://ipapi.co/${IP}/city/)

	echo -e "公网IP信息： ${IP} ${CITY}, ${COUNTRY}"
	echo -e "网卡信息"
	ifconfig

	echo -e "${STATUS}"
	cat ${CLASH_LOG}
	sleep 3
	let i++
done



