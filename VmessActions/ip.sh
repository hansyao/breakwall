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


# 国家EMOJI表情定义静态数组
EM[1]='🇦🇨阿森松岛'
EM[2]='🇦🇩安道尔'
EM[3]='🇦🇪阿联酋'
EM[4]='🇦🇫阿富汗'
EM[5]='🇦🇬安提瓜和巴布达'
EM[6]='🇦🇮安圭拉'
EM[7]='🇦🇱阿尔巴尼亚'
EM[8]='🇦🇲亚美尼亚'
EM[9]='🇦🇴安哥拉'
EM[10]='🇦🇶南极洲'
EM[11]='🇦🇷阿根廷'
EM[12]='🇦🇸美属萨摩亚群岛'
EM[13]='🇦🇹奥地利'
EM[14]='🇦🇺澳大利亚'
EM[15]='🇦🇼阿鲁巴'
EM[16]='🇦🇽奥兰群岛'
EM[17]='🇦🇿阿塞拜疆'
EM[18]='🇧🇦波黑'
EM[19]='🇧🇧巴多斯'
EM[20]='🇧🇩孟加拉国'
EM[21]='🇧🇩孟加拉'
EM[22]='🇧🇪比利时'
EM[23]='🇧🇫布基纳法索'
EM[24]='🇧🇬保加利亚'
EM[25]='🇧🇭巴林'
EM[26]='🇧🇮布隆迪'
EM[27]='🇧🇯贝宁'
EM[28]='🇧🇱圣巴泰勒米'
EM[29]='🇧🇲百慕大'
EM[30]='🇧🇳文莱'
EM[31]='🇧🇴玻利维亚'
EM[32]='🇧🇶荷兰加勒比'
EM[33]='🇧🇷巴西'
EM[34]='🇧🇸巴哈马'
EM[35]='🇧🇹不丹'
EM[36]='🇧🇻布维岛'
EM[37]='🇧🇼博茨瓦纳'
EM[38]='🇧🇾白俄罗斯'
EM[39]='🇧🇿伯利兹'
EM[40]='🇨🇦加拿大'
EM[41]='🇨🇨科科斯群岛'
EM[42]='🇨🇩刚果(金)'
EM[43]='🇨🇫中非共和国'
EM[44]='🇨🇬刚果(布)'
EM[45]='🇨🇭瑞士'
EM[46]='🇨🇮科特迪瓦'
EM[47]='🇨🇰库克群岛'
EM[48]='🇨🇱智利'
EM[49]='🇨🇲喀麦隆'
EM[50]='🇨🇳中国'
EM[51]='🇨🇴哥伦比亚'
EM[52]='🇨🇵克利珀顿岛'
EM[53]='🇨🇷哥斯达黎加'
EM[54]='🇨🇺古巴'
EM[55]='🇨🇻佛得角'
EM[56]='🇨🇼库拉索'
EM[57]='🇨🇽圣诞岛'
EM[58]='🇨🇾塞浦路斯'
EM[59]='🇨🇿捷克共和国'
EM[60]='🇨🇿捷克'
EM[61]='🇩🇪德国'
EM[62]='🇩🇬迪戈加西亚'
EM[63]='🇩🇯吉布提'
EM[64]='🇩🇰丹麦'
EM[65]='🇩🇲多米尼加'
EM[66]='🇩🇴多明尼加共和国'
EM[67]='🇩🇿阿尔及利亚'
EM[68]='🇪🇦休达和梅利利亚'
EM[69]='🇪🇨厄瓜多尔'
EM[70]='🇪🇪爱沙尼亚'
EM[71]='🇪🇬埃及'
EM[72]='🇪🇭西撒哈拉'
EM[73]='🇪🇷厄立特里亚'
EM[74]='🇪🇸西班牙'
EM[75]='🇪🇹埃塞俄比亚'
EM[76]='🇪🇺欧盟'
EM[77]='🇪🇺欧洲'
EM[78]='🇫🇮芬兰'
EM[79]='🇫🇯斐济'
EM[80]='🇫🇰福克兰群岛'
EM[81]='🇫🇲密克罗尼西亚'
EM[82]='🇫🇴法罗群岛'
EM[83]='🇫🇷法国'
EM[84]='🇬🇦加蓬'
EM[85]='🇬🇧英国'
EM[86]='🇬🇩格林纳达'
EM[87]='🇬🇪格鲁吉亚'
EM[88]='🇬🇫法属圭亚那'
EM[89]='🇬🇬根西岛'
EM[90]='🇬🇭加纳'
EM[91]='🇬🇮直布罗陀'
EM[92]='🇬🇱格陵兰'
EM[93]='🇬🇲冈比亚'
EM[94]='🇬🇳几内亚'
EM[95]='🇬🇵瓜德罗普岛'
EM[96]='🇬🇶赤道几内亚'
EM[97]='🇬🇷希腊'
EM[98]='🇬🇸南乔治亚岛和南桑威奇群岛'
EM[99]='🇬🇹危地马拉'
EM[100]='🇬🇺关岛'
EM[101]='🇬🇼几内亚比绍'
EM[102]='🇬🇾圭亚那'
EM[103]='🇭🇰香港区旗'
EM[104]='🇭🇲赫德与麦克唐纳群岛'
EM[105]='🇭🇳洪都拉斯'
EM[106]='🇭🇷克罗地亚'
EM[107]='🇭🇹海地'
EM[108]='🇭🇺匈牙利'
EM[109]='🇮🇨加那利群岛'
EM[110]='🇮🇩印尼'
EM[111]='🇮🇩印度尼西亚'
EM[112]='🇮🇪爱尔兰'
EM[113]='🇮🇱以色列'
EM[114]='🇮🇲曼岛'
EM[115]='🇮🇳印度'
EM[116]='🇮🇴英属印度洋领地'
EM[117]='🇮🇶伊拉克'
EM[118]='🇮🇷伊朗'
EM[119]='🇮🇸冰岛'
EM[120]='🇮🇹意大利'
EM[121]='🇯🇪泽西'
EM[122]='🇯🇲牙买加'
EM[123]='🇯🇴约旦'
EM[124]='🇯🇵日本'
EM[125]='🇰🇪肯尼亚'
EM[126]='🇰🇬吉尔吉斯斯坦'
EM[127]='🇰🇭柬埔寨'
EM[128]='🇰🇮基里巴斯'
EM[129]='🇰🇲科摩罗'
EM[130]='🇰🇳圣基茨和尼维斯'
EM[131]='🇰🇵朝鲜'
EM[132]='🇰🇷韩国'
EM[133]='🇰🇼科威特'
EM[134]='🇰🇾开曼群岛'
EM[135]='🇰🇿哈萨克斯坦'
EM[136]='🇱🇦老挝'
EM[137]='🇱🇧黎巴嫩'
EM[138]='🇱🇨圣卢西亚'
EM[139]='🇱🇮列支敦士登'
EM[140]='🇱🇰斯里兰卡'
EM[141]='🇱🇷利比里亚'
EM[142]='🇱🇸莱索托'
EM[143]='🇱🇹立陶宛'
EM[144]='🇱🇺卢森堡'
EM[145]='🇱🇻拉脱维亚'
EM[146]='🇱🇾利比亚'
EM[147]='🇲🇦摩洛哥'
EM[148]='🇲🇨摩纳哥'
EM[149]='🇲🇩摩尔多瓦'
EM[150]='🇲🇪黑山'
EM[151]='🇲🇫圣马丁'
EM[152]='🇲🇬马达加斯加'
EM[153]='🇲🇭马绍尔群岛'
EM[154]='🇲🇰马其顿'
EM[155]='🇲🇱马里'
EM[156]='🇲🇲缅甸'
EM[157]='🇲🇳蒙古'
EM[158]='🇲🇴澳门区旗'
EM[159]='🇲🇵北马里亚纳群岛'
EM[160]='🇲🇶马提尼克岛'
EM[161]='🇲🇷毛里塔尼亚'
EM[162]='🇲🇸蒙特塞拉特'
EM[163]='🇲🇹马耳他'
EM[164]='🇲🇺毛里求斯'
EM[165]='🇲🇻马尔代夫'
EM[166]='🇲🇼马拉维'
EM[167]='🇲🇽墨西哥'
EM[168]='🇲🇾马来西亚'
EM[169]='🇲🇿莫桑比克'
EM[170]='🇳🇦纳米比亚'
EM[171]='🇳🇨新喀里多尼亚'
EM[172]='🇳🇪尼日尔'
EM[173]='🇳🇫诺福克岛'
EM[174]='🇳🇬尼日利亚'
EM[175]='🇳🇮尼加拉瓜'
EM[176]='🇳🇱荷兰'
EM[177]='🇳🇴挪威'
EM[178]='🇳🇵尼泊尔'
EM[179]='🇳🇷瑙鲁'
EM[180]='🇳🇺纽埃'
EM[181]='🇳🇿新西兰'
EM[182]='🇴🇲阿曼'
EM[183]='🇵🇦巴拿马'
EM[184]='🇵🇪秘鲁'
EM[185]='🇵🇫法属波利尼西亚'
EM[186]='🇵🇬巴布亚新几内亚'
EM[187]='🇵🇭菲律宾'
EM[188]='🇵🇰巴基斯坦'
EM[189]='🇵🇱波兰'
EM[190]='🇵🇲圣皮埃尔和密克隆群岛'
EM[191]='🇵🇳皮特凯恩群岛'
EM[192]='🇵🇷波多黎各'
EM[193]='🇵🇸巴勒斯坦领土'
EM[194]='🇵🇹葡萄牙'
EM[195]='🇵🇼帕劳'
EM[196]='🇵🇾巴拉圭'
EM[197]='🇶🇦卡塔尔'
EM[198]='🇷🇪团圆'
EM[199]='🇷🇴罗马尼亚'
EM[200]='🇷🇸塞尔维亚'
EM[201]='🇷🇺俄罗斯'
EM[202]='🇷🇼卢旺达'
EM[203]='🇸🇦沙特阿拉伯'
EM[204]='🇸🇧所罗门群岛'
EM[205]='🇸🇨塞舌尔'
EM[206]='🇸🇩苏丹'
EM[207]='🇸🇪瑞典'
EM[208]='🇸🇬新加坡'
EM[209]='🇸🇭圣赫勒拿'
EM[210]='🇸🇮斯洛文尼亚'
EM[211]='🇸🇯斯瓦尔巴群岛和扬马延'
EM[212]='🇸🇰斯洛伐克'
EM[213]='🇸🇱塞拉利昂'
EM[214]='🇸🇲圣马力诺'
EM[215]='🇸🇳塞内加尔'
EM[216]='🇸🇴索马里'
EM[217]='🇸🇷苏里南'
EM[218]='🇸🇸南苏丹'
EM[219]='🇸🇹圣多美和普林西比'
EM[220]='🇸🇻萨尔瓦多'
EM[221]='🇸🇽圣马丁岛'
EM[222]='🇸🇾叙利亚'
EM[223]='🇸🇿斯威士兰'
EM[224]='🇹🇦特里斯坦-达库尼亚群岛'
EM[225]='🇹🇨特克斯和凯科斯群岛'
EM[226]='🇹🇩乍得'
EM[227]='🇹🇫法国南方的领土'
EM[228]='🇹🇬多哥'
EM[229]='🇹🇭泰国'
EM[230]='🇹🇯塔吉克斯坦'
EM[231]='🇹🇰托克劳'
EM[232]='🇹🇱东帝汶'
EM[233]='🇹🇲土库曼斯坦'
EM[234]='🇹🇳突尼斯'
EM[235]='🇹🇴汤加'
EM[236]='🇹🇷土耳其'
EM[237]='🇹🇹特立尼达和多巴哥'
EM[238]='🇹🇻图瓦卢'
EM[239]='🇹🇼台湾地区旗'
EM[240]='🇹🇿坦桑尼亚'
EM[241]='🇺🇦乌克兰'
EM[242]='🇺🇬乌干达'
EM[243]='🇺🇲美国离岛'
EM[244]='🇺🇸美国'
EM[245]='🇺🇾乌拉圭'
EM[246]='🇺🇿乌兹别克斯坦'
EM[247]='🇻🇦梵蒂冈城'
EM[248]='🇻🇨圣文森特和格林纳丁斯'
EM[249]='🇻🇪委内瑞拉'
EM[250]='🇻🇬英属维尔京群岛'
EM[251]='🇻🇮美属维尔京群岛'
EM[252]='🇻🇳越南'
EM[253]='🇻🇺瓦努阿图'
EM[254]='🇼🇫瓦利斯和富图纳群岛'
EM[255]='🇼🇸萨摩亚'
EM[256]='🇽🇰科索沃'
EM[257]='🇾🇪也门'
EM[258]='🇾🇹马约特'
EM[259]='🇿🇦南非'
EM[260]='🇿🇲赞比亚'
EM[261]='🇿🇼津巴布韦'


