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
  sudo echo net.ipv4.ip_forward=1 | sudo tee /etc/sysctl.conf > /dev/null
  sudo sysctl -p
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
  sudo iptables -t mangle -A clash -d 127.0.0.0/8 -j RETURN
  sudo iptables -t mangle -A clash -d 169.254.0.0/16 -j RETURN
  sudo iptables -t mangle -A clash -d 172.16.0.0/12 -j RETURN
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

  cat >$2 <<EOL
tproxy-port: 7893
socks-port: 7891
allow-lan: true
mode: Rule
log-level: info
external-controller: :9090

proxies:
EOL

cat $1 | grep "\- {" >>$2

cat >$2 <<EOL
  - name: 🐟 全局
    type: select
    proxies:
EOL

cat $1 | grep "\- {" | awk -F":" '{print $2}' | cut -d "," -f1 >>$2

  cat >$2 <<EOL
rules:
  - MATCH, 🐟 全局

EOL

  unset LIST

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

echo -e "测试网络连通性"
STATUS=$(curl -s -i https://connect.rom.miui.com/generate_204 | grep 204)
if [[ -z ${STATUS} ]]; then
	echo -e "网络连通测试失败"
fi
curl -s -i https://connect.rom.miui.com/generate_204 | grep 204
echo -e "${STATUS}"
tail ${CLASH_LOG}

