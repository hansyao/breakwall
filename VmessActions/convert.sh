#!/bin/bash

GITHUB=https://github.com
OS=linux64
USER=tindy2013
APP=subconverter
REPO=$USER/$APP
FILE=$APP.tar.gz


get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}
VERSION=$(get_latest_release $REPO)

rm -rf $APP
rm -f $FILE

echo -e "下载$FILE"
curl -s -L -X GET $GITHUB/$REPO/releases/download/$VERSION/$APP\_$OS.tar.gz -o $FILE
echo -e "下载完成, 开始解压缩到`pwd`/$APP"
tar -xvf $FILE >/dev/null 2>&1
echo -e "解压完成，删除`pwd`/$FILE"
rm -f $FILE

echo -e "设置权限 chmod 755 `pwd`/$APP/$APP"
chmod 755 $APP/$APP
echo -e "扩充EMOJI库"
cp -f VmessActions/emoji.txt subconverter/snippets/emoji.txt
echo -e "运行规则转换工具"
$APP/$APP >/dev/null 2>&1 &