function search_emoji() {
	for emoji in ${EM[@]}
	do
		if [[ $(echo ${emoji} | cut -c 3-) == $1 ]]; then
			echo ${emoji} | cut -c 1-2
			break
		fi
	done
}

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
		# COUNTRY=$(echo ${DATABASE}|awk -F"|" '{print $1}')
		echo -e $1\|${DATABASE}
	else
		JSON=$(curl -s --connect-timeout 1 -m 5 -X GET $URL$IP1\?lang\=zh-CN)
		COUNTRY=$(echo $JSON | awk -F"\"country\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		REGION=$(echo $JSON | awk -F"\"region\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		REGIONNAME=$(echo $JSON | awk -F"\"regionName\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		CITY=$(echo $JSON | awk -F"\"city\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		ISP=$(echo $JSON | awk -F"\"isp\":" '{print $2}' | awk -F"," '{print $1}' | sed 's/\"//g')
		# EMOJI=$(search_emoji $COUNTRY)

		# if [[ ! ${EMOJI} ]]; then EMOJI='🏁'; fi
		# if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 台湾) ]]; then EMOJI='🇹🇼'; fi
		# if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 香港) ]]; then EMOJI='🇭🇰'; fi
		# if [[ $COUNTRY == "中国" && $(echo ${DATABASE} | grep 澳门) ]]; then EMOJI='🇲🇴'; fi
		echo -e $1\|$COUNTRY\|$REGION\|$REGIONNAME\|$CITY\|$ISP
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

