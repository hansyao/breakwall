# This is a basic workflow to help you get started with Actions

name: 代理测试

# Controls when the workflow will run
on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: 迁出代码
      uses: actions/checkout@v2
    - name: 设置时区
      run: sudo timedatectl set-timezone 'Asia/Shanghai'
    - name: CLASH环境部署
      run: |
        ulimit -SHn 65536
        GITHUB='https://github.com'
        OS='linux-amd64'
        USER='Dreamacro'
        APP='clash'
        REPO=$USER/$APP
        FILE=$APP.gz
        get_latest_release() {
          curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
            grep '"tag_name":' |                                            # Get tag line
            sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
        }
        VERSION=$(get_latest_release $REPO)
        get_clash() {
                curl -L -s ${GITHUB}/${USER}/${APP}/releases/download/${VERSION}/${APP}-${OS}-${VERSION}.gz -o ${FILE}
                gzip -d ${FILE}
                chmod 755 clash
        }
        get_clash
        mv clash VmessActions/clash && chmod 755 VmessActions/clash 
    - name: 代理测试
      run: |
        source VmessActions/proxy.sh
