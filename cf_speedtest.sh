#!/bin/sh

# 一般配置常量， 可按需更改
PING_COUNT=100						#丢包率和延迟率测试时单个ping检测次数, 缺省100次，次数越高准确度越高但是耗时越长。建议调整为20-100
TARGET_IPS=20						#目标IP数:缺省20
EXPECT_BANDWIDTH=20					#期望的最小带宽(单位)缺省20M
ALGORITHM=1						#算法：1. 直接从cloudflare官网全IP库中拉取IP池； 2. 从udpfile.com过滤过的IP库中拉取IP池
POOL_COMBINE=yes					#是否启用与现有生效的代理池订阅进行合并(yes/no)，启用后注意各代理节点命名不能有重复，否则本地转换时会出错
SAMPLE_IPS=1000						#每次测试用到的IP池大小,可根据设备性能和网络情况调整，一般无需更改
SPEED_THREAD_NUMBER=5					#带宽测速度的线程数,缺省5，加大线程数可加快测试速度。可根据实际物理带宽和EXPECT_BANDWIDTH期望带宽做调整
							#如果物理带宽是200M，期望带宽是20M最大值可以调为5=200/20
STATUS_THREAD_NUMBER=100				#进行丢包率和节点有效性检测的线程数，缺省100，可按实际性能做调整，一般不需要改
SCHEDULE="30 */6 * * *"					#计划任务 (由于crontab版本不同，各个平台计划任务的格式可能会稍有差异，按实际情况填写)
GHPROXY='https://ghproxy.com/'				#github代理网址,直接访问gihub有问题的可以用这个
PREF_INI_URL="${GHPROXY}https://gist.githubusercontent.com/hansyao/e00678003f4eea63b219217638582414/raw/cloudflare.ini"	#远程规则文件,可按需替换
TEMP_DIR='/tmp/mytemp'					#临时文件路径(无需更改)
PREF_INI="${TEMP_DIR}/cloudflare.ini"			#本地规则文件，如PREF_INI_URL未定义，则抓取PREF_INI本地规则
POOL="${TEMP_DIR}/main_cloudflare.yaml"			#脚本自动生成的转换规则前的代理池文件路径
CLASH_CONFIG="${TEMP_DIR}/clash_cloudflare_final.yaml"	#脚本自动规则转换后的的代理池文件路径
WWW_PATH='/var/www/html/'				#VPS服务器上的web路径，如需要外网访问需要将其路径填写在这里
CLASH_ENABLE=yes					#是否应用clash(yes/no), 填no不进行规则转换, opewrt填no同时不应用到配置文件
PASSWALL_ENABLE=yes					#是否应用passwall(yes/no), openwrt适用，填no不用passwall
SPEED_TEST=yes						#是否启用带宽测速(yes/no)
PACK_LOSS_TEST=no					#是否启用丢包率测试(yes/no), 注意丢包率高的未必测速带宽低，具体按实际情况调整
CONVERTER_ENABLE=yes					#是否进行规则转换并生成自己的私有订阅链接方便应用到其他代理客户端(必须先开启gist)
GIST_TOKEN=						#授予gist权限的github密钥，如不上传留空即可
REMOTE_NAME='cloudflare'				#上传到gist上的文件名,按需更改
RULE_PATH_OPENCLASH=/etc/openclash/config		#OpenClash配置文件路径(OpenClash缺省，一般无需更改)
RULE_PATH_MERLINCLASH=/koolshare/merlinclash/yaml_bak	#梅林路由器clash文件配置文件路径(Merlin koolshare Clash缺省，一般无需更改)
RULE_PATH_OTHERS=${WWW_PATH}				#其他服务器clash文件配置文件路径(按需更改为自己的配置文件所在路径)
POOL_COMBINED_CONF="${TEMP_DIR}/pool_combined.yaml"	#代理池合并后的文件路径(无需更改)


# 不同客户端规则转换(yes/no， 必须开启gist)
CONVERT_clash=no
CONVERT_clashr=no
CONVERT_quan=no
CONVERT_quanx=no
CONVERT_loon=no
CONVERT_mellow=no
CONVERT_surfboard=no
CONVERT_surge2=no
CONVERT_surge3=no
CONVERT_surge4=yes
CONVERT_v2ray=no
CONVERT_mixed=no

# 上传Github gist用到的全局变量, 以下变量都由脚本自动生成无需更改
DESC_JSON="${TEMP_DIR}/gist.json"
RESPONSE="${TEMP_DIR}/gist_response.json"
GIST_ID_main=
GIST_ID_clash=
GIST_ID_clashr=
GIST_ID_quan=
GIST_ID_quanx=
GIST_ID_loon=
GIST_ID_mellow=
GIST_ID_surfboard=
GIST_ID_surge2=
GIST_ID_surge3=
GIST_ID_surge4=
GIST_ID_v2ray=
GIST_ID_mixed=

# 代理池，改称自己的，如有多个代理每个配置一行按照格式填写即可（注：命名规则: VPS1_美国_CF加速 >>>CF加速字样和分组规则相对应，'vp1'为你的vps名称, '美国'为其他关键字，括号内的'${ID}'不要改）
function pool_generate() {
	local SERVER=$1
	local ID=$2

	echo -e  "  - {name: VPS1_美国_CF加速(${ID}), server: ${SERVER}, port: 443, type: vmess, uuid: xxxx-xxxx-xxxx-xxxx-0000xxxx, alterId: 0, cipher: auto, tls: true, skip-cert-verify: false, network: ws, ws-path: /PrVbmadf, ws-headers: {Host: your.cloudflare.workers.dev}}"
}


urlencode() {
   local data
   if [ "$#" -eq 1 ]; then
      data=$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$1" "")
      if [ ! -z "$data" ]; then
         echo "$(echo ${data##/?} |sed 's/\//%2f/g' |sed 's/:/%3a/g' |sed 's/?/%3f/g' \
		|sed 's/(/%28/g' |sed 's/)/%29/g' |sed 's/\^/%5e/g' |sed 's/=/%3d/g' \
		|sed 's/|/%7c/g' |sed 's/+/%20/g')"
      fi
   fi
}

parse_json_simple(){
	local JSON=$1
	local KEY=$2
	local VALUE=$(echo "$1" | sed 's/.*"'${KEY}'":\([^,}]*\).*/\1/')
	echo "${VALUE}" | sed 's/\"//g'
}

function openwrt_env() {
	local RE1=0
	local RE2=0
	which uci
	if [[ $? -ne 0 ]]; then
		echo -e "未找到uci工具， 开始安装源依赖"
		opkg install ca-certificates wget
		opkg update
		opkg install uci
		if [[ $? -gt 0 ]]; then
			echo "uci安装失败, 请手工安装后继续！"
			local RE1=1
		fi
	fi

	which shuf
	if [[ $? -ne 0 ]]; then
		opkg install coreutils-shuf
		opkg install ca-certificates wget
		opkg update
		opkg install coreutils-shuf
		if [[ $? -gt 0 ]]; then
			echo "shuf安装失败, 请手工安装后继续！"
			local RE2=1
		fi
	fi

	if [[ ${RE1} -eq 0 && ${RE1} -eq 0 ]]; then
		return 0
	else
		return 1
	fi
}

