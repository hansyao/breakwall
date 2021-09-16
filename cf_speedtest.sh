#!/bin/sh

PLATFORM=$1	#可选平台： merlin, openwrt, vps

# 一般配置常量， 可按需更改
PING_COUNT=100	#单个ping检测次数, 缺省100次
TARGET_IPS=20	#目标IP数:缺省20，单一代理20个CDN IP足够, 太多了也没意义
SCHEDULE="30 */6 * * *"	#计划任务 (由于crontab版本不同，各个平台计划任务的格式可能会稍有差异，按实际情况填写)
GHPROXY='https://ghproxy.com/'				#github代理网址
PREF_INI_URL="${GHPROXY}https://gist.githubusercontent.com/hansyao/e00678003f4eea63b219217638582414/raw/cloudflare.ini"	#远程规则文件
PREF_INI='/tmp/cloudflare.ini'				#本地规则文件，如PREF_INI_URL未定义，则抓取PREF_INI本地规则
POOL='/tmp/clash_cloudflare.yaml'			#脚本自动生成的转换规则前的代理池文件路径
CLASH_CONFIG='/tmp/clash_cloudflare_final.yaml'		#脚本自动规则转换后的的代理池文件路径
WWW_PATH='/var/www/html/'				#VPS服务器上的web路径，如需要外网访问需要将其路径填写在这里
CLASH_ENABLE=yes					#是否应用clash(yes/no), 填no不进行规则转换, opewrt填no同时不应用到配置文件
PASSWALL_ENABLE=yes					#是否应用passwall(yes/no), openwrt适用，填no不用passwall

# 上传Github gist用到的全局变量
GIST_TOKEN=						#github密钥，需要授予gist权限，如不上传留空即可
GIST_ID=						#运行后会自动生成，无需更改
REMOTE_NAME='clash_cloudflare.yaml'			#上传到gist上的文件名,按需更改
DESC_JSON='/tmp/gist.json'				#提交给gist的请求结构体,无需更改
RESPONSE='/tmp/gist_response.json'			#gist返回的状态结构体,无需更改

# 代理池，改称自己的，如有多个代理每个配置一行按照格式填写即可
function pool_generate() {
	local SERVER=$1
	local ID=$2
	echo -e  "  - {name: VPS1_美国_CF加速(${ID}), server: ${SERVER}, port: 443, type: vmess, uuid: xxxx-xxxx-xxxx-xxxx-0000xxxx, alterId: 0, cipher: auto, tls: true, skip-cert-verify: false, network: ws, ws-path: /PrVbmadf, ws-headers: {Host: your.cloudflare.workers.dev}}"
	# echo -e  "  - {name: VPS2_美国_CF加速(${ID}), server: ${SERVER}, port: 4362, type: vmess, uuid: xxxxx-4084-xxxx-xxxx, alterId: 0, cipher: auto, tls: true, skip-cert-verify: false, network: ws, ws-path: /PrVbmadfad, ws-headers: {Host: your.cloudflare.workers.dev}}"
}

function passwall_config() {
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
		echo -e "$SERVER_NAME\`${PORT}" >>/tmp/main_server.txt

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
		local HAPROXY_PORT=$(cat /tmp/main_server.txt | grep -E "^${SERVER_NAME}\`" | awk -F "\`" '{print $2}')
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
	rm -f /tmp/main_server.txt
	unset i
}

