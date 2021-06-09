#!/bin/bash

passwallnodeslist=passwallnodeslist.txt     #现有存在的passwall节点
passwall_config_nodes=passwall_config_nodes.txt #新的passwall节点

if [ -e  $passwall_config_nodes ]; then rm -rf $passwall_config_nodes; fi
if [ -e  $passwallnodeslist ]; then rm -rf $passwallnodeslist; fi

cat /etc/config/passwall | grep "config nodes" | awk -F"'" '{print $2}' > nodes.txt
cat /etc/config/passwall | grep "option address" | awk -F"'" '{print $2}' > address.txt

echo 已读取现有passwall配置节点如下：
awk '{if(NR==FNR){a[FNR]=$1;}else{print $1 "|" a[FNR]}}' address.txt nodes.txt | sed '/127.0.0.1/d' 

read -p "是否使用现有passwall节点(y/n):" existing

if [ $existing == 'y' ]; then
    awk '{if(NR==FNR){a[FNR]=$1;}else{print $1 "|" a[FNR]}}' address.txt nodes.txt | sed '/127.0.0.1/d' >$passwallnodeslist
    rm -rf nodes.txt address.txt
    cat $passwallnodeslist | awk -F"|" '{print $1}' >$passwall_config_nodes
    
    echo 将使用的passwall节点已经写入$passwall_config_nodes如下：

elif [ $existing == 'n' ]; then 
    rm -rf nodes.txt address.txt
    read -p "请输入生成新passwall节点个数:" nodesnum
    for ((i=1;i<=$nodesnum;i++));
    do
        str=$(cat /proc/sys/kernel/random/uuid  | md5sum |cut -c 1-32)

        #这里的配置一定要确保按照passwall规则配置正确能正常上网
        echo $str >>$passwall_config_nodes
        uci set passwall.$str=nodes
        uci set passwall.$str.remarks=pass$i
        uci set passwall.$str.type=V2ray
        uci set passwall.$str.protocol=vless
        uci set passwall.$str.port=443
        uci set passwall.$str.encryption=none
        uci set passwall.$str.uuid=6f4adf6a-4928-11eb-a771-000017013436
        uci set passwall.$str.level=1
        uci set passwall.$str.stream_security=tls
        uci set passwall.$str.tls_serverName=你的cloudflare-worker域名
        uci set passwall.$str.transport=ws
        uci set passwall.$str.ws_host=你的cloudflare-worker域名
        uci set passwall.$str.ws_path=/dddOQ/
        uci set passwall.$str.mux=1
        uci set passwall.$str.mux_concurrency=8
        uci set passwall.$str.address=104.17.57.75
        uci commit passwall

    done

    echo 节点模板已经写入passwall配置文件
    echo -e 生成的$nodesnum个passwall节点已经写入$passwall_config_nodes如下：

else
    echo 输入错误

fi

cat $passwall_config_nodes

exit