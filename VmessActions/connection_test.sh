#!/bin/bash

POOL=$1
FINAL_POOL=$2

#POOL=VmessActions/subscribe/latest_pool.yaml
#FINAL_POOL=VmessActions/subscribe/valid_pool.yaml
CLASH=${HOME}/go/bin/clash
TEMP=tmp

get_clash() {
        GO_VERSION=1.168.6
	GO_TAR=go.tar.gz
        GO=`pwd`/go/bin/go
        curl -L -s https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz -o ${GO_TAR}
        tar -xvf ${GO_TAR} >/dev/null
        ${GO} install github.com/Dreamacro/clash@latest
	ulimit -u unlimited
	ulimit -n 65536
}

clash_help() {
	echo "how to manage clash:"
	echo "clash start config pid"
	echo "clash restart config pid"
	echo "clash stop config pid"
}

clash() {
	CONFIG=$2
	PID=$3
	LOG=/dev/null
	if [[ $1 == 'start' && $2 == ${CONFIG} ]]; then
		nohup ${CLASH} -f ${CONFIG} > ${LOG} 2>&1 &
		echo "$!" > ${PID}
	elif [[ $1 == 'stop' && $2 == ${CONFIG} ]]; then
		kill `cat ${PID}`
	elif [[ $1 == 'restart' && $2 == ${CONFIG} ]]; then
		kill `cat ${PID}`
		nohup ${CLASH} -f ${CONFIG} > ${LOG} 2>&1 &
		echo "$!" > ${PID}
	else
		clash_help
	fi
}

# generate single config file
# $1: PORT	$2: config line	$3: config file
config() {
	PORT=$1
	LINE=$2
	CONFIG=$3

	NAME=$(echo ${LINE} | awk -F"\"name\":" '{print $2}' | awk -F"," '{print $1}'| sed 's/\"//g')

	cat >${CONFIG} <<EOL
socks-port: ${PORT}
allow-lan: true
mode: Rule
log-level: silent
proxies:
${LINE}
proxy-groups:
  - name: 🐟 全局
    type: select
    proxies:
      - ${NAME}

rules:
  - MATCH,🐟 全局
EOL

}

check_port() {
	CHECK=$(sudo lsof -i :$1 | awk '{print $1 " "  $2}')
	if [[ -z ${CHECK} ]]; then
		echo -e "no"
	else
		echo -e "yes"
	fi
}

isconnected() {
	PORT=$1
	CONFIG=$2
	PROXY=socks5h://127.0.0.1:$[PORT]
	GEN_204=https://www.gstatic.com/generate_204 
	PID=${TEMP}/${PORT}.pid

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
	
	clash stop ${CONFIG} ${PID}
}

pool_validate() {
	POOL=$1
	for ((k=$2; k<$3; k++))
	do
		LINE=$(cat ${POOL} | sed -n "$[k]p")
		if [[ -z $(echo ${LINE} | grep "\- {") ]]; then
			continue
		fi
		{
		# generate config file for each node
		PORT=$[k]
		PORT=$((8000 + $[k]))
		CONFIG=${TEMP}/${PORT}.yaml
		config "${PORT}" "${LINE}" "${CONFIG}"

		# validate connection availabe status
		if [[ $(isconnected "${PORT}" "${CONFIG}") == 'yes' ]]; then
			echo ${LINE} >> ${FINAL_POOL}
		fi
		}&
	done
	wait
}

pool_validate_fd() {

	m=$1

	START_TIME=$(date +%s)
	rm -rf ${FINAL_POOL}
	rm -rf $TEMP && mkdir $TEMP
	echo 'proxies:' >${FINAL_POOL}

	[ -e /tmp/fd1 ] || mkfifo /tmp/fd1
	exec 3<>/tmp/fd1
	rm -rf /tmp/fd1
	for ((i=1; i<=$m; i++))
	do
		echo >&3
	done
	i=1
	cat ${POOL} | while read line || [[ -n ${line} ]]
	do
		read -u 3

		if [[ -z $(echo ${line} | grep "\- {") ]]; then
			continue
		fi
		{
			# generate config file for each node
			PORT=$((8000 + $[i]))
			CONFIG=${TEMP}/${PORT}.yaml
			config "${PORT}" "${line}" "${CONFIG}"

			# validate connection availabe status
			if [[ $(isconnected "${PORT}" "${CONFIG}") == 'yes' ]];
			then 
				echo ${line} >> ${FINAL_POOL}
			fi
			echo >&3
		}&
		let i++
		
	done

	wait

	#rm -rf $TEMP

	STOP_TIME=$(date +%s)
	echo -e "可用节点检测总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"
	exec 3<&-
	exec 3>&-
}

pool_validate_pid() {

	TOTAL=$(cat $POOL | wc -l)
	m=$1
	z=$(expr $TOTAL / $m + 1)

	START_TIME=$(date +%s)

	rm -rf $TEMP && mkdir $TEMP
	rm -rf ${FINAL_POOL}
	echo 'proxies:' >${FINAL_POOL}


	for (( i=1; i<=$z; i++))
	do
		begin=$(($i * $m - $m + 1))
		if [ $i == $z ]; then
			end=$TOTAL
		else
			end=$(($i * $m))
		fi
		pool_validate ${POOL} $[begin] $[end]
	done

	wait

	#rm -rf $TEMP
	
	STOP_TIME=$(date +%s)
	echo -e "可用节点检测总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"
}


#pool_validate_pid 20

pool_validate_fd 800
