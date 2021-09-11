#!/bin/sh

# 使用说明：Merlin路由器新建目录/jffs/cf-auto，将脚本文件传到和两个clash规则文件上传进去，然后计划任务里 添加定时运行
# 原理：免测速自动优选出一组个ping延迟值最低且丢包率为零的cloudflare CDN IP地址（路由器配置垃圾，测速耗时过长且没卵用
# 的，因为理论上丢包率为零的IP的延迟率最低就是网速最快的, clash插件的自动测速功能也是这个原理）
# 0 4 * * 2,4,6 的意思是在每周二、周四、周六的凌晨4点会自动运行一次。/root/cf-auto-passwall.sh 是你脚本的绝对地址
# 0 3 * * * cd /jffs/cf-auto && /jffs/cf-auto/cf-merlin-clash.sh > /dev/null  #cloudflareIP autoupdate
#########################################注意注意注意注意注意############################################

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
clear
green "=========================================================="
 blue "用途：适用于安装了Merlin Clash插件的梅林路由器"
 blue "用于自动筛选 CF IP，并自动生成Clash 的配置文件"
green "=========================================================="
green "=========================================================="
 red  "请在脚本中按照使用说明修改成你自己的配置....."
green "=================脚本正在运行中.....======================="
sleep 3s

#按需修改部分：
totalips=10                                        #期望得到的优选ip数量，可按需修改
clash_rules=clash_rules.yaml                       #clash规则文件，可按需修改
clash_header=clash_header.yaml                     #clash规则文件，可按需修改
clash=clash.yaml                                   #你期望生成的clash配置文件名，可按需修改
                                     
#必须修改部分 >>> 你的代理服务器配置，默认vmess，如果是其他协议，可能还需要修改215行：
PORT=443                                           #代理端口
TYPE=vmess                                         #协议
UUID=adfa2acc-4084-11eb-dddd-00001702adff          #uuid
ALTERID=0                                          #alterid
CIPHER=auto                                        #cipher
TLS=true                                           #tls
SKIPCERTVERIFY=false                               #skipe-cert-verify 参数
NETWORK=ws                                         #network
WSPATH=/PrAsDITT                                   #ws-path
HOST=quiet-test-test.test.workers.dev              #cloudflare worker


# 以下配置无需修改

serverresults=serverresults.csv #自动生成的优选IP列表，无需修改
clashconfig=/jffs/.koolshare/merlinclash/clashconfig.sh
speedtest=n                     #无需测试速度，无需修改

nodes_line=1
if [ -e $serverresults ]; then rm -rf $serverresults; fi

source $clashconfig

#stop_config

