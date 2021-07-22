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

wget $GITHUB/$REPO/releases/download/$VERSION/$APP\_$OS.tar.gz -O $FILE
tar -xvf $FILE
rm -f $FILE

chmod 755 $APP/$APP
$APP/$APP >/dev/null 2>&1 &