#!/bin/bash

# 检查环境变量是否存在
if [[ -z "$GIT_USERNAME" || -z "$GIT_TOKEN" ]]; then
  echo "错误: 请设置环境变量 GIT_USERNAME 和 GIT_TOKEN"
  exit 1
fi

# Git 仓库地址
REMOTE_REPO="github.com/183600/moonotel.git"

# 设置远程 URL（包含认证信息）
# 注意：URL 中不包含密码/token 的日志会被隐藏，但 URL 本身仍包含敏感信息
git remote set-url origin "https://${GIT_USERNAME}:${GIT_TOKEN}@${REMOTE_REPO}"

# 执行推送
echo "正在推送到远程仓库..."
git push