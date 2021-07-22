# 前言

本脚本参考了[badafans](https://github.com/badafans/better-cloudflare-ip)和[V2RaySSR](https://github.com/V2RaySSR/cf-auto-passwall)， 目的在于自动替换passwall和clash的ip为一组cloudflare优选IP实现passwall haproxy的负载均衡和clash的配置。

主要改进功能：
>1. 多节点支持
>2. passwall支持
>3. clash支持
>4. 梅林路由器clash支持, 参见[这里](merlin/README.md)
<br>

# 使用手册

## 准备工作：


```bash
git clone https://github.com/hansyao/breakwall          # 克隆到本地电脑
cd breakwall
```

1. 如果你的路由器原先没有配置passwall cloudflare优选节点, 改一下'getpasswallnodes.sh'文件配置第34-48行为自己的cloudflare优选配置。

```bash
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

```

2. 修改`cf-auto-passwall.sh`以下两行, 如果使用passwall，将`passwall_enable`填`true`，否则`false`； 如果使用clash, 将`clash_enable`填`true`，否则`false`。不要两个都填`true`，二选一即可。
(如果填`false`，配置文件也会自动生成，待手动启动代理时才会生效。填`true`则是自动启动生效)

```bash
passwall_enable=false         #启用passwall: true; 不启用:false
clash_enable=true             #启用clash: true; 不启用:false
```

3. 将`clash_header.yaml`中的一下两行修改成自己的,其他参数可按需修改。

```bash
external-controller: 192.168.50.1:9990   #改成路由器地址
router.asus.com: 192.168.50.1       #改成路由器地址和host名字，华硕的一般是router.asus.com。此行不重要，也可删除

```

4. `clash_rules.yaml`也可按需修改，不修改保持默认即可。

5. 修改`cf-auto-clash.sh`中以下一行，改成自己的配置。
```bash
    echo -e  \ \ - \{name: $i.${coco[$i]}, server: ${server[$i]}, port: 443, type: vmess, uuid: 231afacc-5082-11eb-badc-000adfdd60ef, alterId: 0, cipher: auto, tls: true, skip-cert-verify: false, network: ws, ws-path: /adfbdd, ws-headers: \{Host: your.cloudflare.workers.dev\}\} >>$clash

```

6. 将修改好的文件上传到路由器root用户目录，并进入路由器shell环境。

```bash
scp -r breakwall root@192.168.50.1/root/
ssh root@192.168.50.1
cd breakwall
```

至此，准备工作完成。

<br>

## 步骤一 解析当前路由器passwall节点

运行脚本`getpasswallnodes.sh`
```bash
./getpasswallnodes.sh
```

提示是否使用现有passwall节点，如果你的路由器已经配置了passwall cloudflare优选节点，填<kbd>y</kbd>。脚本会自动将现有节点信息写入`passwall_config_nodes.txt`下备用然后进入[步骤二](#步骤二)。

如果你的路由器原先没有配置passwall cloudflare优选节点，填<kbd>n</kbd>， 提示`请输入生成新passwall节点个数:`，按自己的需求输入即可，一般不用超过`10`, 脚本会根据你在`准备工作1`中所填的个人配置生成cloudflare优选配置。

完成后会得到一组passwall的32位随机字符的节点， 写入了文件`passwall_config_nodes.txt`:

```bash
将使用的passwall节点已经写入passwall_config_nodes.txt如下：
4c701d5aa826484a89212584827b35dc
bc93fdedb73e42d0b29b48800c507ab9
5f0dc84d8edd4064b77286c4647b64c8
790e3ceff4bc446188c52054a1754cbb
62df4fd72bfd40e78a05a25360ef36e1
a91eb8a55c2f4538813ebac8401258e3
de2f7ef0635545fbb1a644b44c6892a7
392589466550437aacf35a0591cc2535
a31d8a9e9848499bad3e19c225b6b4ab
c1f59974939148ddaa5ad4144aa0002b
```

<br>

## 步骤二: 生成passwall和clash配置文件并自动重启服务

此步骤较简单，如[准备工作](#准备工作)和[步骤一](#步骤一-解析当前路由器passwall节点)已完成，直接运行`cf-auto-passwall.sh`即可。

```
./cf-auto-passwall.sh
```
运行完成后到路由器`passwall`和`openclash`管理界面检查一下是否生效，同时目录下会自动生成calsh的配置文件`clash.yaml`, 你也可将其用于其他支持clash的客户端。测试有问题的话仔细检查[准备工作](#准备工作)和[步骤一](#步骤一-解析当前路由器passwall节点)是否配置正确。

如没有问题，再设置一下计划任务：
```bash
crontab -e

#增加一行计划任务, 按i键编辑, :wq保存退出
0 2 * * 1,3,5 bash /root/breakwall/cf-auto-passwall.sh > /dev/null      #添加礼拜一，三，五每天凌晨两点运行一次。可按需修改

```

自此，全部部署完成。

<br>

## 附：

如已经得到优选IP列表`serverresults.csv`，可直接运行`cf-auto-clash.sh`得到clash配置文件`clash.yaml`。`cf-auto-clash.sh`可作为独立脚本适用于通用clash配置文件生成，前提是除了ip地址外其他配置都一样。

```bash
./cf-auto-clash.sh

```


