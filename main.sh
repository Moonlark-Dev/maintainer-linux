#!/bin/bash

set -e
echo 'Moonlark Maintainer for Linux (MTL) is launching ...'


# 检查权限
if ![ "$EUID" -eq 0 ]; then
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
if ![ -z "$MTL_MOONLARK_PATH" ] && ![ -f "$MTL_MOONLARK_PATH" ]; then
    echo 错误：MTL_MOONLARK_PATH 未定义或不存在。
    exit 1
fi


# 初始化
MTL_BACKUP_NAME=MTL_BACKUP_$(date +"%Y%m%d")
MTL_CACHE_DIRECTORY=/tmp/$MTL_BACKUP_NAME
echo 将在 $MTL_CACHE_DIRECTORY 建立缓存文件夹
mkdir -p $MTL_CACHE_DIRECTORY
cd $MTL_MOONLARK_PATH
OLD_COMMIT=$(git rev-parse --short HEAD)
echo Moonlark 当前版本 $OLD_COMMIT


# 备份与更新
echo ">== 当前步骤: 停止 ==<"
systemctl stop "$MTL_MOONLARK_SERVICE"

echo ">== 当前步骤: 备份 ==<"
if [ -z "$MTL_BACKUP_DATABASE" ] || [ "$MTL_BACKUP_DATABASE" == 1 ]; then
    mysqldump -u "$MTL_MYSQL_USER" -p"$MTL_MYSQL_PASSWORD" "$MTL_DATABASE_NAME" > $MTL_CACHE_DIRECTORY/database.sql
    echo 已将 $MTL_DATABASE_NAME 数据库备份到 $MTL_CACHE_DIRECTORY/database.sql
fi
cp -r /home/$MTL_MOONLARK_USER/.config/nonebot2 $MTL_CACHE_DIRECTORY/config
cp -r /home/$MTL_MOONLARK_USER/.local/share/nonebot2 $MTL_CACHE_DIRECTORY/data

echo ">== 当前步骤: 更新 ==<"
git pull
NEW_COMMIT=$(git rev-parse --short HEAD)
echo Moonlark 当前版本 $NEW_COMMIT
poetry run nb orm upgrade

echo ">== 当前步骤: 启动 ==<"
systemctl start "$MTL_MOONLARK_SERVICE"


# 打包
cd /tmp
cp -r $MTL_CACHE_DIRECTORY/* $MTL_BACKUP_PATH
rm -rf $MTL_BACKUP_NAME


# 上传
cd $MTL_BACKUP_PATH
git add -A
git commit -m $(date +%Y%m%d%H%M%S)
git push


# 结束
echo "Moonlark 维护已完成"