function passwall_config() {
	local POOL=$1

	echo -e "删除现有UUID重复的配置"
	local UUID_LIST=$(cat "${POOL}" | sed "1d" | awk -F "uuid:" '{print $2}' | awk -F "," '{print $1}' \
		| sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g' | sort | uniq)
	local CURRENT_NODES=$(uci show passwall | grep uuid=)
	echo -e "${CURRENT_NODES}" | while read LINE && [[ -n "${LINE}" ]]
	do
		local NODE_ID=$(echo -e ${LINE} | cut -d "." -f2)
		local UUID=$(echo -e ${LINE} | cut -d "'" -f2)
		if [[ -n "$(echo -e "${UUID_LIST}" | grep "${UUID}")" ]]; then
			uci delete passwall.${NODE_ID}
		fi
	done
	uci commit passwall
	unset LINE

	echo -e "清空负载均衡节点配置"
	local PROXY_LIST_NUM=$(uci show passwall | grep haproxy_config | tail -n 1| sed "s/^.*\[//g"| sed "s/\].*//g")
	while [[ ${PROXY_LIST_NUM} -ge 0 ]]
	do
		uci delete passwall.@haproxy_config[${PROXY_LIST_NUM}]
		local PROXY_LIST_NUM=$((PROXY_LIST_NUM -1))
	done
	uci commit passwall

	echo -e "清空负载均衡中继节点配置"
	uci show passwall | grep 127.0.0.1 | cut -d "." -f1,2 | while read LINE && [[ -n "${LINE}" ]]
	do
		uci delete "${LINE}"
	done
	uci commit passwall
	unset LINE

	echo -e "清空负载均衡全局配置"
	local HAPROXY_GLOBAL_NUM=$(uci show passwall | grep global_haproxy | tail -n 1| sed "s/^.*\[//g"| sed "s/\].*//g")
	while [[ ${HAPROXY_GLOBAL_NUM} -ge 0 ]]
	do
		uci delete passwall.@global_haproxy[${PROXY_LIST_NUM}]
		local HAPROXY_GLOBAL_NUM=$((HAPROXY_GLOBAL_NUM -1))
	done
	uci commit passwall

	echo -e "创建haproxy负载均衡中继节点"
	local PORT=1181
	echo -e "$(pool_generate)" | while read LINE && [[ -n "${LINE}" ]]
	do
		local LINE=$(echo -e "${LINE}" | sed "s/.*name/name/g" | sed "s/}$//g" | sed "s/{/,/g" \
					| sed "s/}$//g" | sed "s/,/\\n/g" | sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g')
		local SERVER_NAME=$(echo -e "${LINE}" | grep -i name: | awk '{print $2}' | sed "s/()//g")
		local NODE_ID=$(cat /proc/sys/kernel/random/uuid  | md5sum |cut -c 1-32)

		local PROTOCOL=$(echo -e "${LINE}" | grep type: | awk '{print $2}')
		if [[ "${PROTOCOL}" == 'vmess' ]]; then
			local TYPE='V2ray'
		elif [[ "${PROTOCOL}" == 'vless' ]]; then
			local TYPE='V2ray'
		elif [[ "${PROTOCOL}" == 'ss' ]]; then
			local TYPE='Shadowsocks'
		elif [[ "${PROTOCOL}" == 'ssr' ]]; then
			local TYPE='ShadowsocksR'
		elif [[ "${PROTOCOL}" == 'trojan' ]]; then
			local TYPE='Trojan-Plus'
		else
			echo -e "不支持的协议"
			continue
		fi

		uci set passwall.${NODE_ID}=nodes
		uci set passwall.${NODE_ID}.add_mode="CF自动测速"
		uci set passwall.${NODE_ID}.remarks="负载均衡 ${SERVER_NAME}"
		uci set passwall.${NODE_ID}.type="${TYPE}"
		uci set passwall.${NODE_ID}.protocol="${PROTOCOL}"
		uci set passwall.${NODE_ID}.port="${PORT}"
		uci set passwall.${NODE_ID}.encryption=none
		uci set passwall.${NODE_ID}.uuid=$(echo -e "${LINE}" | grep -i uuid: | awk '{print $2}')
		uci set passwall.${NODE_ID}.level=1
		uci set passwall.${NODE_ID}.cipher=$(echo -e "${LINE}" | grep -i cipher: | awk '{print $2}')
		uci set passwall.${NODE_ID}.alter_id=$(echo -e "${LINE}" | grep -i alterId: | awk '{print $2}')
		uci set passwall.${NODE_ID}.stream_security=tls
		uci set passwall.${NODE_ID}.tls_serverName=$(echo -e "${LINE}" | grep -i Host: | awk '{print $2}')
		uci set passwall.${NODE_ID}.transport=$(echo -e "${LINE}" | grep -i network: | awk '{print $2}')
		uci set passwall.${NODE_ID}.ws_host=$(echo -e "${LINE}" | grep -i Host: | awk '{print $2}')
		uci set passwall.${NODE_ID}.tls_serverName=$(echo -e "${LINE}" | grep -i Host: | awk '{print $2}')
		uci set passwall.${NODE_ID}.tls_allowInsecure=1
		uci set passwall.${NODE_ID}.security=$(echo -e "${LINE}" | grep -i cipher: | awk '{print $2}')
		uci set passwall.${NODE_ID}.is_sub=0
		uci set passwall.${NODE_ID}.password=$(echo -e "${LINE}" | grep -i password: | awk '{print $2}')
		uci set passwall.${NODE_ID}.ws_path=$(echo -e "${LINE}" | grep -i ws-path: | awk '{print $2}')
		uci set passwall.${NODE_ID}.mux=1
		uci set passwall.${NODE_ID}.mux_concurrency=8
		uci set passwall.${NODE_ID}.address=127.0.0.1

		echo -e "$SERVER_NAME"	"${PORT}"
		echo -e "$SERVER_NAME\`${PORT}" >>"${TEMP_DIR}/main_server.txt"

		local PORT=$(( ${PORT} + 1))
	done
	unset LINE

	echo -e "写入haproxy负载均衡全局设置"
	local HAPROXY_GLOBAL_NODE=$(uci add passwall global_haproxy)
	uci set passwall."${HAPROXY_GLOBAL_NODE}".balancing_enable=1
	uci set passwall."${HAPROXY_GLOBAL_NODE}".console_port=1199
	uci commit passwall
	
	echo -e "开始写入passwall配置"
	local i=1
	cat "${POOL}" | sed "1d" | while read PROXY && [[ -n "${PROXY}" ]]
	do
		local NODE_ID=$(cat /proc/sys/kernel/random/uuid  | md5sum |cut -c 1-32)
		local PROXY=$(echo -e "${PROXY}" | sed "s/.*name/name/g" | sed "s/}$//g" | sed "s/{/,/g" \
			| sed "s/}$//g" | sed "s/,/\\n/g" | sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g')
		local SERVER_NAME=$(echo -e "${PROXY}" | grep -i name: | awk '{print $2}')
		local SERVER_IP=$(echo -e "${PROXY}" | grep -i server: | awk '{print $2}')
		local PORT=$(echo -e "${PROXY}" | grep -i port: | awk '{print $2}')

		local PROTOCOL=$(echo -e "${PROXY}" | grep type: | awk '{print $2}')
		if [[ "${PROTOCOL}" == 'vmess' ]]; then
			local TYPE='V2ray'
		elif [[ "${PROTOCOL}" == 'vless' ]]; then
			local TYPE='V2ray'
		elif [[ "${PROTOCOL}" == 'ss' ]]; then
			local TYPE='Shadowsocks'
		elif [[ "${PROTOCOL}" == 'ssr' ]]; then
			local TYPE='ShadowsocksR'
		elif [[ "${PROTOCOL}" == 'trojan' ]]; then
			local TYPE='Trojan-Plus'
		else
			echo -e "不支持的协议"
			continue
		fi

		echo -e "添加节点 ${SERVER_IP}:${PORT} 并加入haproxy负载均衡"
		uci set passwall.${NODE_ID}=nodes
		uci set passwall.${NODE_ID}.add_mode="CF自动测速"
		uci set passwall.${NODE_ID}.remarks="${SERVER_NAME}"
		uci set passwall.${NODE_ID}.type="${TYPE}"
		uci set passwall.${NODE_ID}.protocol="${PROTOCOL}"
		uci set passwall.${NODE_ID}.port="${PORT}"
		uci set passwall.${NODE_ID}.encryption=none
		uci set passwall.${NODE_ID}.uuid=$(echo -e "${PROXY}" | grep -i uuid: | awk '{print $2}')
		uci set passwall.${NODE_ID}.level=1
		uci set passwall.${NODE_ID}.cipher=$(echo -e "${PROXY}" | grep -i cipher: | awk '{print $2}')
		uci set passwall.${NODE_ID}.alter_id=$(echo -e "${PROXY}" | grep -i alterId: | awk '{print $2}')
		uci set passwall.${NODE_ID}.stream_security=tls
		uci set passwall.${NODE_ID}.tls_serverName=$(echo -e "${PROXY}" | grep -i Host: | awk '{print $2}')
		uci set passwall.${NODE_ID}.transport=$(echo -e "${PROXY}" | grep -i network: | awk '{print $2}')
		uci set passwall.${NODE_ID}.ws_host=$(echo -e "${PROXY}" | grep -i Host: | awk '{print $2}')
		uci set passwall.${NODE_ID}.tls_serverName=$(echo -e "${PROXY}" | grep -i Host: | awk '{print $2}')
		uci set passwall.${NODE_ID}.tls_allowInsecure=1
		uci set passwall.${NODE_ID}.security=$(echo -e "${PROXY}" | grep -i cipher: | awk '{print $2}')
		uci set passwall.${NODE_ID}.is_sub=0
		uci set passwall.${NODE_ID}.password=$(echo -e "${PROXY}" | grep -i password: | awk '{print $2}')
		uci set passwall.${NODE_ID}.ws_path=$(echo -e "${PROXY}" | grep -i ws-path: | awk '{print $2}')
		uci set passwall.${NODE_ID}.mux=1
		uci set passwall.${NODE_ID}.mux_concurrency=8
		uci set passwall.${NODE_ID}.address="${SERVER_IP}"

		local SERVER_NAME=$(echo -e "${SERVER_NAME}" | sed "s/(.*$//g")
		local HAPROXY_PORT=$(cat "${TEMP_DIR}/main_server.txt" | grep -E "^${SERVER_NAME}\`" | awk -F '`' '{print $2}')
		local HAPROXY_NODE=$(uci add passwall haproxy_config)
		if [[ ${i} -le 6 ]]; then 
			local LBWEIGHT=20
			local BACKUP=0
		else
			local LBWEIGHT=5
			local BACKUP=1
		fi
		uci set passwall.${HAPROXY_NODE}.enabled=1
		uci set passwall.${HAPROXY_NODE}.lbort=${PORT}
		uci set passwall.${HAPROXY_NODE}.haproxy_port=${HAPROXY_PORT}
		uci set passwall.${HAPROXY_NODE}.lbweight=${LBWEIGHT}
		uci set passwall.${HAPROXY_NODE}.export=1
		uci set passwall.${HAPROXY_NODE}.backup=${BACKUP}
		uci set passwall.${HAPROXY_NODE}.lbss="${SERVER_IP}:${PORT}"

		let i++
	done
	uci commit passwall
	rm -f "${TEMP_DIR}/main_server.txt"
	unset i
}

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

function dec2bin() {
	local num=$1

	local rem=1
	local bno=" "
	while [[ ${num} -gt 0 ]]
	do
		local rem=$(( $num % 2 ))
		local bno=$bno$rem
		local num=$(( $num / 2 ))
	done

	local i=${#bno}
	local final=" "
	while [[ $i -gt 0 ]]
	do
		local rev=`echo $bno | awk '{ printf substr( $0,'$i',1 ) }'`
		local final=$final$rev
		local i=$(( $i - 1 ))
	done
	echo "$final" | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'
}

function bin2dec() {
	bino=$1

	local len=${#bino}
	local i=1
	local pow=$((len - 1 ))
	while [ $i -le $len ]
	do
		local n=`echo $bino | awk '{ printf substr( $0,'$i',1 )}' `
		local j=1
		local p=1

		while [ $j -le $pow ]
		do
			p=$(( p * 2 ))
			j=$(( j + 1 ))
		done

		local dec=$(( n * p ))
		local findec=$(( findec + dec ))
		local pow=$((pow - 1 ))
		local i=$(( i + 1 ))
	done
	echo "$findec" | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'
}


function reverse_chars() {
	awk '{ for (i=length($0);i>0;i--) {printf substr($0,i,1)}; printf"\n"}'
}

function bit_calc() {
	local a=$(echo -e "$1" | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
	local OPT=$2
	local b=$(echo -e "$3" | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
	local output=$4

	echo -e "${a}" >${TEMP_DIR}/a.txt
	echo -e "${b}" >${TEMP_DIR}/b.txt

	local max_len=$(( ${#a}> ${#b} ? ${#a} :${#b} ))
	local a1
	while read -n 1 char && [[ -n "${char}" ]]
	do
		local a1="${char}\\n${a1}"
		let i++
	done <${TEMP_DIR}/a.txt
	a=$(echo -e "${a1}" | grep -v "^$")
	# echo -e "${a}"

	local b1
	while read -n 1 char && [[ -n "${char}" ]]
	do
		b1="${char}\\n${b1}"
		let i++
	done <${TEMP_DIR}/b.txt
	b=$(echo -e "${b1}" |  grep -v "^$")
	# echo -e "${b}"
	
	local i=1
	local final
	while [[ ${i} -le ${max_len} ]]
	do
		a1=$(echo -e "${a}" | sed -n "${i}p")
		b1=$(echo -e "${b}" | sed -n "${i}p")

		if [[ -z ${a1} ]]; then local a1=0; fi
		if [[ -z ${b1} ]]; then local b1=0; fi

		if [[ "$OPT" == '|' ]]; then
			if [[ ${a1} -eq 1 || ${b1} -eq 1 ]]; then
				local result=1
			else
				local result=0
			fi
		elif [[ "$OPT" == '&' ]]; then
			if [[ $a1 -eq 1 && $b1 -eq 1 ]]; then
				local result=1
			else
				local result=0
			fi
		elif [[ "$OPT" == '^' ]]; then
			if [[ $a1 -eq $b1 ]]; then
				local result=1
			else
				local result=0
			fi
		else
			return 1
		fi

		final="${result}${final}"

		let i++
	done

	if [[ "${output}" == 'dec' ]]; then
		bin2dec $(echo -e "$final" | xargs echo -n \
			| sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
	else
		echo -e "$final" | xargs echo -n \
			| sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'
	fi
}


function serials_num_generate() {
	local START=$1
	local END=$2
	
	local FINAL
	while [[ ${START} -le ${END} ]]
	do
		local FINAL="${FINAL} ${START}"
		let START++
	done
	echo $FINAL
}

function prefix_to_bit_netmask() {
	local prefix=$1;
	local shift=$(( 32 - prefix ));

	local bitmask=""
	local i=0
	while [[ ${i} -lt 32 ]]
	do
		local num=0
		if [ $i -lt $prefix ]; then
			local num=1
		fi

		local space=
		if [ $(( i % 8 )) -eq 0 ]; then
			space=" ";
		fi

		local bitmask="${bitmask}${space}${num}"
		let i++
	done
	echo -e "$bitmask" | sed "s/\ /\\n/g" | grep -v '^$' >"${TEMP_DIR}/bitmask.txt"
	echo -e "$bitmask"
	unset i
}

function bit_netmask_to_wildcard_netmask() {
	local wildcard_mask=
	while read octect && [[ -n "${octect}" ]]
	do
		local octet=$(bin2dec ${octect})
		local wildcard_mask="${wildcard_mask} $(( 255 - $octet ))"
	done < "${TEMP_DIR}/bitmask.txt"

	echo $wildcard_mask;
}

function check_net_boundary() {
	local net=$1;
	local wildcard_mask=$2;
	local is_correct=1
	local i=1
	while [[ ${i} -le 4  ]]
	do
		local net_octet=$(echo $net | cut -d '.' -f $i)
		local mask_octet=$(bit_netmask_to_wildcard_netmask | cut -d ' ' -f $i)
		if [ $mask_octet -gt 0 ]; then

			if [[ $(bit_calc "$(dec2bin $net_octet)" '&' \
				"$(dec2bin $mask_octet)" 'dec') -ne 0 ]]; then
				local is_correct=0;
			fi
		fi
		let i++
	done
	echo $is_correct

	unset i
}

function help_cidr_to_ips() {
	echo ""
	echo "转换CIDR规则地址为IP列表.

使用方法：
cidr_to_ips [OPTION(only one)] [STRING/FILENAME]
详细说明:
	-h  显示帮助
	-i  输入文件路径
	-o  输出结果的文件路径
	-l  输入CIDR列表(逗号分隔)
	-f  强制检查network boundary
	-i  从文件中读取 (不检查network boundary)
	-b  从文件中读取 (同时检查network boundary)

举例:
	cidr_to_ips  -l 192.168.0.1/24
	cidr-to-ips  -l 192.168.0.1/24,10.10.0.0/28
	cidr-to-ips  -f 192.168.0.0/16
	cidr-to-ips  -i inputfile.txt
	cidr-to-ips  -b inputfile.txt
"
}
function cidr_to_ips() {

	OPTIND=1
		
	local START_TIME=$(date +%s)

	local TEMP_DIR=${TEMP_DIR}
	if [[ ! -d ${TEMP_DIR} ]]; then mkdir -p ${TEMP_DIR}; fi

	while getopts 'fl:i:b:o:h' OPT
	do
		case $OPT in
			f) local force='f';;
			i) local INPUT_FILE=$OPTARG;;
			b) local INPUT_FILE=$OPTARG; force='b';;
			o) local OUTPUT_FILE=$OPTARG;;
			l) local CIDR_LIST=$OPTARG;;
			h) help_cidr_to_ips; exit;;
			?) help_cidr_to_ips; exit;;
		esac
	done

	echo -e "开始转换以下CIDR地址:"
	cat "${INPUT_FILE}"
	echo -e "\\n"
	rm -f "${OUTPUT_FILE}"

	if [[ -n "${CIDR_LIST}" ]]; then
		echo -e "${CIDR_LIST}" | sed "s/,/\\n/g" >${INPUT_FILE}
	fi

	while read ip && [[ -n "${ip}" ]]
	do
		local net=$(echo $ip | cut -d '/' -f 1);
		local prefix=$(echo $ip | cut -d '/' -f 2);
		local do_processing=1

		local bit_netmask=$(prefix_to_bit_netmask $prefix)
		local wildcard_mask=$(bit_netmask_to_wildcard_netmask "$bit_netmask")
		local is_net_boundary=$(check_net_boundary $net "$wildcard_mask")

		if [[ "$force" = 'f' && $is_net_boundary -ne 1 \
			|| "$force" = 'b' && $is_net_boundary -ne 1 ]]; then
			read -p "Not a network boundary! Continue anyway (y/N)? " -n 1 -r
			echo    ## move to a new line
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				local do_processing=1
			else
				local do_processing=0
			fi
		fi

		if [[ $do_processing -eq 1 ]]; then
			local str=
			local i=1
			while [[ ${i} -le 4 ]]
			do
				local range=$(echo $net | cut -d '.' -f $i)
				local mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)

				if [[ "$mask_octet" -gt 0 ]]; then
					local range="{$range..$(bit_calc "$(dec2bin $range)" '|' \
						"$(dec2bin $mask_octet)" 'dec')}"
				fi
				local str="${str} $range"
				let i++
			done
			echo -e "${str}" | while read a b c d
			do
				if [[ -n "$(echo "${a}" | grep '{')" ]]; then
					local start_num=$(echo "${a}" | cut -d "{" -f2 \
						| cut -d "." -f1 )
					local end_num=$(echo "${a}" | cut -d "}" -f1 \
						| awk -F "." '{print $(NF)}')
					serials_num_generate $start_num $end_num \
						| sed "s/\ /\\n/g" >${TEMP_DIR}/a.txt
				else
					echo "${a}" >${TEMP_DIR}/a.txt
				fi

				if [[ -n "$(echo "${b}" | grep '{')" ]]; then
					local start_num=$(echo "${b}" | cut -d "{" -f2 \
						| cut -d "." -f1 )
					local end_num=$(echo "${b}" | cut -d "}" -f1 \
						| awk -F "." '{print $(NF)}')
					serials_num_generate $start_num $end_num \
						| sed "s/\ /\\n/g" >${TEMP_DIR}/b.txt
				else
					echo "${b}" >${TEMP_DIR}/b.txt
				fi

				if [[ -n "$(echo "${c}" | grep '{')" ]]; then
					local start_num=$(echo "${c}" | cut -d "{" -f2 \
						| cut -d "." -f1 )
					local end_num=$(echo "${c}" | cut -d "}" -f1 \
						| awk -F "." '{print $(NF)}')
					serials_num_generate $start_num $end_num \
						| sed "s/\ /\\n/g" >${TEMP_DIR}/c.txt
				else
					echo "${c}" >${TEMP_DIR}/c.txt
				fi

				if [[ -n "$(echo "${d}" | grep '{')" ]]; then
					local start_num=$(echo "${d}" | cut -d "{" -f2 \
						| cut -d "." -f1 )
					local end_num=$(echo "${d}" | cut -d "}" -f1 \
						| awk -F "." '{print $(NF)}')
					serials_num_generate $start_num $end_num \
						| sed "s/\ /\\n/g" >${TEMP_DIR}/d.txt
				else
					echo "${d}" >${TEMP_DIR}/d.txt
				fi
				
				while read a && [[ -n ${a} ]]
				do
					while read b && [[ -n ${b} ]]
					do
						while read c && [[ -n ${c} ]]
						do
							while read d && [[ -n ${d} ]]
							do
								awk '{print "'${a}.'" "'${b}.'" "'${c}.'" $0}' \
									>>"${OUTPUT_FILE}"
								green "+\\c"
							done < ${TEMP_DIR}/d.txt
						done < ${TEMP_DIR}/c.txt
					done < ${TEMP_DIR}/b.txt
				done < ${TEMP_DIR}/a.txt
			done

		else
			exit
		fi

	done < "${INPUT_FILE}"
	
	echo -e "\033[0m"
	END_TIME=$(date +%s)
	echo -e "CIDR转IP列表运行总耗时 $((${END_TIME} - ${START_TIME})) 秒"
	echo -e "共转换为 $(cat ${OUTPUT_FILE} | wc -l)个 IP地址， 转换后的IP列表保存在: ${OUTPUT_FILE}"
}

function check_ip() {
	local IP=$1
	local VALID_CHECK=$(echo ${IP} \
		| awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
	
	local RULE="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
	if [[ -n "$(echo -e ${IP} | grep -E ${RULE})" ]]; then
		if [[ "${VALID_CHECK}" == "yes" ]]; then
			echo "IP ${IP} available."
		else
			echo "IP ${IP} not available!"
		fi
	else
		echo "IP format error!"	

	fi
}

function get_cf_ip_list_udp() {
	local META=$(curl -s https://speed.cloudflare.com/meta)
	local ASN=$(parse_json_simple "${META}" asn)
	local CITY=$(parse_json_simple "${META}" city)
	local COUNTRY=$(parse_json_simple "${META}" country)

	# 获取udpfile配置文件
	local UDPFILE_CONF=$(curl -s --ipv4 --retry 3 \
		https://service.udpfile.com\?asn\="${ASN}"\&city="${CITY}")
	if [[ -z "${UDPFILE_CONF}" ]]; then
		echo -e "CF解析节点获取失败， 退出任务"
		exit 1
	fi
	echo -e "${UDPFILE_CONF}" >"${TEMP_DIR}/udpfile.txt"

	# 获取cloudflare CDN IP列表
	echo -e "${UDPFILE_CONF}" | sed '1,4d'
}

function get_cf_ip_list_official() {
	local IP_LIST_FILE=$1
	
	curl https://ghproxy.com/https://raw.githubusercontent.com/hansyao/breakwall/master/cf_ip_database.txt \
	-o ${IP_LIST_FILE}
	
	echo -e "检查cloudflare IP库是否下载成功"
	if [[ -n "$(check_ip $(cat ${IP_LIST_FILE} | head -n 1) \
		| grep -E "(error|not available)")" ]]; then

		echo -e "cloudflare IP库下载失败，开始从cloudflare官网拉取CIDR规则文件进行本地转换"
		echo -e "(转换结果会缓存为临时文件，除非设备重启，下次不会再重新转换)"
		echo -e "本地转换耗时较长，请耐心等待......"
		rm -f ${IP_LIST_FILE}
		curl -s https://www.cloudflare.com/ips-v4 >${TEMP_DIR}/cf_cidr_list.txt

		cidr_to_ips -i "${TEMP_DIR}/cf_cidr_list.txt" -o ${IP_LIST_FILE}
	fi
}

function pack_loss_test() {
	local CF_IP_LIST=$1
	local PACK_LOSS_RESULT=$2
	local EXPECT_IPS=$3

	local PING_COUNT=${PING_COUNT}
	local THREAD_NUMBER=${STATUS_THREAD_NUMBER}
	local EXPECT_RATE=0
	local TOTAL_IPS=$(echo -e "${CF_IP_LIST}" | wc -l)
	
	echo "丢包率测试要求： ${PING_COUNT}次ping的丢包率<=${EXPECT_RATE}%"

	local i=1
	if  [[ ${TOTAL_IPS} -lt ${THREAD_NUMBER} ]]; then
		local j=1
	else
		local j=$(( ${TOTAL_IPS} / ${THREAD_NUMBER} ))
	fi
	local START_LINE=1
	local END_LINE=$((${START_LINE} + ${THREAD_NUMBER} -1))
	local PACK_RESULT_IPS=0
	while [[ ${i} -le ${j} ]]
	do
		echo -e "${CF_IP_LIST}" | sed -n "${START_LINE},${END_LINE}p" \
				>"${TEMP_DIR}/cf_ip_list.txt"
				
		while read LINE && [[ -n "${LINE}" ]] && [[ ${PACK_RESULT_IPS} -lt ${EXPECT_IPS} ]]
		do
			{
			if [[ -e ${PACK_LOSS_RESULT} ]]; then
				local PACK_RESULT_IPS=$(cat ${PACK_LOSS_RESULT} | wc -l)
			else
				local PACK_RESULT_IPS=0
			fi

			if [[ ${PACK_RESULT_IPS} -gt ${EXPECT_IPS} ]]; then exit 0; fi
			local PING_RESULT=$(ping -c ${PING_COUNT} -n -q "${LINE}")
			local LOSS_RATE=$(echo -e "${PING_RESULT}" | grep "packet loss" | sed "s/,\ /\n/g" \
				| grep "packet loss" | awk '{print $1}')
			local DELAY=$(echo -e "${PING_RESULT}" | grep avg \
				| awk -F "=" '{print $2}' | cut -d "/" -f2)
			
			echo -e "${LOSS_RATE}(丢包率) ${DELAY}ms(${PING_COUNT}次ping平均延迟) ${LINE}"

			if [[ $(echo "${LOSS_RATE}" | cut -d "%" -f1) -le ${EXPECT_RATE} ]]; then
				echo -e "${LOSS_RATE}(丢包率)	${DELAY}ms(${PING_COUNT}次ping平均延迟)	${LINE}"\
						>>"${PACK_LOSS_RESULT}"
			fi
			}&
			if [[ -e ${PACK_LOSS_RESULT} ]]; then
				local PACK_RESULT_IPS=$(cat ${PACK_LOSS_RESULT} | wc -l)
			else
				local PACK_RESULT_IPS=0
			fi

		done < "${TEMP_DIR}/cf_ip_list.txt"
		wait
		local START_LINE=$((${START_LINE} + ${THREAD_NUMBER}))
		local END_LINE=$((${END_LINE} + ${THREAD_NUMBER}))
		let i++
	done
	echo -e "筛选出 ${PACK_RESULT_IPS}个 节点IP地址满足丢包率小于或等于 ${EXPECT_RATE}"
}

function clash_config() {
	local PREF_INI=$1
	local POOL=$2
	# 生成基本配置
	local HEADER_CONF="${TEMP_DIR}/header.yaml"
	cat > ${HEADER_CONF} <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: Rule
log-level: silent
external-controller: 0.0.0.0:9090
EOF

	# 生成代理组proxy_groups
	local PROXY_GROUPS="${TEMP_DIR}/proxy_groups.yaml"
	echo "proxy-groups:" >${PROXY_GROUPS}
	cat "${PREF_INI}" | grep "^custom_proxy_group=" | while read LINE && [[ -n "${LINE}" ]]
	do

		local GROUP=$(echo -e "$LINE" | cut -d "=" -f2-)
		local NAME=$(echo -e "${GROUP}" | awk -F "\`" '{print $1}')
		local TYPE=$(echo -e "${GROUP}" | sed "s/${NAME}//g" | cut -d "\`" -f2)
		local GROUP=$(echo -e "${GROUP}" | awk -F "\`" '{for (i=3;i<=NF;i++)printf("%s\t", $i);print ""}')
		
		# 如果存在[]数组
		local PROXY_GROUP1=$(echo -e "${GROUP}" | sed "s/\t/\n/g" | grep "\[]" | sed "s/\[]//g" \
			| sed '/^[  ]*$/d' )
		# 如果不存在[]数组
		local PROXY_GROUP2=$(echo -e "${GROUP}" | sed "s/\t/\n/g" | grep -v "\[]" | sed "s/\[]//g")
		if [[ -n "${PROXY_GROUP2}" ]]; then
			local PROXY_LIST=$(cat ${POOL} | sed '1d' | awk -F "name:" '{print $2}' | cut -d "," -f1 \
			| sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g' | sed '/^[  ]*$/d' \
			| grep -E "$(echo -e "${PROXY_GROUP2}" | sed -n '1p')")
		fi

		echo "  - name: ${NAME}" >>${PROXY_GROUPS}
		echo "    type: ${TYPE}" >>${PROXY_GROUPS}

		if [[ "${TYPE}" == 'url-test' || "${TYPE}" == 'load-balance' ]]; then
			echo "    url: $(echo -e "${PROXY_GROUP2}" | sed -n '2p')" >>${PROXY_GROUPS}
			echo "    interval: $(echo -e "${PROXY_GROUP2}" | sed -n '3p' \
				| awk -F "," '{print $1}')" >>${PROXY_GROUPS}
			echo "    tolerance: $(echo -e "${PROXY_GROUP2}" | sed -n '3p' \
				| awk -F "," '{print $(NF)}')" >>${PROXY_GROUPS}
		fi
		echo "    proxies:" >>${PROXY_GROUPS}
		echo -e "${PROXY_GROUP1} \\n ${PROXY_LIST}" \
			| sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g' | sed '/^[  ]*$/d' \
			| awk '{print "      - " $0}' >>${PROXY_GROUPS}
		
		unset PROXY_LIST
	done

	# 生成规则表
	local RULES="${TEMP_DIR}/tmp_rules.yaml"
	local FINAL_RULES="${TEMP_DIR}/final_rules.yaml"

	rm -f ${RULES}
	cat "${PREF_INI}" | grep "^ruleset=" >${TEMP_DIR}/pref_tmp.ini
	local i=1
	while read LINE && [[ -n "${LINE}" ]]
	do
		unset GROUP
		{
		local LINE=$(echo -e "${LINE}" | cut -d "=" -f2)
		local GROUP=$(echo -e "${LINE}" | cut -d "," -f1)
		local URL=$(echo -e "${LINE}" | cut -d "," -f2)
		if [[ -n "$(echo -e "$URL" | grep 'http')" ]]; then
			echo "正在下载远程规则 ${URL}"
			curl -s "${URL}" | grep -Ev "(^\ *$|\#)" | awk -F "," '{print $1","$2",""'"${GROUP}"'"","$3}' >"${TEMP_DIR}/split_rule_remote_${i}.txt"
		else
			echo "应用本地规则 ${LINE}"
			echo -e $(echo -e "${LINE}" | cut -d "," -f2- | sed 's/\[]//g'),"${GROUP}" >"${TEMP_DIR}/split_rule_local_${i}.txt"
		fi
		}&

		let i++
	done < ${TEMP_DIR}/pref_tmp.ini
	
	wait

	local SPLIT_RULE_LIST=$(ls -l ${TEMP_DIR}/* | grep split_rule | awk '{print $(NF)}')
	echo -e "${SPLIT_RULE_LIST}" | while read SPLIT_RULE && [[ -n "${SPLIT_RULE}" ]]
	do
		cat ${SPLIT_RULE} >>${RULES}
		rm -f ${SPLIT_RULE}
	done
	echo -e "规则去重并移除不支持的规则格式"
	sed -i "s/,$//g" ${RULES}
	echo "rules:" >${FINAL_RULES}
	local INCL="(DOMAIN\|DOMAIN\-KEYWORD\|DOMAIN\-SUFFIX\|GEOIP\|IP-CIDR\|IP-CIDR6\|MATCH\|PROCESS-NAME)"
	cat ${RULES} | grep "${INCL}" | sed "s/FINAL,/MATCH,/g" \
		| sort -n | uniq | awk '{print "  - "$0}' >>${FINAL_RULES}

	# 合并clash配置文件
	cat >"${CLASH_CONFIG}"<< EOF
$(cat ${HEADER_CONF})
$(cat ${POOL})
$(cat ${PROXY_GROUPS})
$(cat ${FINAL_RULES})
EOF
}

function pool_combine() {
	local POOL_CF=$1
	local POOL_COMBINED_CONF=$2

	if [[ -d "${RULE_PATH_OPENCLASH}" ]]; then
		local PROXY_FILE_LIST=$(ls -l ${RULE_PATH_OPENCLASH}/* \
			| grep -v $(echo -e "${CLASH_CONFIG}" | awk -F "/" '{print $(NF)}') \
			| grep '\.yaml' | awk '{print $(NF)}')
	elif [[ -d "${RULE_PATH_MERLINCLASH}" ]]; then
		local PROXY_FILE_LIST=$(ls -l ${RULE_PATH_MERLINCLASH}/* \
			| grep -v $(echo -e "${CLASH_CONFIG}" | awk -F "/" '{print $(NF)}') \
			| grep '\.yaml' | awk '{print $(NF)}')
	elif [[ -d "${RULE_PATH_OTHERS}" ]]; then
		local PROXY_FILE_LIST=$(ls -l ${RULE_PATH_OTHERS}/* \
			| grep -v $(echo -e "${CLASH_CONFIG}" | awk -F "/" '{print $(NF)}') \
			| grep '\.yaml' | awk '{print $(NF)}')
	fi

	rm -f "${TEMP_DIR}/pool_combined_tmp.yaml"
	cat "${POOL_CF}" | grep "\- {" >>"${TEMP_DIR}/pool_combined_tmp.yaml"
	echo -e "${PROXY_FILE_LIST}" | while read PROXY_FILE && [[ -n "${PROXY_FILE}" ]]
	do
		cat "${PROXY_FILE}" | grep "\- {" >>"${TEMP_DIR}/pool_combined_tmp.yaml"
	done

	# 去重
	echo "proxies:" >"${POOL_COMBINED_CONF}"
	cat "${TEMP_DIR}/pool_combined_tmp.yaml" | sort -n | uniq >>"${POOL_COMBINED_CONF}"
	rm -f "${TEMP_DIR}/pool_combined_tmp.yaml"
}

function speed_test() {
	# 基本参数设置
	local IP_LIST_FILE=/tmp/ip_list.txt
	local TEMP_DIR=${TEMP_DIR}
	local EXPECT_IPS=$1
	local EXPECT_BANDWIDTH=$2
	local ALGORITHM=$3
	local SAMPLE_IPS=$4
	local PACK_LOSS_TEST=$5
	local SPEED_TEST=$6
	local RESULT_FILE=$7
	local SPEED_THREAD_NUMBER=${SPEED_THREAD_NUMBER}
	local STATUS_THREAD_NUMBER=${STATUS_THREAD_NUMBER}
	local BASEPATH=$(cd `dirname $0`; pwd)

	# 环境初始化
	local START_TIME=$(date +%s)

	if [[ ${ALGORITHM} -eq 1 ]]; then
		echo -e "执行获取节点IP算法一： 直接从cloudflare官方获取"
		# 第一步 将Cloudflare的IP段生成IP地址清单
		echo -e "开始检查Cloudflarae IP库"
		if [[ ! -e "${IP_LIST_FILE}" ]]; then
			echo -e "未发现cloudflare本地IP库， 开始远程下载"

			get_cf_ip_list_official "${IP_LIST_FILE}"
		else
			if [[ -n "$(check_ip $(cat ${IP_LIST_FILE} | head -n 1) \
				| grep 'error\|not available')" ]];then
				echo -e "IP库异常， 开始远程下载"
				get_cf_ip_list_official "${IP_LIST_FILE}"
			fi
		fi
		local TOTAL_IPS=$(cat "${IP_LIST_FILE}" | wc -l)
		echo -e "查询到Cloudflare IP库共有 ${TOTAL_IPS}个 IP地址"

		# 第二步 从第一步生成的IP地址清单中随机挑选 ${SAMPLE_IPS} 条
		echo -e "随机挑选 ${SAMPLE_IPS}个 IP进行有效性测试"
		shuf -n ${SAMPLE_IPS} "${IP_LIST_FILE}" >${TEMP_DIR}/selected_iplist_random_tmp.txt

		# 排除已经扫描过的IP
		if [[ -e "${TEMP_DIR}/history_scanned_ips.txt" ]]; then
			diff -B -T -w  ${TEMP_DIR}/history_scanned_ips.txt \
				"${TEMP_DIR}/selected_iplist_random_tmp.txt" \
				| grep -E "(\+|>)$(printf '\t')" | awk '{print $(NF)}' \
				>>${TEMP_DIR}/selected_iplist_random.txt
		else
			cat ${TEMP_DIR}/selected_iplist_random_tmp.txt \
				>>${TEMP_DIR}/selected_iplist_random.txt
		fi

	elif  [[ ${ALGORITHM} -eq 2 ]]; then
		echo -e "执行获取节点IP算法二： 从service.udpfile.com获取"
		
		rm -f "${TEMP_DIR}/udpfile.txt"
		rm -f "${TEMP_DIR}/udpfile_ip_list.txt"
		local RETRIEVAL_IPS=0
		local i=1
		while [[ ${RETRIEVAL_IPS} -lt ${SAMPLE_IPS} ]]
		do
			# 刷新多次并去重得到更多IP
			echo -e "第 ${i} 次从 https://service.udpfile.com 获取IP列表"
			get_cf_ip_list_udp >> "${TEMP_DIR}/udpfile_ip_list_tmp.txt"

			# 排除已经扫描过的IP
			if [[ -e "${TEMP_DIR}/history_scanned_ips.txt" ]]; then
				diff -B -T -w ${TEMP_DIR}/history_scanned_ips.txt \
					"${TEMP_DIR}/udpfile_ip_list_tmp.txt" \
					| grep -E "(\+|>)$(printf '\t')" | awk '{print $(NF)}' \
					>>"${TEMP_DIR}/udpfile_ip_list.txt"
			else
				cat ${TEMP_DIR}/udpfile_ip_list_tmp.txt \
					>>${TEMP_DIR}/udpfile_ip_list.txt
			fi

			local RETRIEVAL_IPS=$(cat "${TEMP_DIR}/udpfile_ip_list.txt" \
				| sort | uniq | wc -l)
			sleep 1

			let i++
		done
		cat "${TEMP_DIR}/udpfile_ip_list.txt" | sort | uniq | head -n ${SAMPLE_IPS} \
			>${TEMP_DIR}/selected_iplist_random.txt
		echo "合并后去重 写入 $(cat ${TEMP_DIR}/selected_iplist_random.txt | wc -l)个 IP地址"
	else
		echo "ALGORITHM 参数错误"
		exit 1
	fi

	# 保存扫描过的ip地址
	cat ${TEMP_DIR}/selected_iplist_random.txt >>${TEMP_DIR}/history_scanned_ips.txt


	# 第三步 对第二步挑选的IP进行可用性检测，并按回源速度排序
	local i=1
	if  [[ ${SAMPLE_IPS} -lt ${STATUS_THREAD_NUMBER} ]]; then
		local j=1
	else
		local j=$(( ${SAMPLE_IPS} / ${STATUS_THREAD_NUMBER} ))
	fi
	local START_LINE=1
	local END_LINE=$((${START_LINE} + ${STATUS_THREAD_NUMBER} -1))
	echo -e "正在扫描节点IP，请稍后..."
	while [[ ${i} -le ${j} ]]
	do
		sed -n "${START_LINE},${END_LINE}p" ${TEMP_DIR}/selected_iplist_random.txt \
				>"${TEMP_DIR}/selected_iplist_split.txt"
		while read IP && [[ -n "${IP}" ]]
		do
			{
			local STATUS=$(curl -s -L -w "%{http_code}\\t%{time_total}" --connect-timeout 2 \
				--resolve speed.cloudflare.com:443:${IP} \
				-o /dev/null https://speed.cloudflare.com/__down)
			local HTTP_CODE=$(echo -e "${STATUS}" | awk '{print $1}' | awk '{print int($0)}')
			local TIME_TOTAL=$(echo -e "${STATUS}" | awk '{print $2}')
			
			if [[ ${HTTP_CODE} -eq 200 ]]; then
				green "+\\c"
				echo "${TIME_TOTAL}(回源总延迟)	${IP}" >>${TEMP_DIR}/selected_iplist_unsort.txt
			else
				red "-\\c"
			fi
			}&
		done < ${TEMP_DIR}/selected_iplist_split.txt
		wait
		local START_LINE=$((${START_LINE} + ${STATUS_THREAD_NUMBER}))
		local END_LINE=$((${END_LINE} + ${STATUS_THREAD_NUMBER}))

		let i++
	done
	echo -e "\033[0m"
	if [[ ! -e ${TEMP_DIR}/selected_iplist_unsort.txt ]]; then
		echo -e "未找到有效IP"
		return 1
	else
		cat ${TEMP_DIR}/selected_iplist_unsort.txt | sort | uniq >${TEMP_DIR}/selected_iplist.txt
	fi

	local VALID_IPS=$(cat ${TEMP_DIR}/selected_iplist.txt | wc -l)
	echo -e "共扫描到(有效节点IP： ${VALID_IPS} 个; \
无效节点 $(($(cat ${TEMP_DIR}/selected_iplist_random.txt|wc -l) - ${VALID_IPS} )) 个)"

	# 第四步 丢包率和ping延迟率测试
	if [[ "${PACK_LOSS_TEST}" == 'yes' ]]; then
		local START_TIME2=$(date +%s)
		echo -e "开始测试丢包率	$(date -R -d @${START_TIME})"
		pack_loss_test "$(cat "${TEMP_DIR}/selected_iplist.txt" \
			| awk '{print $(NF)}')" "${TEMP_DIR}/pack_loss_result.txt" "$((${EXPECT_IPS} * 2))"
		local END_TIME=$(date +%s)
		echo -e "丢包率测试完成, 耗时 $((${END_TIME} - ${START_TIME2})) 秒\
	$(date -R -d @${END_TIME})"
		cat "${TEMP_DIR}/pack_loss_result.txt" | sort -n >${TEMP_DIR}/selected_iplist.txt
	else
		echo -e "跳过丢包率测试"
	fi

	# 第五步 开始对上一步骤筛选出来的IP进行带宽测速
	if [[ "${SPEED_TEST}" == 'no' ]]; then
		cat ${TEMP_DIR}/selected_iplist.txt | head -n ${EXPECT_IPS} >${RESULT_FILE}
		# 第六步 完成后计算运行时间
		local RESULT_IPS=$(cat "${RESULT_FILE}" | wc -l)
		local END_TIME=$(date +%s)
		echo -e "带宽测速已跳过, 运行总耗时 $((${END_TIME} - ${START_TIME})) 秒"
		echo -e "共找到 ${RESULT_IPS}个 可用IP"

		rm -f $(ls -l ${TEMP_DIR}/* | grep -Ev "(history_scanned_ips.txt|${RESULT_FILE})" | awk '{print $(NF)}')

		return 0
	fi

	echo -e "开始对 $(cat ${TEMP_DIR}/selected_iplist.txt | wc -l)个 满足要求的有效IP进行带宽测速"
	local EXPECT_DL_SPEED="$(awk 'BEGIN{print "'${EXPECT_BANDWIDTH}'" * 1 / 8 * 1000 * 1000  }')"
	local DL_SIZE=$((500 * 1024 * 1024))

	local i=1
	if  [[ ${VALID_IPS} -lt ${SPEED_THREAD_NUMBER} ]]; then
		local j=1
	else
		local j=$(( ${VALID_IPS} / ${SPEED_THREAD_NUMBER} ))
	fi	
	local START_LINE=1
	local END_LINE=$((${START_LINE} + ${SPEED_THREAD_NUMBER} -1))
	if [[ -e "${RESULT_FILE}" ]]; then
		local SPEED_RESULT_IPS=$(cat "${RESULT_FILE}" | wc -l)
	else
		local SPEED_RESULT_IPS=0
	fi
	while [[ ${i} -le ${j} ]]
	do
		sed -n "${START_LINE},${END_LINE}p" ${TEMP_DIR}/selected_iplist.txt \
			>${TEMP_DIR}/selected_iplist_split.txt
		while read LINE && [[ -n "${LINE}" ]] && [[ ${SPEED_RESULT_IPS} -lt ${EXPECT_IPS} ]]
		do
			{
			if [[ $(cat "${RESULT_FILE}" | wc -l) -ge ${EXPECT_IPS} ]]; then exit; fi
			local IP=$(echo -e "${LINE}" | awk '{print $(NF)}')

			local STATUS=$(curl -w "%{speed_download}\\t%{time_connect}" \
				--resolve speed.cloudflare.com:443:${IP} https://speed.cloudflare.com/__down \
				-G -d "measId=$(date -u +%s)"  -d "bytes=${DL_SIZE}" \
				-o /dev/null --connect-timeout 3 --max-time 10 2>&1)

			local SPEED=$(echo -e "${STATUS}" | tail -n 1 | awk '{print $1}' | awk '{print int($0)}')
			local SPEED=$(printf "%.f" "${SPEED}")
			local TIME_CONNECT=$(echo -e "${STATUS}" | tail -n 1 | awk '{print $(NF)}')

			if [[ ${SPEED} -eq 0 ]]; then
				local MAX_SPEED=0
			else
				local MAX_SPEED=$(echo -e "${STATUS}" | sed -n "3p" | awk '{print $(NF)}')

				if [[ "$(echo -e ${MAX_SPEED} | tail -c 2)" == 'k' ]]; then
					local MAX_SPEED=$(echo -e "${MAX_SPEED}" | sed "s/.$//g")
					local MAX_SPEED=$(awk 'BEGIN{print "'${MAX_SPEED}'" * 1024}')
				elif [[ "$(echo -e ${MAX_SPEED} | tail -c 2)" == 'm' \
					|| "$(echo -e ${MAX_SPEED} | tail -c 2)" == 'M' ]]; then
					local MAX_SPEED=$(echo -e "${MAX_SPEED}" | sed "s/.$//g")
					local MAX_SPEED=$(awk 'BEGIN{print "'${MAX_SPEED}'" * 1024 * 1024 }')
				fi
			fi
			local MAX_SPEED=$(printf "%.f" "${MAX_SPEED}")
			if [[ ${SPEED} -gt ${MAX_SPEED} ]]; then
				local MAX_SPEED=${SPEED}
			fi
			
			local DL_SPEED="$(awk 'BEGIN{print "'${SPEED}'" / 1024 /1024}') Mb/s"
			local BANDWIDTH="$(awk 'BEGIN{print "'${SPEED}'" * 8 / 1000000}') Mbps"
			local DL_SPEED_MAX="$(awk 'BEGIN{print "'${MAX_SPEED}'" / 1024 /1024}') Mb/s"
			local BANDWIDTH_MAX="$(awk 'BEGIN{print "'${MAX_SPEED}'" * 8 / 1000000}') Mbps"

			if [[ ${MAX_SPEED} -lt ${EXPECT_DL_SPEED} ]]; then
				echo "${DL_SPEED}(平均下载速度)	${DL_SPEED_MAX}(最大下载速度)	${BANDWIDTH_MAX}(实测带宽)	${TIME_CONNECT}(回源连接延迟)	${LINE}"
				exit
			else
				if [[ $(cat ${RESULT_FILE} | wc -l) -ge ${EXPECT_IPS} ]]; then exit; fi
				echo "${DL_SPEED}(平均下载速度)	${DL_SPEED_MAX}(最大下载速度)	${BANDWIDTH_MAX}(实测带宽)	${TIME_CONNECT}(回源连接延迟)	${LINE}" \
					>>${RESULT_FILE}
				green "${DL_SPEED}(平均下载速度)	${DL_SPEED_MAX}(最大下载速度)	${BANDWIDTH_MAX}(实测带宽)	${TIME_CONNECT}(回源连接延迟)	${LINE}"
			fi
			
			}&

			if [[ -e "${RESULT_FILE}" ]]; then
				local SPEED_RESULT_IPS=$(cat "${RESULT_FILE}" | wc -l)
			else
				local SPEED_RESULT_IPS=0
			fi

		done < ${TEMP_DIR}/selected_iplist_split.txt
		wait

		local START_LINE=$((${START_LINE} + ${SPEED_THREAD_NUMBER}))
		local END_LINE=$((${END_LINE} + ${SPEED_THREAD_NUMBER}))

		let i++

	done

	# 第六步 完成后计算运行时间
	local RESULT_IPS=$(cat "${RESULT_FILE}" | wc -l)
	local END_TIME=$(date +%s)
	echo -e "带宽测速完成, 运行总耗时 $((${END_TIME} - ${START_TIME})) 秒"
	echo -e "共找到 ${RESULT_IPS}个 优选IP满足 ${EXPECT_BANDWIDTH}M 带宽需求"

	rm -f $(ls -l ${TEMP_DIR}/* | grep -Ev "(history_scanned_ips.txt|${RESULT_FILE})" | awk '{print $(NF)}')
}

speed_test_all() {
	local EXPECT_IPS=$1
	local EXPECT_BANDWIDTH=$2
	local ALGORITHM=$3
	local SAMPLE_IPS=$4
	local PACK_LOSS_TEST=$5
	local SPEED_TEST=$6
	local RESULT_FILE=$7
	local TEMP_DIR=${TEMP_DIR}

	rm -rf "${TEMP_DIR}"
	mkdir -p "${TEMP_DIR}"
	touch "${RESULT_FILE}"
	
	local RESULT_IPS=0
	while [[ ${RESULT_IPS} -lt ${EXPECT_IPS} ]]
	do
		if [[ ${RESULT_IPS} -lt 20 ]]; then
			speed_test ${EXPECT_IPS} ${EXPECT_BANDWIDTH} ${ALGORITHM} \
				${SAMPLE_IPS} ${PACK_LOSS_TEST} ${SPEED_TEST} ${RESULT_FILE}
		fi
		local RESULT_IPS=$(cat ${RESULT_FILE} | wc -l)
	done
	echo -e "测速结果保存在: ${RESULT_FILE}"
}

function request_body_create() {
  # 生成请求结构体 - 新建
  local REMOTE_NAME=$1
  local CONFIG=$2

  cat > "${DESC_JSON}" <<EOF
{
 "description":"clash config by cloudflare speedtest",
 "public": false,
 "files": {
   "${REMOTE_NAME}": {
     "content":"$(sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'  -e 's/$/\\n/' <${CONFIG})"
    }
  }
}
EOF
}

function request_body_update() {
  # 生成请求结构体 - 更新
  local REMOTE_NAME=$1
  local GIST_ID=$2
  local CONFIG=$3

  cat > "${DESC_JSON}" <<EOF
{
 "description":"clash config by cloudflare speedtest",
 "public": false,
 "gist_id": "${GIST_ID}",
 "files": {
   "${REMOTE_NAME}": {
     "content":"$(sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'  -e 's/$/\\n/' <${CONFIG})"
    }
  }
}
EOF
}

function gist() {
	local ACTION=$1
	local GIST_ID=$2
	local REMOTE_NAME=$3
	local CONFIG=$4

	if [[ "$ACTION" == 'create' ]]; then
		local REMOTE_NAME="$2"
		local CONFIG="$3"

		request_body_create "${REMOTE_NAME}" "${CONFIG}"
		curl -s -H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GIST_TOKEN}" \
		-d @"${DESC_JSON}" \
		-X POST https://api.github.com/gists >${RESPONSE} 2>&1
	elif [[ "$ACTION" == 'update' ]]; then

		request_body_update "${REMOTE_NAME}" "${GIST_ID}" "${CONFIG}"
		curl -s -H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GIST_TOKEN}" \
		-d @"${DESC_JSON}" \
		-X POST https://api.github.com/gists/${GIST_ID} >${RESPONSE} 2>&1
	elif [[ "$ACTION" == 'info' ]]; then
		curl -s -H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GIST_TOKEN}" \
		-X GET https://api.github.com/gists/${GIST_ID} >${RESPONSE} 2>&1
	else
		echo "${ACTION} 命令不支持"
	fi
}

function get_gist_url() {
	local RAW_URL=$(cat "${RESPONSE}" | grep raw_url)
	if [[ -z "${RAW_URL}" ]]; then
		return 1
	fi

	local RAW_URL=$(echo -e "${RAW_URL}" | awk -F"\"" '{print $4}' | head -n 1)
	local COMMIT_ID=$(echo -e ${RAW_URL} | awk -F"/" '{print $(NF-1)}')
	echo -e "${RAW_URL}" | sed "s/${COMMIT_ID}\///g"
}

function update_status() {
	local OPTION=$1
	local GIST_ID=$2
	local GIST_URL="$(get_gist_url)"
	if [[ -n "${GIST_URL}" ]]; then
		echo -e "gist上传成功： ${GIST_URL}"
		local GIST_NEW_ID=$(echo -e "${GIST_URL}" | awk -F "/" '{print $(NF-2)}')
		if [[ "${GIST_ID}" != "${GIST_NEW_ID}" ]]; then
			echo -e "更新GIST_ID_${OPTION}: ${GIST_ID}为： ${GIST_NEW_ID} 下次运行生效"
			sed -i "s/GIST_ID_${OPTION}\=.*$/GIST_ID_${OPTION}\=${GIST_NEW_ID}/g" "${BASEPATH}"/$(basename $0)
		fi

	else
		echo -e "未收到正确的返回信息，gist可能上传失败"
		echo -e $(cat "${RESPONSE}")
	fi
}

function upload_gist() {
	local REMOTE_NAME=$1
	local OPTION=$2
	local CONFIG=$3

	local GIST_ID=$(cat ${BASEPATH}/$(basename $0)| grep -E "GIST_ID_${OPTION}\=" | awk -F "=" '{print $2}')
	if [[ -n "${GIST_TOKEN}" ]]; then
		if [[ -n "${GIST_ID}" ]]; then
			gist 'info' "${GIST_ID}"
			local GIST_URL=$(get_gist_url)
			if [[ -n "${GIST_URL}" ]]; then
				echo -e "发现gist远程文件,准备提交更新"
				gist update "${GIST_ID}" "${REMOTE_NAME}" "${CONFIG}"
				update_status "${OPTION}" "${GIST_ID}"
			else
				echo -e "gist远程文件不存在,准备全新提交"
				gist create "${REMOTE_NAME}" "${CONFIG}"
				update_status "${OPTION}" "${GIST_ID}"
			fi
		else
			echo -e "gist远程文件不存在,准备全新提交"
			gist create "${REMOTE_NAME}" "${CONFIG}"
			update_status "${OPTION}" "${GIST_ID}"
		fi
	else
		echo -e "GIST_TOKEN 不存在，请先填入GIST_TOKEN"
	fi
}

remote_config_convert() {
	local TARGET=$1
	local GIST_CONF_URL=$2
	local VERSION=$3


	local CONVERTER_DOMAIN=https://oneplus-solution.com/convert/sub\?
	local EXTERNAL_CONFIG=$(urlencode "${PREF_INI_URL}")
	local GIST_CONF_URL=$(urlencode "${GIST_CONF_URL}")
	curl -s ${CONVERTER_DOMAIN}target\=${TARGET}\&ver\=${VERSION}\&config\=${EXTERNAL_CONFIG}\&url\=${GIST_CONF_URL}

}

remote_config_convert_all() {
	local GIST_CONF_URL=$1
	cat ${BASEPATH}/$(basename $0) | grep -E "^CONVERT_.*=yes" \
		| awk -F "=" '{print $1}' | cut -d "_" -f2 \
		>${TEMP_DIR}/rules_list.txt

	echo -e "开始规则转换"
	while read LINE && [[ -n "${LINE}" ]]
	do
		
		if [[ -n "$(echo -e "${LINE}" | grep surge)" ]]; then
			local TARGET=$(echo -e "${LINE}" | sed 's/.$//g')
			local VERSION=$(echo -e "${LINE}" | sed 's/surge//g')
		else
			local TARGET="${LINE}"
			local VERSION=""
		fi
		if [[ -n "$(echo -e "${LINE}" | grep clash)" ]]; then
			local EXT_NAME='.yaml'
		else
			local EXT_NAME='.conf'
		fi
		remote_config_convert "${TARGET}" "${GIST_CONF_URL}" "${VERSION}"  >${TEMP_DIR}/${LINE}_${REMOTE_NAME}${EXT_NAME}

		local status=$(cat ${TEMP_DIR}/${LINE}_${REMOTE_NAME}${EXT_NAME} | head -n 1 \
			| grep -E '(Invalid target|The following link|No nodes were found)')
		if [[ -n "${status}" ]]; then
			echo -e "${LINE} 配置转换失败: $(cat ${TEMP_DIR}/${LINE}_${REMOTE_NAME}${EXT_NAME} | head -n 1)"
			continue
		fi
		
		echo -e "转换 ${LINE} 配置完成"
		echo -e "上传 ${LINE}_${REMOTE_NAME}${EXT_NAME} 到gist"
		upload_gist "${LINE}_${REMOTE_NAME}${EXT_NAME}" "${LINE}" "${TEMP_DIR}/${LINE}_${REMOTE_NAME}${EXT_NAME}"

	done < ${TEMP_DIR}/rules_list.txt
}

function cron_job() {
	local USER=$USER
	local CRON_PATH='/var/spool/cron/crontabs'

	local RE=$(`which sudo` sh -c "if [[ -d ${CRON_PATH} ]]; then echo yes; else echo no;fi")
	if [[ ${RE} == 'no' ]]; then local CRON_PATH='/var/spool/cron'; fi

	`which sudo` sh -c "sed -i '/$(basename $0)/d' ${CRON_PATH}/$USER"
	crontab -l | { cat; echo -e "${SCHEDULE} ${BASEPATH}/$(basename $0) ${PLATFORM} >${BASEPATH}/$(basename $0).log 2>&1"; } | crontab -
}

PLATFORM=$1	#可选平台： merlin, openwrt, vps

BASEPATH=$(cd `dirname $0`; pwd)
START_TIME=$(date +%s)
if [[ ! -d "${TEMP_DIR}" ]]; then mkdir -p "${TEMP_DIR}"; fi
DURATION=$(( 3 + $(if [[ "${SPEED_TEST}" == 'yes' ]]; then echo ${TARGET_IPS}*10*2/60; else echo 0;fi) ))


# 进行下载测速
echo -e "开始进行 Cloudflare IP 优选"
echo
START_TIME2=$(date +%s)
META=$(curl -s --retry 3 https://speed.cloudflare.com/meta)
COUNTRY_CF=$(parse_json_simple "${META}" country)
CITY_CF=$(parse_json_simple "${META}" city)
CLIENT_IP_CF=$(parse_json_simple "${META}" clientIp)
ISP_CF=$(parse_json_simple "${META}" colo)
LAT_CF=$(parse_json_simple "${META}" latitude)
LON_CF=$(parse_json_simple "${META}" longitude)

echo "你的公网IP信息:"
IP_API=$(curl -s --retry 3 http://ip-api.com/json/\?lang=zh-CN)
if [[ "$(parse_json_simple "${IP_API}" status)" == 'success' ]]; then
	COUNTRY=$(parse_json_simple "${IP_API}" country)
	REGION=$(parse_json_simple "${IP_API}" regionName)
	CITY=$(parse_json_simple "${IP_API}" city)
	ISP=$(parse_json_simple "${IP_API}" isp)
	LAT=$(parse_json_simple "${IP_API}" lat)
	LON=$(parse_json_simple "${IP_API}" lon)
	IP_ADDR=$(parse_json_simple "${IP_API}" query)
	echo -e "IP地址:${IP_ADDR}"
	echo -e "地域：${COUNTRY}/${REGION}/${CITY}"
	echo -e "运营商：${ISP}"
	echo -e "位置：经度 ${LAT} 纬度 ${LON}"
else
	echo -e "IP:${CLIENT_IP_CF}"
fi

echo
echo "cloudflare解析到的IP信息:"
echo -e "IP地址:${CLIENT_IP_CF}"
echo -e "地域：${COUNTRY_CF}/${CITY_CF}"
echo -e "位置：经度 ${LAT_CF} 纬度 ${LON_CF}"
echo

if [[ "${COUNTRY_CF}" != 'CN' ]]; then
	echo "侦测到你正在用代理访问speed.cloudflare.com, \\n
为了测速准确， 请先关闭代理， 或者将speed.cloudflare.com域名及以下IP规则加入白名单"
	curl -s --retry 3 https://www.cloudflare.com/ips-v4
fi

if [[ "${PLATFORM}" == 'merlin' || "${PLATFORM}" == 'openwrt' ]]; then
	if [[ "${COUNTRY_CF}" != 'CN' ]]; then
		echo "关闭clash代理"
		kill -9 "$(ps | grep clash | grep -v grep | awk '{print $1}')"
	fi
fi

if [[ "${PLATFORM}" == 'openwrt' ]]; then
	echo -e "开始检查依赖项"
	openwrt_env
	if [[ $? -gt 0 ]]; then
		echo "openwrt缺少依赖项, 结束任务!"
		exit
	fi
fi

speed_test_all ${TARGET_IPS} ${EXPECT_BANDWIDTH} ${ALGORITHM} \
	${SAMPLE_IPS} ${PACK_LOSS_TEST} ${SPEED_TEST} "${TEMP_DIR}/speedtest_result.txt"
RESULT_LIST=$(cat "${TEMP_DIR}/speedtest_result.txt" | sort -n -r \
	| head -n ${TARGET_IPS} | awk '{print ($NF)}')
echo -e "优选 ${TARGET_IPS}个 CF节点如下:"
cat "${TEMP_DIR}/speedtest_result.txt" | sort -n -r | head -n ${TARGET_IPS}

echo -e "开始根据测试结果生成clash配置文件"
echo "proxies:" >"${POOL}"
i=1
echo -e "${RESULT_LIST}" | while read LINE && [[ -n "${RESULT_LIST}" ]]
do
	pool_generate "${LINE}" "${i}" >>"${POOL}"
	let i++
done
unset i
END_TIME=$(date +%s)
echo -e "根据公网IP ${CLIENT_IP} 解析出cloudflare CDN加速IP池"
echo -e "按要求筛选出 $(($(cat ${POOL} | wc -l) -1)) 个优选IP, 生成的代理池文件保存在： ${POOL}"
echo -e "筛选CF优选IP任务完成, 耗时 $(( ${END_TIME} - ${START_TIME} )) 秒\
	$(date -R -d @${END_TIME})"

################ clash代理池合并 ######################
if [[ "${POOL_COMBINE}" == 'yes' ]]; then
	echo -e "开始合并代理池"
	pool_combine "${POOL}" "${POOL_COMBINED_CONF}"
	echo -e "代理池合并完成, 保存在: ${POOL_COMBINED_CONF}"
else
	POOL_COMBINED_CONF=${POOL}
fi
################ 转换clash规则开始 ####################
if [[ "${CLASH_ENABLE}" == 'yes' ]]; then
	START_TIME2=$(date +%s)
	echo -e "开始加入clash规则并转换 $(date -R -d @${END_TIME})"
	if [[ -n "${PREF_INI_URL}" ]]; then
		curl -L -s "${PREF_INI_URL}" \
		| sed "s/https:\/\/raw.githubusercontent/https:\/\/ghproxy.com\/https:\/\/raw.githubusercontent/g" \
		> "${PREF_INI}"
	fi
	clash_config "${PREF_INI}" "${POOL_COMBINED_CONF}"

	END_TIME=$(date +%s)
	echo -e "clash规则转换完成, 耗时 $((${END_TIME} - ${START_TIME2})) 秒"
	echo -e "转换后的Clash配置文件保存在： ${CLASH_CONFIG}"
	echo -e "任务完成, 总耗时 $((${END_TIME} - ${START_TIME})) 秒	$(date -R -d @${END_TIME})"
fi
################ 转换clash规则完成 ####################

################ 梅林Merlin路由器  ############
if [[ "${PLATFORM}" == 'merlin' ]]; then
	clashconfig=/jffs/.koolshare/merlinclash/clashconfig.sh
	if [[ ! -x "$clashconfig" ]]; then exit 0; fi
	source $clashconfig
	
	cp -f  ${CLASH_CONFIG} /tmp/upload/
	merlinclash_uploadfilename="$(echo -e "${CLASH_CONFIG}" | awk -F "/" '{print $(NF)}')"
	move_config
	echo "==========================="
	# cat $LOG_FILE | tail -n 11

	echo "==========================="
	echo "开始重启 Clash 进程并显示日志"
	sync
	echo 1 > /proc/sys/vm/drop_caches
	sleep 1s
	dbus set merlinclash_enable="1"
	sh /koolshare/merlinclash/clashconfig.sh restart >/dev/null 2>&1 &
    	cat $LOG_FILE | tail -n 17
	#如果重启失败，直接执行启动命令
	if [[ -z "$(ps | grep clash | grep -v grep)" ]]; then
		/koolshare/bin/clash -d /koolshare/merlinclash/ \
		-f /koolshare/merlinclash/yaml_use/$(echo -e "${CLASH_CONFIG}" | awk -F "/" '{print $(NF)}')
	fi
fi

################ OpenWRT路由器 ##############
if [[ "${PLATFORM}" == 'openwrt' ]]; then
	if [[ "${CLASH_ENABLE}" == 'yes' ]]; then
		echo -e "开始写入clash配置"
		cp -f  ${CLASH_CONFIG} /etc/openclash/config/
		/etc/init.d/openclash restart
		echo -e "clash配置写入完成, 可到clash配置面板切换"
	fi
	if [[ "${PASSWALL_ENABLE}" == 'yes' ]]; then
		if [[ $? -eq 0 ]]; then
			echo -e "开始写入passwall配置"
			passwall_config "${POOL}"
			if [[ $? -eq 0 ]]; then
				echo -e "passwall配置写入完成"
				uci show passwall | grep address=
				echo -e "请稍后，正在重启passwall和haproxy"
				/etc/init.d/haproxy restart
				/etc/init.d/passwall restart
				
				echo -e "重启成功并结束任务"
			else
				echo -e "passwall配置写入失败"
			fi
		fi
	fi
fi

################ VPS自建服务器 ##############
if [[ "${PLATFORM}" == 'vps' ]]; then
	`which sudo` sh -c "cp -f  ${CLASH_CONFIG} ${WWW_PATH}"
fi

################ 定时任务 ################

if [[ -n "${PLATFORM}" ]]; then
	echo "开始创建计划任务 ${SCHEDULE}"
	cron_job
	echo "计划任务更新完成 ${SCHEDULE}"
	crontab -l | grep $(basename $0)
fi

################ 上传到 gist 开始 ####################

if [[ "${CONVERTER_ENABLE}" == 'yes' ]]; then
	echo -e "准备进行规则转换并上传gist"
	sleep 5
	# 上传代理池文件到gist
	# REMOTE_NAME=$(cat "${POOL}" | awk -F "/" '{print $(NF)}')
	upload_gist "main_${REMOTE_NAME}.yaml" 'main' "${POOL}"
	GIST_CONF_URL=$(get_gist_url)
	# echo GIST_CONF_URL: $GIST_CONF_URL
	# 远程转换规则并创建远程订阅链接
	remote_config_convert_all "${GIST_CONF_URL}"
	# 删除远程代理池
fi
################ 上传到 gist 完成 ####################


# 清空临时文件
if [[ -n "${PLATFORM}" ]]; then
	rm -rf "${TEMP_DIR}" 
fi

END_TIME=$(date +%s)
echo
green "全部运行完成，运行总耗时 $((${END_TIME} - ${START_TIME})) 秒"
red "=====结束任务====="
echo -e "\033[0m"
exit 0
