# SSB Package Build System (or Super Develop Environment Build System)

## 这是什么？
这个仓库是应用: System Shell Box 的软件包构建系统

## 第三方代码？

patch/ 下的大部分内容都来自于 [termux-package](https://github.com/termux/termux-packages) 仓库

old-ndk-install.sh 来自于 [AndroidIDE-NDK](https://github.com/MrIkso/AndroidIDE-NDK)

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

## 关于spm
spm (即 SuperPackageManager) 是一个我自己编写的轻量级软件包管理程序，仅一个文件 (spm.py)

不完善，用Python写的，目前正有计划重写为cpp (see spm/spm.cpp)

当然你也可以切换为其他的包管理器 (WIP)

也许这个环境并不是那么的Super，这个包管理器也并不是那么的Super，这个环境也并不是那么的Super，但它仍在发展

欢迎贡献！

## 概况
目前所拥有的软件包:

coreutils 9.7

bash 5.2.37

zlib 1.3.1

openssl 1:3.5.0

ca-certificates 1:2025.08.12

spm 1.0.0 (WIP)

xdps 1.0.0 (WIP)