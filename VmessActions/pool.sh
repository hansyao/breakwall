#!/bin/bash

URL=https://proxy.yugogo.xyz/clash/proxies
TEMP=VmessActions/subscribe/temp_pool.yaml
ALLPOOL=VmessActions/subscribe/pool.yaml
POOL=VmessActions/subscribe/pool_no_cn.yaml
CN=VmessActions/subscribe/clash_cn.yaml
CLASH=VmessActions/subscribe/clash_no_cn.yaml
CLASH2=VmessActions/subscribe/clash.yaml
V2RAY=VmessActions/subscribe/ray_pool.yaml

rm -f $TEMP
i=0
while [[ $(cat $TEMP | sed -n '1p' | sed s/\ //g) != "proxies:" ]]
do
	if [ $i -ge 500 ]; then
                echo "爬取失败!"
                exit 0
        fi

        sleep 1
        if [ $i != 0 ]; then
	        echo -e 第 $i 次爬取失败
        fi
	rm -f $TEMP
	curl -s $URL > $TEMP
	let i++
done

echo -e "第 $i 次爬取成功 获得节点信息 >> $TEMP"

# check whether it's same
if [[ $(md5sum $TEMP | awk -F" " '{print $1}') == $(md5sum $ALLPOOL | awk -F" " '{print $1}') ]]; then
        echo "代理池没变化退出流程"
        rm -f $TEMP
        exit 0
fi
cp -f $TEMP $ALLPOOL

echo -e "开始规则转换"
echo -e "排除CHINA节点"

echo -e "转换非CHINA节点"
cat $TEMP | grep -v '"country":"🇨🇳CN"' > $POOL
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../$POOL -o $CLASH

echo -e "转换非SS节点"
cat $POOL | grep -v 'type\":\"ss' > $V2RAY
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../$V2RAY -o $V2RAY
cp -f $V2RAY $CLASH2

echo -e "转换CHINA节点"
echo "proxies:" > $CN
if [[ $(cat $TEMP | grep '"country":"🇨🇳CN"') ]]; then
        cat $TEMP | grep '"country":"🇨🇳CN"' >> $CN
        curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../$CN -o $CN
fi

echo -e "clash规则转化完成"
rm -f $TEMP

exit 0

