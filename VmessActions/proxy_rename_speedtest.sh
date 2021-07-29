#!/bin/bash

POOL=VmessActions/subscribe/latest_pool.yaml
FINAL_POOL=VmessActions/subscribe/pool.yaml

#POOL=$1
#FINAL_POOL=$2
LOCATION=VmessActions/location.txt


# 验证IP是否非法
check_ip() {
	IP=$1
	VALID_CHECK=$(echo $IP \
		| awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
	
	RULE="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
	if echo $IP | grep -E $RULE>/dev/null; 
	then
		if [ ${VALID_CHECK:-no} == "yes" ]; then
			echo "IP $IP available."
		else
			echo "IP $IP not available!"
		fi
	else
		echo "IP format error!"	
	fi	
}

# 根据国家和地区名获取地域代码
countrycode() {
	CODE=VmessActions/code.csv
	echo -e $(cat $CODE | grep -P "\t$1\t" | awk -F"\t" '{print $1}')
}

# 远程获取单IP地域信息
location_remote() {
	URL=http://ip-api.com/json
	LANG='zh-CN'
	
	# Taobao API
	URL2=https://ip.taobao.com/outGetIpInfo\?ip\=
	KEY=alibaba-inc


	JSON=$(curl -s --connect-timeout 1 -m 2 -X GET $URL/$1\?lang\=$LANG)
	if [[ -z $JSON ]]; then
		JSON=$(curl -s -X POST $URL2$1\&accessKey\=$KEY)
		if [[ -z $JSON ]]; then
			echo -e 未知\|\|\|\|
			return
		fi
	fi

	COUNTRY=$(echo $JSON | awk -F"\"country\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	REGION=$(echo $JSON | awk -F"\"region\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	REGIONNAME=$(echo $JSON | awk -F"\"regionName\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	CITY=$(echo $JSON | awk -F"\"city\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
	ISP=$(echo $JSON | awk -F"\"isp\":" '{print $2}' \
		| awk -F"," '{print $1}' | sed 's/\"//g')
		
	echo -e $COUNTRY\|$REGION\|$REGIONNAME\|$CITY\|$ISP
}

# 获取单个IP地域信息
patch_location() {
	DOMAIN=8.8.8.8

	IP1=$1
	if [[ $(check_ip $1 $DOMAIN) != "IP $1 available." ]]; then
		IP1=$(nslookup $1 |egrep 'Address:'|awk '{if(NR==2) print $NF}')
	fi

	#从本地IP数据库拉取
	IPREGION=$(./VmessActions/search -d VmessActions/ip2region.db -i $IP1)
	if [[ ${IPREGION} != '0|0|0|内网IP|内网IP' && ${IPREGION} ]]; then
		echo -e $1\|${IPREGION}
		return
	fi

	#本地IP数据库不存在，从远程拉取
	echo -e $1\|$(location_remote $IP1)
}

# 获取缺失国家地区选项的代理节点清单
missed_pool() {
	cat $POOL | grep -v country | awk -F '\"server\":' '{print $2}' \
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
	if [ ! -s $2 ]; then touch $2; fi
	pool $1 | while read line || [[ -n ${line} ]]
	do
		if [[ $(cat $2 | grep -P "\|${line}\|") ]]; then
			continue
		fi

		IPDATA=$(patch_location ${line})
		COUNTRY=$(echo $IPDATA | awk -F"|" '{print $2}')
		CODE=$(countrycode $COUNTRY)

		if [[ $CODE == "CN" && $(echo $IPDATA | grep 台湾) ]]; then
			CODE='TW'
		fi
		if [[ $CODE == "CN" && $(echo $IPDATA | grep 香港) ]]; then
			CODE='HK'
		fi
		if [[ $CODE == "CN" && $(echo $IPDATA | grep 澳门) ]]; then
			CODE='MO'
		fi


		echo -e $CODE\|$IPDATA >>$2
	done 
}

# 根据地域为节点服务器重命名
pool_rename() {
	i=0
	cat $1 | while read line || [[ -n ${line} ]]
	do
		LINE=$(echo ${line} | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')

		if [ $(echo $LINE | awk -F" " '{print $1}') != '-' ]; then
			NEW_LINE=$LINE
			continue
		fi

		SERVER=$(echo $LINE | awk -F"\"server\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')
		COUNTRY=$(echo $LINE | awk -F"\"country\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')
		NAME=$(echo $LINE | awk -F"\"name\":" '{print $2}' \
			| awk -F"," '{print $1}'| sed 's/\"//g')

		NEW_NAME=$(cat $LOCATION | grep -e "|${SERVER}|" \
			| cut -d "|" -f1,3- | sed "s/\0|//g" | sed "s/|0//g")

		# 修正国家代码
		CODE=$(cat ${LOCATION} | grep -e "|${SERVER}|" | cut -d "|" -f1)

		if [[ -z $(echo $LINE | grep "\"country\":") ]]; then
			LINE=$(echo $LINE \
				| sed -e "s/.$/,\"country\":\"$CODE\"\}/g")
		else
			LINE=$(echo $LINE | sed "s/\"country\":\"${COUNTRY}/\
				\"country\":\"${CODE}/g")
		fi
		
		let i++
		NEW_LINE=$(echo $LINE \
		  | sed "s/\"name\":\"${NAME}/\"name\":\"${NEW_NAME}\|$i\|/g")

		echo ${NEW_LINE} >> $2
	done
}


# 代理节点重命名 -- 多线程 -- 堵塞
# $1 - 输出配置文件 $2 - 每个进程最大处理行数设定 
multi_pool_rename_pid() {
	TOTAL=$(cat $POOL | wc -l)
	m=$2
	n=$(expr $TOTAL / $m + 1)

	START_TIME=$(date +%s)


	TEMP=tmp
	rm -rf $TEMP
	mkdir $TEMP
	for (( i=1; i<=$n; i++))
	do
		begin=$(($i * $m - $m + 1))
		if [ $i == $n ]; then
			end=$TOTAL
		else
			end=$(($i * $m))
		fi

		cat $POOL | sed -n "$[begin],$[end]p" > $TEMP/$i.yaml
		arry[$[i]]=$(pool_rename $TEMP/$i.yaml $TEMP/FINAL-$i.yaml) &
	done

	wait

	i=1
	echo "proxies:" > $1 
	while [ $i -le $n ]
	do
		cat $TEMP/FINAL-$i.yaml >> $1
		let i++
	done

	rm -rf $TEMP
	
	STOP_TIME=$(date +%s)
	echo -e "总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"

}


# 代理节点重命名 -- 多线程 -- 队列非堵塞
# $1 - 源配置文件 $2 - 目标配置文件 $3 - 每个线程队列数最大处理数
multi_pool_rename_fd() {
	m=$3

	START_TIME=$(date +%s)
	[ -e /tmp/fd1 ] || mkfifo /tmp/fd1
	exec 3<>/tmp/fd1
	rm -rf /tmp/fd1
	for ((i=1; i<=$m; i++))
	do
		echo >&3
	done

	i=0
	cat $1 | while read line || [[ -n ${line} ]]
	do
		read -u 3
		let i++
		{
			LINE=$(echo ${line} | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')

			if [ $(echo $LINE | awk -F" " '{print $1}') != '-' ]; then
				NEW_LINE=$LINE
			else
				SERVER=$(echo $LINE | awk -F"\"server\":" '{print $2}' \
					| awk -F"," '{print $1}'| sed 's/\"//g')
				COUNTRY=$(echo $LINE | awk -F"\"country\":" '{print $2}' \
					| awk -F"," '{print $1}'| sed 's/\"//g')
				NAME=$(echo $LINE | awk -F"\"name\":" '{print $2}' \
					| awk -F"," '{print $1}'| sed 's/\"//g')

				NEW_NAME=$(cat $LOCATION | grep -e "|${SERVER}|" \
					| cut -d "|" -f1,3- | sed "s/\0|//g" | sed "s/|0//g")

				# 修正国家代码
				CODE=$(cat ${LOCATION} | grep -e "|${SERVER}|" | cut -d "|" -f1)

				if [[ -z $(echo $LINE | grep "\"country\":") ]]; then
					LINE=$(echo $LINE \
						| sed -e "s/.$/,\"country\":\"$CODE\"\}/g")
				else
					LINE=$(echo $LINE | sed "s/\"country\":\"${COUNTRY}/\
						\"country\":\"${CODE}/g")
				fi
				
				NEW_LINE=$(echo $LINE \
				  | sed "s/\"name\":\"${NAME}/\"name\":\"${NEW_NAME}\|$[i]\|/g")
			fi

			echo ${NEW_LINE} >> $2

			echo >&3
		}&
	done
	wait

	STOP_TIME=$(date +%s)

	echo -e "总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"
	exec 3<&-
	exec 3>&-
}


# 得到IP地域文件
#location $POOL $LOCATION

# 代理池按照地域改名
for ((x=0; x<20; x++))
do
	n=$[(($[x] * 100 + 100))]
	echo -e "参数 $[n] $(multi_pool_rename_pid $FINAL_POOL $[n])"
done
#multi_pool_rename_pid $FINAL_POOL 500
#multi_pool_rename_fd $POOL $FINAL_POOL 30 
exit 0
