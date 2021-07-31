#!/bin/bash

#LPOOL=$1
#FINAL_POOL=$2

#LPOOL=VmessActions/subscribe/latest_pool.yaml
#FINAL_POOL=VmessActions/subscribe/valid_pool.yaml
TEMP_DIR=tmp

GITHUB='https/github.com'
OS='linux-amd64'
USER='Dreamacro'
APP='clash'
REPO=$USER/$APP
FILE=$APP.gz
PROXY_URL='https://lingering-math-d2ca.hansyow.workers.dev/'

get_latest_release() {
  curl --silent "${PROXY_URL}https/api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}
VERSION=$(get_latest_release $REPO)


get_clash() {
 
	CLASH=`pwd`/clash
	if [ -e ${CLASH} ]; then
		echo ${CLASH}
		unset CLASH
		return
	fi

        curl -L -s ${PROXY_URL}${GITHUB}/${USER}/${APP}/releases/download/${VERSION}/${APP}-${OS}-${VERSION}.gz -o ${FILE}
        gzip -d ${FILE}
		chmod 755 clash

	unset CLASH
}

clash_help() {
	echo "how to manage clash:"
	echo "clash start config pid"
	echo "clash restart config pid"
	echo "clash stop config pid"
}

clash() {
	LOG=/dev/null
	CLASH=$(get_clash)
	
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

# generate single config file
# $1: PORT	$2: config line	$3: config file
config() {

	NAME=$(echo $2 | awk -F"\"name\":" '{print $2}' | awk -F"," '{print $1}'| sed 's/\"//g')

	cat >$3 <<EOL
socks-port: $1
allow-lan: true
mode: Rule
log-level: silent
proxies:
$2
proxy-groups:
  - name: 🐟 全局
    type: select
    proxies:
      - ${NAME}

rules:
  - MATCH,🐟 全局
EOL

	unset NAME
}

check_port() {
	CHECK=$(lsof -i :$1 | awk '{print $1 " "  $2}')
	if [[ -z ${CHECK} ]]; then
		echo -e "no"
	else
		echo -e "yes"
	fi

	unset CHECK
}

isconnected() {
	PORT=$1
	CONFIG=$2
	PID=${TEMP_DIR}/${PORT}.pid

	PROXY=socks5h://127.0.0.1:$[PORT]
	GEN_204=https://www.gstatic.com/generate_204 
	
	# check if port is available
	if [ $(check_port $[PORT]) == 'no' ]; then
		clash start ${CONFIG} ${PID}

	else
		echo -e "PORT $[PORT] is in use"
		return
	fi

	# recheck PORT status after clash start
	n=0
	while : 
	do
		CHECK=$(check_port $[PORT])
		if [[ ${CHECK} == 'yes' || $[n] -gt 5 ]]; then
			break
		fi
		let n++
	done
	if [[ $[n] -gt 5 ]]; then
		echo -e "${PORT} failed"
		return
	fi

	# check conneciton status
	RESULT=$(curl --connect-timeout 1 -m 2 -x ${PROXY} -s -L -i ${GEN_204}| head -n 1 | grep 204)
	if [[ -z ${RESULT} ]]; then
		echo -e "no"
	else
		echo -e "yes"
	fi
	
	if [ ! -e ${TEMP_DIR}/${PORT}.pid ]; then 
		kill -9 $(ps axu | grep "${TEMP_DIR}/${PORT}.pid" | grep -v exclude | awk '{print $2}')
	else
		clash stop "$2" "${TEMP_DIR}/${PORT}.pid"
	fi
	
	unset PID
	unset PORT
	unset CONFIG
	unset GEN_204
	unset PID
	unset n
	unset CHECK
	unset RESULT
}

pool_validate() {
	for ((i=$3; i<$4; i++))
	do
		LINE=$(cat $1 | sed -n "$[i]p")
		if [[ -z $(echo ${LINE} | grep "\- {") ]]; then
			continue
		fi
		{
		# generate config file for each node
		PORT=$[i]
		PORT=$((8000 + $[i]))
		CONFIG=${TEMP_DIR}/${PORT}.yaml
		config "${PORT}" "${LINE}" "${CONFIG}"

		# validate connection availabe status
		if [[ $(isconnected "${PORT}" "${CONFIG}") == 'yes' ]]; then
			echo ${LINE} >> $2
		fi
		}&
	done
	wait

	unset LINE
	unset i
	unset PORT
	unset CONFIG
	unset PID
}

pool_validate_fd() {

	START_TIME=$(date +%s)
	rm -rf $2
	rm -rf ${TEMP_DIR} && mkdir ${TEMP_DIR}
	echo 'proxies:' >$2

	[ -e /tmp/fd1 ] || mkfifo /tmp/fd1
	exec 3<>/tmp/fd1
	rm -rf /tmp/fd1
	for ((i=1; i<=$[$3]; i++))
	do
		echo >&3
	done
	i=1
	cat $1 | while read line || [[ -n ${line} ]]
	do
		read -u 3

		if [[ -z $(echo ${line} | grep "\- {") ]]; then
			continue
		fi
		{
			# generate config file for each node
			PORT=$((8000 + $[i]))
			CONFIG=${TEMP_DIR}/${PORT}.yaml
			config "${PORT}" "${line}" "${CONFIG}"

			# validate connection availabe status
			if [[ $(isconnected "${PORT}" "${CONFIG}") == 'yes' ]];
			then 
				echo ${line} >> $2
			fi
			echo >&3
		}&
		let i++
		
	done

	wait

	#rm -rf ${TEMP_DIR}

	STOP_TIME=$(date +%s)
	echo -e "可用节点检测总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"
	exec 3<&-
	exec 3>&-

	unset START_TIME
	unset STOP_TIME
	unset i
	unset PORT
	unset CONFIG
}

pool_validate_pid() {

	TOTAL=$(cat $1 | wc -l)
	m=$3
	z=$(expr $TOTAL / $m + 1)

	START_TIME=$(date +%s)

	rm -rf ${TEMP_DIR} && mkdir ${TEMP_DIR}
	rm -rf $2
	echo 'proxies:' >$2

	for (( i=1; i<=$z; i++))
	do
		begin=$(($i * $m - $m + 1))
		if [ $i == $z ]; then
			end=$TOTAL
		else
			end=$(($i * $m))
		fi
		pool_validate $1 $2 $[begin] $[end]
	done

	wait

	#rm -rf ${TEMP_DIR}
	
	STOP_TIME=$(date +%s)
	echo -e "可用节点检测总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"
	
	unset begin
	unset end
	unset STOP_TIME
	unset START_TIME
	unset m
	unset z
	unset TOTAL
}


#get_clash
#pool_validate_pid $1 $2 20
#pool_validate_fd $1 $2 800
