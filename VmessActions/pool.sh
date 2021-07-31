#!/bin/bash

TEMP_DIR=tmp
URL=https://proxy.yugogo.xyz/clash/proxies
TEMP=VmessActions/subscribe/temp_pool.yaml
ALLPOOL=VmessActions/subscribe/pool.yaml
VALID_POOL=VmessActions/subscribe/valid_pool.yaml
LPOOL=VmessActions/subscribe/latest_pool.yaml
POOL=VmessActions/subscribe/pool_no_cn.yaml
CN=VmessActions/subscribe/clash_cn.yaml
CLASH1=VmessActions/subscribe/clash_no_cn.yaml
CLASH2=VmessActions/subscribe/clash.yaml
CLASH=${HOME}/go/bin/clash
V2RAY=VmessActions/subscribe/ray_pool.yaml
LOCATION=VmessActions/location.txt

INCL=\(HK\|香港\|TW\|台湾\|JP\|日本\|KR\|韩国\)

function timestamp() {
  date +"%Y-%m-%d %H:%M:%S" # current time
}

echo -e "开始爬取 $(timestamp)"

rm -f ${TEMP}
i=0
while [[ $(cat ${TEMP} | sed -n '1p' | sed s/\ //g) != "proxies:" ]]
do
	if [ $i -ge 500 ]; then
                echo "爬取失败超过500次，终止爬取"
                exit 0
        fi

        sleep 1
        if [ $i != 0 ]; then
	        echo -e 第 $i 次爬取失败
        fi
	rm -f ${TEMP}
	curl -s ${URL} > ${TEMP}
	let i++
done

echo -e "第 $i 次爬取成功 获得节点信息 >> ${TEMP} $(timestamp)"

echo -e "检查代理池是否有变化"
if [[ $(md5sum ${TEMP} | awk -F" " '{print $1}') == $(md5sum $LPOOL | awk -F" " '{print $1}') ]]; then
        echo -e "代理池没变化退出流程 $(timestamp)"
        rm -f ${TEMP}
        exit 0
fi
echo -e "代理池检查完成 $(timestamp)"
cp -f ${TEMP} ${LPOOL}
rm -f ${ALLPOOL}

source ./VmessActions/connection_test.sh

echo -e "开始排除不可用节点 $(timestamp)"
# 算法一
pool_validate_fd "${TEMP}" "${VALID_POOL}" 1000
#算法二
#pool_validate_pid "${TEMP}" "${VALID_POOL}" 10
echo -e "排除不可用节点完成 $(timestamp)"

echo -e "开始地域查询与转换 $(timestamp)"
source ./VmessActions/proxy_rename.sh
# 得到IP地域文件
START_TIME=$(date +%s)
location ${VALID_POOL} ${LOCATION}
STOP_TIME=$(date +%s)
echo -e "查询IP地域总耗时: `expr $[STOP_TIME] - $[START_TIME]` 秒"

echo -e "开始节点重命名 $(timestamp)"
multi_pool_rename_pid "${VALID_POOL}" "${ALLPOOL}" 900

echo -e "开始规则转换 $(timestamp)"

echo -e "排除CHINA节点 $(timestamp)"
cat ${ALLPOOL} | grep -v '\"country\":\"CN' > ${POOL}
echo -e "转换非CHINA节点 $(timestamp)"
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../${POOL} -o ${CLASH1} >/dev/null 2>&1 &

echo -e "转换非SS节点 $(timestamp)"
cat ${POOL} | grep -v 'type\":\"ss' > ${V2RAY}
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../${V2RAY} -o ${V2RAY} >/dev/null 2>&1 &

echo -e '转换亚太区(台湾|日本|韩国|香港)为缺省配置'
curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&include=$INCL\&url\=../$POOL  -o $CLASH2 >/dev/null 2>&1 &

echo -e "转换CHINA节点 $(timestamp)"
echo "proxies:" > ${CN}
if [[ $(cat ${ALLPOOL} | grep '\"country\":\"CN') ]]; then
        cat ${ALLPOOL} | grep '\"country\":\"CN' >> ${CN}
        curl -s http://127.0.0.1:25500/sub\?target\=clash\&emoji\=true\&url\=../${CN} -o ${CN}
fi

wait

echo -e "clash规则转化完成 $(timestamp)"
rm -f ${TEMP}

exit 0