while [ $nodes_line -le $totalips ];
do
    starttime=`date +'%Y-%m-%d %H:%M:%S'`
    while true
    do
        while true
        do
            rm -rf icmp temp data.txt meta.txt log.txt anycast.txt temp.txt
            mkdir icmp
            while true
            do
                if [ -f "resolve.txt" ]
                then
                    echo 指向解析获取CF节点IP
                    resolveip=$(cat resolve.txt)
                    while true
                    do
                        if [ ! -f "meta.txt" ]
                        then
                            curl --ipv4 --resolve speed.cloudflare.com:443:$resolveip --retry 3 -v https://speed.cloudflare.com/__down >meta.txt 2>&1
                        else
                            asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
                            city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk -F ": " '{print $2}')
                            latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
                            longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
                            curl --ipv4 --resolve service.udpfile.com:443:$resolveip --retry 3 "https://service.udpfile.com?asn="$asn"&city=\"$city\"" -o data.txt -#
                            break
                        fi
                    done
                else
                    echo DNS解析获取CF节点IP
                    while true
                    do
                        if [ ! -f "meta.txt" ]
                        then
                            curl --ipv4 --retry 3 -v https://speed.cloudflare.com/__down >meta.txt 2>&1
                        else
                            asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
                            city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk -F ": " '{print $2}')
                            latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
                            longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
                            curl --ipv4 --retry 3 "https://service.udpfile.com?asn="$asn"&city=\"$city\"" -o data.txt -#
                            break
                        fi
                    done
                fi
                if [ -f "data.txt" ]
                then
                    break
                fi
            done
            domain=$(cat data.txt | grep domain= | cut -f 2- -d'=')
            file=$(cat data.txt | grep file= | cut -f 2- -d'=')
            url=$(cat data.txt | grep url= | cut -f 2- -d'=')
            app=$(cat data.txt | grep app= | cut -f 2- -d'=')
            if [ "$app" != "20210825" ]
            then
                echo 发现新版本程序: $app
                echo 更新地址: $url
                echo 更新后才可以使用
                exit
            fi
            for i in `cat data.txt | sed '1,4d'`
            do
                echo $i>>anycast.txt
            done
            rm -rf meta.txt data.txt
            n=0
            m=$(cat anycast.txt | wc -l)
            for i in `cat anycast.txt`
            do
                ping -c 100 -n -q $i > icmp/$n.log&
                n=$(expr $n + 1)
                per=$(expr $n \* 100 / $m)
                while true
                do
                    p=$(ps | grep ping | grep -v "grep" | wc -l)
                    if [ $p -ge 100 ]
                    then
                        echo 正在测试 ICMP 丢包率:进程数 $p,已完成 $per %
                        sleep 1
                    else
                        echo 正在测试 ICMP 丢包率:进程数 $p,已完成 $per %
                        break
                    fi
                done
            done
            rm -rf anycast.txt
            while true
            do
                p=$(ps | grep ping | grep -v "grep" | wc -l)
                if [ $p -ne 0 ]
                then
                    echo 等待 ICMP 进程结束:剩余进程数 $p
                    sleep 1
                else
                    echo ICMP 丢包率测试完成
                    break
                fi
            done

            cat icmp/*.log | grep 'statistics\|loss\|avg' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' | sed 's/ms -/ms\n-/g' | sed '/errors\|0 received/d' | sed 's/\// /g' | awk -F" " '{print $2,$12,$21}'|grep " 0% " | sort -n -k 3 | awk '{print $1}' | sed '21,$d' > ip.txt

            if [ "$speedtest==n" ];then
                cat icmp/*.log | grep 'statistics\|loss\|avg' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' | sed 's/ms -/ms\n-/g' | sed '/errors\|0 received/d' | sed 's/\// /g' | awk -F" " '{print $2,$12,$21}'|grep " 0% " | sort -n -k 3 | awk '{print $1}' | head -$totalips > ip.txt
                for i in `cat ip.txt`
                do
                    curl --ipv4 --resolve service.udpfile.com:$i --retry 3 -s -X POST  "https://service.udpfile.com" > temp.txt
                    publicip=$(cat temp.txt | grep publicip= | cut -f 2- -d'=')
                    colo=$(cat temp.txt | grep colo= | cut -f 2- -d'=') 
                    echo -e $i,$colo >>$serverresults

                done
                rm -rf ip.txt
                echo 优选$totalips 个IP如下
                cat $serverresults
                break 3
            fi 
        done

    done

    max=$(expr $max / 1024)
    realbandwidth=$(expr $max / 128)
    endtime=`date +'%Y-%m-%d %H:%M:%S'`
    start_seconds=$(date --date="$starttime" +%s)
    end_seconds=$(date --date="$endtime" +%s)
    clear
    curl --ipv4 --resolve service.udpfile.com:443:$anycast --retry 3 -s -X POST -d ''20210315-$anycast-$max'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o temp.txt
    publicip=$(cat temp.txt | grep publicip= | cut -f 2- -d'=')
    colo=$(cat temp.txt | grep colo= | cut -f 2- -d'=')        
    rm -rf temp.txt
    echo 公网IP $publicip
    echo 数据中心 $colo
    echo 总计用时 $((end_seconds-start_seconds)) 秒

    echo -e $anycast,$colo >>$serverresults
	
	let nodes_line=$(expr $nodes_line + 1)

done

servercounts=$(cat $serverresults | wc -l)

if [ -e $clash ]; then rm $clash; fi

cat $clash_header >$clash
echo -e proxies: >>$clash

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)
    echo -e  \ \ - \{name: $i.$coco\($server\), server: $server, port: $PORT, type: $TYPE, uuid: $UUID, alterId: $ALTERID, cipher: $CIPHER, tls: $TLS, skip-cert-verify: $SKIPCERTVERIFY, network: $NETWORK, ws-path: $WSPATH, ws-headers: \{Host: $HOST\}\} >>$clash

    let i=$(expr $i + 1)
done

cat >> $clash <<EOF
proxy-groups:
  - name: 🔰 节点选择
    type: select
    proxies:
      - ♻️ 自动选择
      - 🎯 全球直连
EOF

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
done

cat >> $clash <<EOF
  - name: ♻️ 自动选择
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    proxies:
EOF

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash    
    let i=$(expr $i + 1)
done

cat >> $clash <<EOF
  - name: 🌍 国外媒体
    type: select
    proxies:
      - 🔰 节点选择
      - ♻️ 自动选择
      - 🎯 全球直连
EOF

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
done


cat >> $clash <<EOF
  - name: 🌏 国内媒体
    type: select
    proxies:
      - 🎯 全球直连
EOF

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
done

cat >> $clash <<EOF
  - name: Ⓜ️ 微软服务
    type: select
    proxies:
      - ♻️ 自动选择
      - 🎯 全球直连
      - 🔰 节点选择
EOF

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
done

cat >> $clash <<EOF
  - name: 📲 电报信息
    type: select
    proxies:
      - ♻️ 自动选择
      - 🔰 节点选择
      - 🎯 全球直连
EOF

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
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

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
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

i=1
while [ $i -le $servercounts ]
do
    server=$(cat $serverresults | awk -F "," '{print $1}' | sed -n $i\p)
    coco=$(cat $serverresults | awk -F "," '{print $2}' | sed -n $i\p)                                                                                                                                                        
    echo -e "      - $i.$coco($server)" >>$clash
    let i=$(expr $i + 1)
done

cat $clash_rules >> $clash

cp -rf  $clash /tmp/upload/

merlinclash_uploadfilename=$clash
move_config
#cat /tmp/upload/merlinclash_log.txt
#apply_mc
#restart_mc_quickly

cat $LOG_FILE | tail -n 11

exit
