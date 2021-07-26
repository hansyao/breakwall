#!/bin/bash

POOL=$1
IPLIST=VmessActions/iplist.txt
LOCATION=VmessActions/location.txt
# IPJSON_FILE=iplookup.json
EMOJI_LIST=VmessActions/emoji_list.txt
# PHPFILE=ip.php
URL=http://ip-api.com/json/

# URL=https://whois.pconline.com.cn/ipJson.jsp\?callback=testJson\&ip\=
# curl -s --connect-timeout 2 -m 5 -X GET $URL$IP | iconv -fgb2312 -t utf-8 | sed -n "6p" >>$IPJSON_FILE

function check_ip() {
	IP=$1
	VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
	if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
		if [ ${VALID_CHECK:-no} == "yes" ]; then
			echo "IP $IP available."
		else
			echo "IP $IP not available!"
		fi
	else
		echo "IP format error!"
	fi
}

function timestamp() {
  date +"%Y-%m-%d %H:%M:%S" # current time
}

function patch_location() {

	IP1=$1
	if [[ $(check_ip $1) != "IP $1 available." ]]; then
		IP1=$(nslookup $1 | egrep 'Address:' | awk '{if(NR==2) print $NF}')
	fi

	# DATABASE=$(php $PHPFILE $IP1) 
	DATABASE=$(./VmessActions/search -d VmessActions/ip2region.db -i $IP1)
	if [[ ${DATABASE} != '0|0|0|内网IP|内网IP' && ${DATABASE} ]]; then
		COUNTRY=$(echo ${DATABASE}|awk -F"|" '{print $1}')
		EMOJI=$(cat $EMOJI_LIST | sed -n "$(cat $EMOJI_LIST | cut -c 3- | grep -x -n $COUNTRY | cut -d ":" -f 1)p" | cut -c 1-2)
		if [[ ${#EMOJI} != 2 ]]; then EMOJI='🏁'; fi
		if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 台湾) ]]; then EMOJI='🇹🇼'; fi
		if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 香港) ]]; then EMOJI='🇭🇰'; fi
		if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 澳门) ]]; then EMOJI='🇲🇴'; fi
		echo -e $1\|$EMOJI${DATABASE}
	else
		JSON=$(curl -s --connect-timeout 1 -m 5 -X GET $URL$IP1\?lang\=zh-CN)
		COUNTRY=$(echo $JSON | awk -F"\"country\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		REGION=$(echo $JSON | awk -F"\"region\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		REGIONNAME=$(echo $JSON | awk -F"\"regionName\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		CITY=$(echo $JSON | awk -F"\"city\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		ISP=$(echo $JSON | awk -F"\"isp\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		EMOJI=$(cat $EMOJI_LIST | sed -n "$(cat $EMOJI_LIST | cut -c 3- | grep -x -n $COUNTRY | cut -d ":" -f 1)p" | cut -c 1-2)

		if [[ ${#EMOJI} != 2 ]]; then EMOJI='🏁'; fi
		if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 台湾) ]]; then EMOJI='🇹🇼'; fi
		if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 香港) ]]; then EMOJI='🇭🇰'; fi
		if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 澳门) ]]; then EMOJI='🇲🇴'; fi
		echo -e $1\|$EMOJI$COUNTRY\|$REGION\|$REGIONNAME\|$CITY\|$ISP
	fi
}


cat $POOL | sed "1d" |tr -s '\n'| awk -F"\"server\":" '{print $2}' | awk -F"," '{print $1}' | sort | uniq | sed s/\"//g | sed '/^$/d' > $IPLIST
TOTAL=$(cat $IPLIST | wc -l)

rm -f $LOCATION

# patch location to file 
echo -e "根据IP地址获取地域 $(timestamp)"

i=1
while [[ $i -le $TOTAL ]]
do
	IP=$(cat $IPLIST | sed -n "$[i]p")
	echo -e $(patch_location $IP) >>$LOCATION

	let i++
done
rm -f $IPLIST

# retry missing
echo -e "获取地域失败的重试一次 $(timestamp)"
i=1
TOTAL=$(cat $LOCATION | wc -l)
while [[ $i -le $TOTAL ]]
do
	EMOJI=$(cat $LOCATION | sed -n "$[i]p" | awk -F"|" '{print $2}' | cut -c 1-2)

	if [[ $EMOJI == "🏁" ]]; then
		IP=$(cat $LOCATION | sed -n "$[i]p" | awk -F"|" '{print $1}')
		sed -i "$[i]c $(patch_location $IP)" $LOCATION
	fi

	let i++
done

echo -e "按地域更改代理服务器名称 $(timestamp)"
i=1
TOTAL=$(cat $POOL | wc -l)
while [[ $i -le $TOTAL ]]
do
	IP=$(cat $POOL | sed -n "$[i]p"| awk -F"\"server\":" '{print $2}' | awk -F"," '{print $1}' | sed s/\"//g)
	NODE[i]=$(cat $POOL | sed -n "$[i]p")
	if [[ $IP ]]; then
		NEW_NAME=$(cat $LOCATION | sed -n "$(cat $LOCATION | awk -F"|" '{print $1}' | grep -x -n $IP | cut -d ":" -f 1)p")
		NEW_NAME=$(echo $NEW_NAME | awk -F"|" '{print $2,$3,$4,$5,$6}' | sed s/\0//g | sed s/\ //g) 
		
		OLD_NODE=$(cat $POOL | sed -n "$[i]p")
		OLD_NAME=$(echo $OLD_NODE | awk -F"{\"name\":" '{print $2}' | awk -F"," '{print $1}' | sed s/\"//g)

		NEW_NODE=$(echo $OLD_NODE | sed s/$OLD_NAME/$NEW_NAME\($i\)/g)

		NODE[i]=$NEW_NODE
		# sed -i "$[i]c $NEW_NODE" $POOL
	fi

	echo -e "${NODE[i]}" >> $2

	let i++
done


echo -e "区域转换完成 $(timestamp)"

exit 0

