# SSB Package Build System

## 这是什么？
这个仓库是应用: System Shell Box 的软件包构建系统

## 第三方代码？

patch/ 下的大部分内容都来自于 [termux-package] (https://github.com/termux/termux-packages) 仓库

old-ndk-install.sh 来自于 [AndroidIDE-NDK] (https://github.com/MrIkso/AndroidIDE-NDK)

我建议使用install-ndk-for-termux.sh来安装NDK

## 如何构建？
若您是在手机上构建:

1. 下载并安装termux
2. 克隆这个仓库
3. 运行 ndk.sh 安装 ndk
4. 运行 build.sh 来启动构建系统
5. 配置您的构建并运行

若您是在电脑上构建:
1. 克隆这个仓库
2. 运行 build.sh 来启动构建系统
3. 找到你的ndk安装位置 (最推荐的版本是27c，路径要精确到版本号)
4. 进入build设置，并修改ndk目录
5. 配置您的构建并运行

重新构建时，请务必完全删除 base 目录并且重新解压 base.zip

## 概况
目前所拥有的软件包:
coreutils 9.7
bash 5.2.37 (WIP)