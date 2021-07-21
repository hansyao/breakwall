#!/bin/bash

URL=https://proxy.yugogo.xyz/clash/proxies
TEMP=VmessActions/subscribe/pool.yaml
CLASH=VmessActions/subscribe/clash_pool.yaml

rm -f $TEMP
i=1
while [[ $(cat $TEMP | sed -n '1p' | sed s/\ //g) != "proxies:" ]]
do
	if [ $i -ge 500 ]; then
                break
        fi
                
        sleep 1
	echo -e 第 $i 次爬取失败
	rm -f $TEMP
	curl -s $URL > $TEMP
	let i++
done
if [ $i -lt 500 ]; then
        echo -e "第 $i 次爬取成功 获得节点信息 >> $TEMP"
        echo -e "开始规则转换"
        curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=https%3A%2F%2Fraw.githubusercontent.com%2Fhansyao%2Fbreakwall%2Fmaster%2FVmessActions%2Fsubscribe%2Fpool.yaml > $CLASH
else
        echo -e "爬取失败!"
fi

