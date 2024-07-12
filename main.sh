#!/bin/bash

set -e
echo 'Moonlark Maintainer for Linux (MTL) is launching ...'
alias poetry=$MTL_POETRY_PATH


# 检查权限
if ! [ "$EUID" -eq 0 ]; then
  echo 请以 ROOT 权限执行此脚本
  exit 1
fi


# 读取配置
if [ -z "$MTL_CONFIG" ]; then
    MTL_CONFIG=./config.sh
fi
if [ -f $MTL_CONFIG ]; then
    source $MTL_CONFIG
    echo 读取配置文件 $MTL_CONFIG 成功！
fi


# 检查路径
if ! [ -z "$MTL_MOONLARK_PATH" ] && ! [ -f "$MTL_MOONLARK_PATH/pyproject.toml" ]; then
    echo 错误：MTL_MOONLARK_PATH 未定义或不存在。
    exit 1
fi


# 初始化
MTL_BACKUP_NAME=MTL_BACKUP_$(date +"%Y%m%d")
MTL_CACHE_DIRECTORY=/tmp/$MTL_BACKUP_NAME
echo 将在 $MTL_CACHE_DIRECTORY 建立缓存文件夹
mkdir -p $MTL_CACHE_DIRECTORY
cd $MTL_MOONLARK_PATH
OLD_COMMIT=$(sudo -u $MTL_MOONLARK_USER git rev-parse --short HEAD)
echo Moonlark 当前版本 $OLD_COMMIT


# 备份与更新
echo ">== 当前步骤: 停止 ==<"
systemctl stop "$MTL_MOONLARK_SERVICE"
echo ">== 当前步骤: 备份 ==<"
cp -r $MTL_MOONLARK_PATH/$MTL_DATABASE_NAME.db $MTL_CACHE_DIRECTORY/database.db
cp -r /home/$MTL_MOONLARK_USER/.config/nonebot2 $MTL_CACHE_DIRECTORY/config
cp -r /home/$MTL_MOONLARK_USER/.local/share/nonebot2 $MTL_CACHE_DIRECTORY/data
chown -R $MTL_MOONLARK_USER $MTL_CACHE_DIRECTORY
echo ">== 当前步骤: 更新 ==<"
sudo -u $MTL_MOONLARK_USER git pull
NEW_COMMIT=$(sudo -u $MTL_MOONLARK_USER git rev-parse --short HEAD)
sudo -u $MTL_MOONLARK_USER $MTL_POETRY_PATH install
echo Moonlark 当前版本 $NEW_COMMIT
sudo -u $MTL_MOONLARK_USER $MTL_POETRY_PATH run nb orm upgrade
echo ">== 当前步骤: 启动 ==<"
systemctl start "$MTL_MOONLARK_SERVICE"


# 打包
cd /tmp
git clone --depth=1 $MTL_BACKUP_REPO mtl_backup
cd /tmp/mtl_backup
rm -rf ./database* ./onfig ./data || true
cp -r $MTL_CACHE_DIRECTORY/* $MTL_BACKUP_PATH
rm -rf /tmp/$MTL_BACKUP_NAME

# 上传
cd $MTL_BACKUP_PATH
zip -s 50m -r database.zip database.db
rm database.db
git add -A
git commit -m $(date +%Y%m%d%H%M%S)
git push


# 结束
rm -rf /tmp/mtl_backup
echo "Moonlark 维护已完成"