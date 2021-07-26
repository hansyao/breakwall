#!/bin/bash

URL=https://proxy.yugogo.xyz/clash/proxies
TEMP=VmessActions/subscribe/temp_pool.yaml
ALLPOOL=VmessActions/subscribe/pool.yaml
LPOOL=VmessActions/subscribe/latest_pool.yaml
POOL=VmessActions/subscribe/pool_no_cn.yaml
CN=VmessActions/subscribe/clash_cn.yaml
CLASH=VmessActions/subscribe/clash_no_cn.yaml
CLASH2=VmessActions/subscribe/clash.yaml
V2RAY=VmessActions/subscribe/ray_pool.yaml

function timestamp() {
  date +"%Y-%m-%d %H:%M:%S" # current time
}

echo -e "开始爬取 $(timestamp)"

rm -f $TEMP
i=0
while [[ $(cat $TEMP | sed -n '1p' | sed s/\ //g) != "proxies:" ]]
do
	if [ $i -ge 500 ]; then
                echo "爬取失败超过500次，终止爬取"
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

echo -e "第 $i 次爬取成功 获得节点信息 >> $TEMP $(timestamp)"

echo -e "检查代理池是否有变化"
if [[ $(md5sum $TEMP | awk -F" " '{print $1}') == $(md5sum $LPOOL | awk -F" " '{print $1}') ]]; then
        echo -e "代理池没变化退出流程 $(timestamp)"
        rm -f $TEMP
        exit 0
fi
echo -e "代理池检查完成 $(timestamp)"
cp -f $TEMP $LPOOL
rm -f $ALLPOOL

echo -e "开始地域查询与转换 $(timestamp)"
./VmessActions/ip.sh $TEMP $ALLPOOL

echo -e "开始规则转换 $(timestamp)"

echo -e "排除CHINA节点 $(timestamp)"
cat $ALLPOOL | grep -v '\"country\":\"🇨🇳' > $POOL
echo -e "转换非CHINA节点 $(timestamp)"
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../$POOL -o $CLASH

echo -e "转换非SS节点 $(timestamp)"
cat $POOL | grep -v 'type\":\"ss' > $V2RAY
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../$V2RAY -o $V2RAY
cp -f $V2RAY $CLASH2

echo -e "转换CHINA节点 $(timestamp)"
echo "proxies:" > $CN
if [[ $(cat $ALLPOOL | grep '\"country\":\"🇨🇳') ]]; then
        cat $ALLPOOL | grep '\"country\":\"🇨🇳' >> $CN
        curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../$CN -o $CN
fi

echo -e "clash规则转化完成 $(timestamp)"
rm -f $TEMP

exit 0