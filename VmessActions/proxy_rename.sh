#!/bin/bash

#POOL=$1
#FINAL_POOL=$2
#LOCATION=VmessActions/location.txt


# 验证IP是否非法
check_ip() {
	IP=$1
	VALID_CHECK=$(echo ${IP} \
		| awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
	
	RULE="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
	if echo ${IP} | grep -E ${RULE}>/dev/null; 
	then
		if [ ${VALID_CHECK:-no} == "yes" ]; then
			echo "IP ${IP} available."
		else
			echo "IP ${IP} not available!"
		fi
	else
		echo "IP format error!"	
	fi
	
	unset IP
	unset VALID_CHECK
	unset RULE
}

# 根据国家和地区名获取地域代码
countrycode() {
	CODE=VmessActions/code.csv
	echo -e $(cat ${CODE} | grep -P "\t$1\t" | awk -F"\t" '{print $1}')
}

# 远程获取单IP地域信息
location_remote() {
	URL=http://ip-api.com/json
	LANG='zh-CN'
	
	# Taobao API
	URL2=https://ip.taobao.com/outGetIpInfo\?ip\=
	KEY=alibaba-inc


	JSON=$(curl -s --connect-timeout 1 -m 2 -X GET ${URL}/$1\?lang\=$LANG)
	if [[ -z ${JSON} ]]; then
		JSON=$(curl -s -X POST ${URL2}$1\&accessKey\=${KEY})
		if [[ -z ${JSON} ]]; then
			echo -e 未知\|\|\|\|
			return
		fi
	fi

	COUNTRY=$(echo ${JSON} | awk -F"\"country\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	REGION=$(echo ${JSON} | awk -F"\"region\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	REGIONNAME=$(echo ${JSON} | awk -F"\"regionName\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	CITY=$(echo ${JSON} | awk -F"\"city\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	ISP=$(echo ${JSON} | awk -F"\"isp\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
		
	echo -e ${COUNTRY}\|${REGION}\|${REGIONNAME}\|${CITY}\|${ISP}

	unset URL
	unset LANG
	unset URL2
	unset KEY
	unset JSON
	unset COUNTRY
	unset REGION
	unset REGIONNAME
	unset CITY
	unset ISP
}

# 获取单个IP地域信息
patch_location() {
	DOMAIN=8.8.8.8

	IP1=$1
	if [[ $(check_ip $1 ${DOMAIN}) != "IP $1 available." ]]; then
		IP1=$(nslookup $1 |egrep 'Address:'|awk '{if(NR==2) print $NF}')
	fi

	#从本地IP数据库拉取
	IPREGION=$(./VmessActions/search -d VmessActions/ip2region.db -i ${IP1})
	if [[ ${IPREGION} != '0|0|0|内网IP|内网IP' && ${IPREGION} ]]; then
		echo -e $1\|${IPREGION}
		return
	fi

	#本地IP数据库不存在，从远程拉取
	echo -e $1\|$(location_remote ${IP1})

	unset DOMAIN
	unset IP1
	unset IPREGION
}

# 获取缺失国家地区选项的代理节点清单
missed_pool() {
	cat $1 | grep -v country | awk -F '\"server\":' '{print $2}' \
		  | awk -F',' '{print $1}' | sed 's/\"//g' | sort | uniq \
		  | sed -r '/^\s*$/d'
}

# 获取全部代理节点
# $1 - 代理节点列表
pool() {
	cat $1 | awk -F '\"server\":' '{print $2}' \
		  | awk -F',' '{print $1}' | sed 's/\"//g' | sort | uniq \
		  | sed -r '/^\s*$/d'
}

# 批量获取所有IP地域信息并写入文件
# $1 - 代理节点列表 $2 - LOCATION文件
location() {
	if [ ! -r $1 ]; then echo $1 不存在; return; fi
	rm -f $2 && touch $2
	pool $1 | while read line || [[ -n ${line} ]]
	do
		{
		IPDATA=$(patch_location ${line})
		COUNTRY=$(echo $IPDATA | awk -F"|" '{print $2}')
		CODE=$(countrycode $COUNTRY)

		if [[ $CODE == "CN" && $(echo ${IPDATA} | grep 台湾) ]]
		then
			CODE='TW'
		fi
		if [[ $CODE == "CN" && $(echo ${IPDATA} | grep 香港) ]]
		then
			CODE='HK'
		fi
		if [[ $CODE == "CN" && $(echo ${IPDATA} | grep 澳门) ]]
		then
			CODE='MO'
		fi

		echo -e $CODE\|${IPDATA} >>$2
		}&
	done
	wait

	unset IPDATA
	unset COUNTRY
	unset CODE
}

# 单行重命名
pool_rename_line() {

	LINE=$(echo $* | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')

	if [ $(echo ${LINE} | awk -F" " '{print $1}') != '-' ]; then
		NEW_LINE=${LINE}
	else
		SERVER=$(echo ${LINE} | awk -F"\"server\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')
		COUNTRY=$(echo ${LINE} | awk -F"\"country\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')
		NAME=$(echo ${LINE} | awk -F"\"name\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')

		NEW_NAME=$(cat ${LOCATION} | grep -e "|${SERVER}|" \
			| cut -d "|" -f1,3- | sed "s/\0|//g" | sed "s/|0//g")

		# 修正国家代码
		CODE=$(cat ${LOCATION} | grep -e "|${SERVER}|" | cut -d "|" -f1)

		if [[ -z $(echo ${LINE} | grep "\"country\":") ]]; then
			LINE=$(echo ${LINE} \
				| sed -e "s/.$/,\"country\":\"${CODE}\"\}/g")
		else
			LINE=$(echo ${LINE} | sed "s/\"country\":\"${COUNTRY}/\
				\"country\":\"${CODE}/g")
		fi
		NEW_LINE=$(echo $LINE \
		  | sed "s/\"name\":\"${NAME}/\"name\":\"${NEW_NAME}/g")
	fi
	
	echo ${NEW_LINE}
	
	unset LINE
	unset SERVER
	unset COUNTRY
	unset NAME
	unset NEW_NAME
	unset CODE
	unset NEW_LINE
}


# 根据地域批量节点服务器重命名
pool_rename() {
	cat $1 | while read line || [[ -n ${line} ]]
	do
		LINE=$(pool_rename_line ${line})

		NAME=$(echo ${LINE} | awk -F"\"name\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')
		
		local i=$(($(cat /tmp/total_nodes) + 1))
		NEW_LINE=$(echo ${LINE} \
		  | sed "s/\"name\":\"${NAME}/\"name\":\"${NAME}\|$[i]\|/g")

		echo ${NEW_LINE} >> $2
		echo $[i] >/tmp/total_nodes
	done
	
	unset LINE
	unset NAME
	unset NEW_LINE
}


# 代理节点重命名 -- 多线程 -- 堵塞
# $1 - 输出配置文件 $2 - 每个进程最大处理行数设定 
multi_pool_rename_pid() {
	TOTAL=$(cat $1 | wc -l)
	m=$3
	n=$(expr $[TOTAL] / $[m] + 1)

	START_TIME=$(date +%s)

	cat 0 >/tmp/total_nodes
	TEMP=tmp
	rm -rf ${TEMP}
	mkdir ${TEMP}
	for (( i=1; i<=$n; i++))
	do
		begin=$(($[i] * $[m] - $[m] + 1))
		if [ $i == $n ]; then
			end=$[TOTAL]
		else
			end=$(($[i] * $[m]))
		fi

		cat $1 | sed -n "$[begin],$[end]p" > ${TEMP}/$i.yaml
		arry[$[i]]=$(pool_rename ${TEMP}/$[i].yaml ${TEMP}/FINAL-$[i].yaml) &
	done

	wait

	local i=1
	#echo "proxies:" > $1 
	while [ $[i] -le $[n] ]
	do
		cat ${TEMP}/FINAL-$[i].yaml >> $2
		let local i++
	done

	rm -rf ${TEMP}
	
	STOP_TIME=$(date +%s)
	echo -e "节点重命名总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"

	unset TOTAL
	unset m
	unset n
	unset START_TIME
	unset TEMP
	unset local i
	unset STOP_TIME
}


# 代理节点重命名 -- 多线程 -- 队列非堵塞
# $1 - 源配置文件 $2 - 目标配置文件 $3 - 每个线程队列数最大处理数
multi_pool_rename_fd() {
	m=$3
	cat 0 >/tmp/total_nodes

	START_TIME=$(date +%s)
	[ -e /tmp/fd1 ] || mkfifo /tmp/fd1
	exec 3<>/tmp/fd1
	rm -rf /tmp/fd1
	for ((i=1; i<=$m; i++))
	do
		echo >&3
	done

	cat $1 | while read line || [[ -n ${line} ]]
	do
		read -u 3
		{
			LINE=$(pool_rename_line ${line})
			NAME=$(echo $LINE | awk -F"\"name\":" '{print $2}' \
				| awk -F"," '{print $1}'| sed 's/\"//g')
			
			local i=$(($(cat /tmp/total_nodes) + 1))
			NEW_LINE=$(echo $LINE \
				| sed "s/\"name\":\"${NAME}/\"name\":\
				\"${NAME}\|$i\|/g")
			
			echo ${NEW_LINE} >> $2
			echo $[i] >/tmp/total_nodes
			
			echo >&3
		}&
	done
	wait

	STOP_TIME=$(date +%s)

	echo -e "总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"
	exec 3<&-
	exec 3>&-
	
	unset m
	unset START_TIME
	unset local i
	unset LINE
	unset NAME
	unset NEW_LINE
	unset STOP_TIME

}

# 节点重命名速度测试
rename_speed_test() {
	for ((i=$2; i<$3; i++))
	do
		if [ $1 == 1 ]; then
			n=$[(($[i] * 100 + 100))]
			echo -e "重命名算法一:参数 $[n]"
			echo -e "$(multi_pool_rename_pid $FINAL_POOL $[n])"
		elif [ $1 == 2 ]; then
			n=$[(($[i] * 10 + 10))]
			echo -e "重命名算法二:参数 $[n]"
			echo -e "$(multi_pool_rename_fd ${POOL} $FINAL_POOL $[n])"
		else
			echo -e "参数 $[$1] 错误"
			break
		fi
	done

	unset i
	unset n
}


# 得到IP地域文件
#START_TIME=$(date +%s)
#location ${POOL} ${LOCATION}
#STOP_TIME=$(date +%s)
#echo -e "查询IP地域总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"

# rename_speed_test 1 0 1

#multi_pool_rename_pid ${POOL} ${FINAL_POOL} 900
#multi_pool_rename_fd ${POOL} ${FINAL_POOL} 30

#exit 0
