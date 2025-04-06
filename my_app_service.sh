#!/bin/bash

# 进入项目目录
cd /home/wangbo/document/wangbo/my_app

# 清理任何可能存在的旧日志
rm -f my_app_server.log

# 启动Phoenix服务器并将输出重定向到日志文件
echo "启动Phoenix服务器: $(date)" >> my_app_server.log
MIX_ENV=dev mix phx.server >> my_app_server.log 2>&1