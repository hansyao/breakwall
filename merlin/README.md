# 梅林路由器cloudflare优选IP自动配置clash

## 前言

>cloudflare优选IP测速对配置低的路由器并不适用，因为测速时开启多线程会占用大量资源。一般硬路由的性能有限，最终测速耗时很长，测得的速度明显比真实速度差很多。因此，简单优化了下脚本，只测试100次ping时延和丢包率。这样脚本也可以在路由器上轻松运行，正常时间5分钟之内即可优选出10个以上的IP。

>**原理：** 优选100次ping时延最低且丢包率为零的IP。  

## 配置需求

1. 梅林386固件 - （华硕RT-AC5300测试通过，理论上版本相差不大的都能兼容，其他版本由于cat命令版本问题可能需要修改代码162行的IP解析命令，可自行研究）。
2. 安装了merlin clash插件

## 使用手册

### 步骤一： 下载源码

```bash
git clone https://github.com/hansyao/breakwall
cd breakwall/merlin
```
文件夹里的三个文件都能用到： **cf-merlin-clash.sh**, **clash_header.yaml**, **clash_rules** 。
<br>

### 步骤二: 修改你配置文件

1. **clash_header.yaml**
第9行和18行改成你自己的路由器地址，其他配置懂得话也可按需修改。
2. **clash_rules.yaml**
clash规则，可自定义。不懂可直接用这个无需修改
3. **cf-merlin-clash.sh**
需要修改部门已经在代码中注明:

```bash
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
speedtest=n

```

### 步骤四： 将脚本上传路由器

先在路由器上开启**ssh**登录，然后进行以下的操作
```bash
#进入路由器操作
ssh yourname@192.168.50.1 -p 22         #登录路由器
mkdir /jffs/cf-auto                     #创建/jffs/cf-auto目录
exit                                

#本机上操作
cd passwall/merlin                       #进入刚下载的脚本目录
scp -P 22 ./* yourname@192.168.50.1/jffs/cf-auto/  #复制文件到路由器

#再次进入路由器
ssh yourname@192.168.50.1 -p 22         #登录路由器
cd /jffs/cf-auto                        #进入脚本目录
sh ./clashconfig.sh                     #执行脚本
```
这时可以等待几分钟，提示优选IP已经生成，并自动加载。然后进入路由器clash管理界面，选择刚生成的配置文件`clash`然后点击快速重启，进入clash **RAZARD-clash**或者**YACD-Clash**面板检查下刚才生成的IP是否生效。

如果生效没有问题，可以创建自动任务如下:

```bash
#路由器shell上操作

crobtab -e

# 0 4 * * 2,4,6 的意思是在每周二、周四、周六的凌晨4点会自动运行一次。/root/cf-auto-passwall.sh 是你脚本的绝对地址。建议修改成经常上网的时间段，
0 3 * * * cd /jffs/cf-auto && /jffs/cf-auto/cf-auto-merlin-clash.sh > /dev/null  #cloudflareIP autoupdate

# 修改好后:wq保存退出
:wq

```

然后在clash管理界面配置一下定时重启，可相比脚本的定时任务延迟10-30分钟即可(按自己手工测试情况修改)。

至此，全部配置完成， 可以愉快地无职守玩耍了。