function get_cf_ip_list() {
	local IP_LOCATION=$(curl -s --ipv4 --retry 3 -v https://speed.cloudflare.com/__down 2>&1)
	local ASN=$(echo -e "${IP_LOCATION}" | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $(NF)}')
	local CITY=$(echo -e "${IP_LOCATION}" | grep cf-meta-city: | tr '\r' '\n' | awk '{print $(NF)}')
	local PUBLIC_IP=$(echo -e "${IP_LOCATION}" | grep cf-meta-ip: | tr '\r' '\n' | awk '{print $(NF)}')
	echo -e "${PUBLIC_IP}" >/tmp/public_ip.txt

	# 获取udpfile配置文件
	local UDPFILE_CONF=$(curl -s --ipv4 --retry 3 https://service.udpfile.com\?asn\="${ASN}"\&city="${CITY}")

	local DOMAIN=$(echo -e "${UDPFILE_CONF}" | grep domain= | cut -d '=' -f2-)
	local UPLOAD_FILE=$(echo -e "${UDPFILE_CONF}" | grep file= | cut -d '=' -f2-)
	local URL=$(echo -e "${UDPFILE_CONF}"  | grep url= | cut -d '=' -f2-)
	local APP=$(echo -e "${UDPFILE_CONF}"  | grep app= | cut -d '=' -f2-)

	# 获取cloudflare CDN IP列表
	echo -e "${UDPFILE_CONF}" | sed '1,4d'
}

function pack_loss_test() {
	local CF_IP_LIST=$1

	echo -e "${CF_IP_LIST}" | while read LINE && [[ -n "${LINE}" ]]
	do
		{
			local PING_RESULT=$(ping -c ${PING_COUNT} -n -q "${LINE}")
			local LOSS_RATE=$(echo -e "${PING_RESULT}" | grep "packet loss" | sed "s/,\ /\n/g" \
				| grep "packet loss" | awk '{print $1}')
			local DELAY=$(echo -e "${PING_RESULT}" | grep avg | awk -F "=" '{print $2}' | cut -d "/" -f2)
			echo -e "${LOSS_RATE}(丢包率) ${DELAY}ms(${PING_COUNT}次ping平均延迟) ${LINE}"

		}&
	done
	while :
	do
		if [[ $(ps | wc -l) -gt 5 ]]; then
			local p=$(ps | grep " ping " | grep -v "grep" | wc -l)
		else
			local p=$(ps -ef | grep " ping " | grep -v "grep" | wc -l)
		fi
		if [[ $p -gt 0 ]]; then
			sleep 1
		else
			break
		fi
	done
}

function clash_config() {
	local PREF_INI=$1
	# 生成基本配置
	local HEADER_CONF='/tmp/header.yaml'
	cat > ${HEADER_CONF} <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: Rule
log-level: silent
external-controller: 0.0.0.0:9090
EOF

	# 生成代理组proxy_groups
	local PROXY_GROUPS='/tmp/proxy_groups.yaml'
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
	local RULES=/tmp/tmp_rules.yaml
	local FINAL_RULES=/tmp/final_rules.yaml
	echo >${RULES}
	cat "${PREF_INI}" | grep "^ruleset=" | while read LINE && [[ -n "${LINE}" ]]
	do
		unset GROUP
		# {
		local LINE=$(echo -e "${LINE}" | cut -d "=" -f2)
		local GROUP=$(echo -e "${LINE}" | cut -d "," -f1)
		local URL=$(echo -e "${LINE}" | cut -d "," -f2)
		if [[ -n "$(echo -e "$URL" | grep 'http')" ]]; then
			echo "正在下载远程规则 ${URL}"
			curl -s "${URL}" | grep -Ev "(^\ *$|\#)" | awk -F "," '{print $1","$2",""'"${GROUP}"'"","$3}' >>${RULES}
		else
			echo "应用本地规则 ${LINE}"
			echo -e $(echo -e "${LINE}" | cut -d "," -f2- | sed 's/\[]//g'),"${GROUP}" >>${RULES}
		fi
		# }&
	done
	# multi_process_kill  "$(basename $0)"

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


function request_body_create() {
  # 生成请求结构体 - 新建
  cat > "${DESC_JSON}" <<EOF
{
 "description":"clash config by cloudflare speedtest",
 "public": false,
 "files": {
   "${REMOTE_NAME}": {
     "content":"${CONTENT}"
    }
  }
}
EOF
}

function request_body_update() {
  # 生成请求结构体 - 更新
  cat > "${DESC_JSON}" <<EOF
{
 "description":"clash config by cloudflare speedtest",
 "public": false,
 "gist_id": "${GIST_ID}",
 "files": {
   "${REMOTE_NAME}": {
     "content":"${CONTENT}"
    }
  }
}
EOF
}

function gist() {
	local ACTION=$1

	if [[ "$ACTION" == 'create' || "$ACTION" == 'update'  ]]; then
		CONTENT=$(cat ${CLASH_CONFIG} | awk '{print $0"\\n"}')
	fi

	if [[ "$ACTION" == 'create' ]]; then
		request_body_create
		curl -s -H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GIST_TOKEN}" \
		-d @"${DESC_JSON}" \
		-X POST https://api.github.com/gists >${RESPONSE} 2>&1
	elif [[ "$ACTION" == 'update' ]]; then
		request_body_update
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
	local RAW_URL=$(cat "${RESPONSE}" | grep raw_url | awk -F"\"" '{print $4}')
	local COMMIT_ID=$(echo -e ${RAW_URL} | awk -F"/" '{print $(NF-1)}')
	echo -e "${RAW_URL}" | sed "s/${COMMIT_ID}\///g"
}

function update_status() {
	local GIST_URL="$(get_gist_url)"
	if [[ -n "${GIST_URL}" ]]; then
		echo -e "gist上传成功： ${GIST_URL}"
		GIST_NEW_ID=$(echo -e "${GIST_URL}" | awk -F "/" '{print $(NF-2)}')
		if [[ "${GIST_ID}" != "${GIST_NEW_ID}" ]]; then
			echo -e "更新GIST_ID${GIST_ID}为： ${GIST_NEW_ID} 下次运行生效"
			sed -i "s/GIST_ID\=${GIST_ID}.*/GIST_ID\=${GIST_NEW_ID}/g" "${BASEPATH}"/$(basename $0)
		fi

	else
		echo -e "未收到正确的返回信息，gist可能上传失败"
		echo -e $(cat "${RESPONSE}")
	fi
}

function cron_job() {
	local USER=$USER
	local CRON_PATH='/var/spool/cron/crontabs'

	local RE=$(`which sudo` sh -c "if [[ -d ${CRON_PATH} ]]; then echo yes; else echo no;fi")
	if [[ ${RE} == 'no' ]]; then local CRON_PATH='/var/spool/cron'; fi

	`which sudo` sh -c "sed -i '/$(basename $0)/d' ${CRON_PATH}/$USER"
	crontab -l | { cat; echo -e "${SCHEDULE} ${BASEPATH}/$(basename $0) ${PLATFORM} >${BASEPATH}/$(basename $0).log 2>&1"; } | crontab -
}

BASEPATH=$(cd `dirname $0`; pwd)
START_TIME=$(date +%s)
echo -e "预计耗时2-3分钟，请耐心等待"
echo -e "开始测试丢包率	$(date -R -d @${START_TIME})"
CF_IP_LIST=$(get_cf_ip_list)
RESULT_LIST=$(pack_loss_test "${CF_IP_LIST}")
echo -e "${RESULT_LIST}" | sort -n
echo -e "丢包率测试完成!"

echo -e "开始根据丢包率为零的IP生成clash配置文件"
RESULT_LIST=$(echo -e "${RESULT_LIST}" | sort -n | head -n ${TARGET_IPS} | awk '{print ($NF)}')
echo "proxies:" >"${POOL}"
i=1
echo -e "${RESULT_LIST}" | while read LINE && [[ -n "${RESULT_LIST}" ]]
do
	pool_generate "${LINE}" "${i}" >>"${POOL}"
	let i++
done
unset i
END_TIME=$(date +%s)
echo -e "根据公网IP $(cat /tmp/public_ip.txt) 解析出cloudflare CDN加速IP池" && rm -f /tmp/public_ip.txt
echo -e "按要求筛选出 $(($(cat ${POOL} | wc -l) -1)) 个优选IP, 生成的代理池文件保存在： ${POOL}"
echo -e "按照丢包率筛选CF优选IP任务完成, 耗时 $(( ${END_TIME} - ${START_TIME} )) 秒\
	$(date -R -d @${END_TIME})"


################ 转换clash规则开始 ####################
if [[ "${CLASH_ENABLE}" == 'yes' ]]; then
	START_TIME2=$(date +%s)
	echo -e "开始加入clash规则并转换 $(date -R -d @${END_TIME})"
	if [[ -n "${PREF_INI_URL}" ]]; then
		curl -L -s "${PREF_INI_URL}" | sed "s/https:\/\/raw.githubusercontent/https:\/\/ghproxy.com\/https:\/\/raw.githubusercontent/g" \
		> "${PREF_INI}"
	fi
	clash_config "${PREF_INI}"

	END_TIME=$(date +%s)
	echo -e "clash规则转换完成, 耗时 $((${END_TIME} - ${START_TIME2})) 秒"
	echo -e "转换后的Clash配置文件保存在： ${CLASH_CONFIG}"
	echo -e "任务完成, 总耗时 $((${END_TIME} - ${START_TIME})) 秒	$(date -R -d @${END_TIME})"
fi
################ 转换clash规则完成 ####################

################ 上传到 gist 开始 ####################
if [[ -n "${GIST_TOKEN}" ]]; then
	if [[ -n "${GIST_ID}" ]]; then
		gist 'info'
		GIST_URL=$(get_gist_url)
		if [[ -n "${GIST_URL}" ]]; then
			echo -e "gist远程文件已经存在： ${GIST_URL}"
			echo -e "准备提交更新"
			gist update
			update_status
		fi
	else
		echo -e "gist远程文件不存在"
		echo -e "准备全新提交"
		gist create
		update_status
	fi
fi
################ 上传到 gist 完成 ####################

################ 梅林Merlin路由器  ############
if [[ "${PLATFORM}" == 'merlin' ]]; then
	clashconfig=/jffs/.koolshare/merlinclash/clashconfig.sh
	if [[ ! -x "$clashconfig" ]]; then exit 0; fi
	source $clashconfig
	
	cp -f  ${CLASH_CONFIG} /tmp/upload/
	merlinclash_uploadfilename="$(echo -e "${CLASH_CONFIG}" | awk -F "/" '{print $(NF)}')"
	move_config
	echo "==========================="
	cat $LOG_FILE | tail -n 11

	echo "==========================="
	echo "开始重启 Clash 进程并显示日志"
	sync
	echo 1 > /proc/sys/vm/drop_caches
	sleep 1s
	sh /koolshare/merlinclash/clashconfig.sh restart >/dev/null 2>&1 &
    	cat $LOG_FILE
fi

################ OpenWRT路由器 ##############
if [[ "${PLATFORM}" == 'openwrt' ]]; then
	if [[ "${CLASH_ENABLE}" == 'yes' ]]; then
		echo -e "开始写入clash配置"
		cp -f  ${CLASH_CONFIG} /etc/openclash/config/
		/etc/init.d/openclash restart
		echo -e "clash配置写入完成"
	fi
	if [[ "${PASSWALL_ENABLE}" == 'yes' ]]; then
		echo -e "开始写入passwall配置"
		passwall_config
		if [[ $? -eq 0 ]]; then
			echo -e "passwall配置写入完成"
			uci show passwall | grep address=
			/etc/init.d/haproxy restart
			/etc/init.d/passwall restart
		else
			echo -e "passwall配置写入失败"
		fi
	fi
fi

################ VPS自建服务器 ##############
if [[ "${PLATFORM}" == 'vps' ]]; then
	`which sudo` sh -c "cp -f  ${CLASH_CONFIG} ${WWW_PATH}"
fi

echo "开始创建计划任务 ${SCHEDULE}"
cron_job
echo "计划任务更新完成 ${SCHEDULE}"
crontab -l | grep $(basename $0)

# 清空临时文件
if [[ -n "${PLATFORM}" ]]; then
	rm -f "${PREF_INI}"
	rm -f "${POOL}"
	rm -f "${CLASH_CONFIG}"
	rm -f "${DESC_JSON}"
	rm -f "${RESPONSE}"
fi

exit 0
