# 前言

本脚本目的在于自动替换passwall和clash的ip为一组cloudflare优选IP实现passwall haproxy的负载均衡和clash的配置。

主要改进功能：
>重构了所有代码，linux下全平台兼容。包括不限于OpenWRT, Merlin固件， VPS等， window下可在wsl子系统运行。

>支持生成规则转换后的clash配置文件并提交到你自己的[gist.github.com](https://gist.github.com)私密链接，这样就可以有你自己的专用远程订阅，其他设备可以很方便随时调用既可用。

>多组不同配置的节点支持, 自动为passwall建立负载均衡，并按照不同的节点和丢包率和ping延迟情况进行分组和权重设置

>clash: 新增负载均衡规则

<br>

# 快速食用：

1. 不管哪个平台，首先ssh登录，然后创建一个你自己的目录并进入（用默认目录也可以，本脚本对文件目录没有要求）， 然后转到第二步


2. 拉取代码

```bash
# 国内用户建议前缀加代理网址https://ghproxy.com/
curl -L -O https://ghproxy.com/https://raw.githubusercontent.com/hansyao/breakwall/master/cf_speedtest.sh

```

3. 修改节点信息

    按照格式将[节点信息](../../blob/master/cf_speedtest.sh#L26-L31)改成你自己的

4. 修改基本参数

```bash
# 一般配置常量， 可按需更改
PING_COUNT=100	#单个ping检测次数, 缺省100次
TARGET_IPS=20	#目标IP数:缺省20，单一代理20个CDN IP足够, 太多了也没意义
SCHEDULE="30 */6 * * *"	#计划任务 (由于crontab版本不同，各个平台计划任务的格式可能会稍有差异，按实际情况填写)

# 上传Github gist需要用到 (强烈推荐)
GIST_TOKEN=						#github密钥，需要授予gist权限，如不上传留空即可

```

更多参数配置参见[这里](../../blob/master/cf_speedtest.sh#L5-L23)。

5. 运行代码
./cf_speedtest.sh后接一个参数即可, 本机测试无需加参数
```bash
./cf_speedtest.sh merlin            #梅林路由器 
./cf_speedtest.sh openwrt           #openwrt
./cf_speedtest.sh vps               #vps

```



