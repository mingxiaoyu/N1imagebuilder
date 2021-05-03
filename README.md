![Build Openwrt img](https://github.com/mingxiaoyu/N1imagebuilder/workflows/Build%20Openwrt%20img/badge.svg)


[N1Openwrt](https://github.com/mingxiaoyu/N1Openwrt)和[N1imagebuilder](https://github.com/mingxiaoyu/N1imagebuilder)是关联项目。
N1Openwrt仅仅编译为OpenWrt，不能直接为N1所用。必须通过N1imagebuilder打包成img

# mini版和plus（高大全）的处理方式，学习的了要求不高，请请请在感谢列表里加上我的名字。

基于flippy的58+o打包Phicomm N1的openwrt

用户名和密码
User: root
Password: password
Default IP: 192.168.32.2

# APP List（mini版）
 ![applist](https://github.com/mingxiaoyu/N1Openwrt/blob/master/imgs/mini.jpg?raw=true)
 
# 如何使用

1. fork项目
2. 修改n1img.yml文件 
  * 找到这句 wget  https://github.com/mingxiaoyu/N1Openwrt/releases/download/$version/openwrt-armvirt-64-default-rootfs.tar.gz
    ---> 修改为 wget [openert的URL]

  * 找到这句version=$(curl -s "https://api.github.com/repos/mingxiaoyu/N1Openwrt/releases/latest" | awk -F '"' '/tag_name/{print $4}')
    ---> 修改为 version=$(curl -s "https://api.github.com/repos/{用户名}/{仓储名}/releases/latest" | awk -F '"' '/tag_name/{print $4}')

3. 点击Actions -> Workflows -> Run workflow -> Run workflow

# N1 U盘写入刷emmc
```
cd      /root
./install-to-emmc.sh
```
如果一直卡在fdisk失败那里的解决办法：一是再多试几次，如果还不成功，则需要手动清空分区表然后再重试，具体命令:
```
  dd   if=/dev/zero   of=/dev/mmcblk2  bs=512  count=1  &&  sync
```

升级降级方法统一为：
把 update-amlogic-openwrt.sh 及 img镜像上传至  /mnt/mmcblk2p4
```
cd    /mnt/mmcblk2p4
chmod   755  update-amlogic-openwrt.sh
./update-amlogic-openwrt.sh    xxxxx.img
```

# 感激
 * [flippy](https://www.right.com.cn/forum/space-uid-285101.html)
 * [coolsnowwolf/Lede](https://github.com/coolsnowwolf/lede)

# 特别说明
  * 我对flippy内核，基本的态度是一般小版本的提升。不会提升多少的性能。约一下。。基本等于零。对于要更新科学上网的，可以单独更新[IPK](https://github.com/mingxiaoyu/lede-ssr-plus) 。没必要刷机，那么复杂。欢迎大家去下载。
  * 一般隔一段时间，我会基于上述flippy版本，更新openwrt。没特别原因不会更新flippy的内核

