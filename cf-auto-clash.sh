#!/bin/bash

clash=clash.yaml
# ipresults=ipresults.md
serverresults=serverresults.csv
# serverlist=serverlist.txt
servercounts=$(cat $serverresults | wc -l)

# if [ -e $serverresults ]; then rm $serverresults; fi
if [ -e $clash ]; then rm $clash; fi

# cat $ipresults | awk -F "|  " '{print $2}' | tail -n $servercounts > $serverlist

cat clash_header.yaml >$clash
echo -e proxies: >>$clash

for ((i=1;i<=$servercounts;i++));
do
    server[$i]=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco[$i]=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)
    # country[$i]=$(cat $serverresults | awk -F "," '{print $3}' | sed -n $i\p)
    # echo -e ${server[$i]}
    echo -e  \ \ - \{name: $i.${coco[$i]}, server: ${server[$i]}, port: 443, type: vmess, uuid: 231afacc-5082-11eb-badc-000adfdd60ef, alterId: 0, cipher: auto, tls: true, skip-cert-verify: false, network: ws, ws-path: /adfbdd, ws-headers: \{Host: your.cloudflare.workers.dev\}\} >>$clash

done

cat >> $clash <<EOF
proxy-groups:
  - name: 🔰 节点选择
    type: select
    proxies:
      - ♻️ 自动选择
      - 🎯 全球直连
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat >> $clash <<EOF
  - name: ♻️ 自动选择
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    proxies:
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat >> $clash <<EOF
  - name: 🌍 国外媒体
    type: select
    proxies:
      - 🔰 节点选择
      - ♻️ 自动选择
      - 🎯 全球直连
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done


cat >> $clash <<EOF
  - name: 🌏 国内媒体
    type: select
    proxies:
      - 🎯 全球直连
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat >> $clash <<EOF
  - name: Ⓜ️ 微软服务
    type: select
    proxies:
      - ♻️ 自动选择
      - 🎯 全球直连
      - 🔰 节点选择
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat >> $clash <<EOF
  - name: 📲 电报信息
    type: select
    proxies:
      - ♻️ 自动选择
      - 🔰 节点选择
      - 🎯 全球直连
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat >> $clash <<EOF
  - name: 🍎 苹果服务
    type: select
    proxies:
      - ♻️ 自动选择
      - 🔰 节点选择
      - 🎯 全球直连
      - ♻️ 自动选择
EOF

for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat >> $clash <<EOF
  - name: 🎯 全球直连
    type: select
    proxies:
      - DIRECT
  - name: 🛑 全球拦截
    type: select
    proxies:
      - REJECT
      - DIRECT
  - name: 🐟 漏网之鱼
    type: select
    proxies:
      - 🔰 节点选择
      - 🎯 全球直连
      - ♻️ 自动选择
EOF
for ((i=1;i<=$servercounts;i++));
do
    echo -e "      - $i.${coco[$i]}" >>$clash
done

cat clash_rules.yaml >> $clash