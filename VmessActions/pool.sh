#!/bin/bash

URL=https://proxy.yugogo.xyz/clash/proxies
TEMP=VmessActions/subscribe/pool.yaml

rm -f $TEMP
i=1
while [[ $(cat $TEMP | sed -n '1p' | sed s/\ //g) != "proxies:" ]]
do
	sleep 1
	echo -e 第 $i 次爬取失败
	rm -f $TEMP
	curl -s $URL > $TEMP
	let i++
done

echo -e "第 $i 次爬取成功 获得节点信息 >> $TEMP"

