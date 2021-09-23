# 前言

本脚本目的在于自动替换passwall和clash的ip为一组cloudflare优选IP实现passwall haproxy的负载均衡和clash的配置。

主要改进功能：
>重构了所有代码，linux下全平台兼容。包括不限于OpenWRT, Merlin固件， VPS等， window下可在wsl子系统运行。

>支持多种获取cloudflare节点IP库的算法，可不再依赖udpfile.com提供过滤过的IP库，所有节点直接从cloudflare官方获取， 再也不怕第三方提供的服务抽风了

>支持与现有订阅代理池进行合并

>测速网址：直接用cloudflare官方[speedtest](https://speed.cloudflare.com)

>支持生成规则转换后的clash配置文件并提交到你自己的[gist.github.com](https://gist.github.com)私密链接，这样就可以有你自己的专用远程订阅，其他设备可以很方便随时调用既可用。

>支持订阅转换，适配于不同客户端clash,clashr,quan, quanx,loon,mellow,surfboard,surge2,surge3,surge4,v2ray(必须启用[gist](https://gist.github.com))

>支持为passwall建立不同协议和端口的负载均衡，并按照不同的测速实际情况进行分组和权重设置

>clash: 支持负载均衡规则(这个功能clash实现后可以不用passwall了)


<br>

# 快速食用：

1. 不管哪个平台，首先ssh登录，然后创建一个你自己的目录并进入（用默认目录也可以，本脚本对文件目录没有要求）， 然后转到第二步


2. 拉取代码

```bash
# 国内用户建议前缀加代理网址https://ghproxy.com/
curl -L -O https://ghproxy.com/https://raw.githubusercontent.com/hansyao/breakwall/master/cf_speedtest.sh

```

3. 修改节点信息

    按照格式将[节点信息](../../blob/master/cf_speedtest.sh#L70)改成你自己的, 如有多个按照格式追加（每个节点单独另起一行）

4. 修改基本参数

```bash
# 一般配置常量， 可按需更改
PING_COUNT=100	#单个ping检测次数, 缺省100次
TARGET_IPS=20	#目标IP数:缺省20，单一代理20个CDN IP足够, 太多了也没意义
SCHEDULE="30 */6 * * *"	#计划任务 (由于crontab版本不同，各个平台计划任务的格式可能会稍有差异，按实际情况填写)

# 上传Github gist需要用到 (强烈推荐)
GIST_TOKEN=						#github密钥，需要授予gist权限，如不上传留空即可

```

更多参数配置参见[这里](../../blob/master/cf_speedtest.sh#L3-L46)。

5. 运行代码
./cf_speedtest.sh后接一个参数即可, 本机测试无需加参数
```bash
./cf_speedtest.sh merlin            #梅林路由器 
./cf_speedtest.sh openwrt           #openwrt
./cf_speedtest.sh vps               #vps

```



