![Build Openwrt img](https://github.com/mingxiaoyu/N1imagebuilder/workflows/Build%20Openwrt%20img/badge.svg)

基于flippy的38+o和54+o打包Phicomm N1的openwrt

N1的openwrt来自我自己的另一个项目[N1Openwrt](https://github.com/mingxiaoyu/N1Openwrt)

# 如何使用

1. fork项目
2. 修改n1img.yml文件 
  * 找到这句 wget  https://github.com/mingxiaoyu/N1Openwrt/releases/download/$version/openwrt-armvirt-64-default-rootfs.tar.gz
  * 修改为 wget [openert的URL]
  * 修改flippy_url 的地址（可选，本仓储使用了flippy 38+o和54+o 的打包镜像）。
3. 点击Actions -> Workflows -> Run workflow -> Run workflow

# N1刷emmc
非54+版升级到54+版，如果一直卡在fdisk失败那里的解决办法：一是再多试几次，如果还不成功，则需要手动清空分区表然后再重试，具体命令:
```
  dd   if=/dev/zero   of=/dev/mmcblk2  bs=512  count=1  &&  sync
```

# 感激
 * [flippy](https://www.right.com.cn/forum/space-uid-285101.html)
 * [coolsnowwolf/Lede](https://github.com/coolsnowwolf/lede)

# 特别说明
  * 关于N1的云打包，我在36+o就已经开始做好了，不过那时候的版本不能写到emmc。直到GitHub 支持Ubuntu20之后才做到支持写emmc。也在那个时候把它从私有仓储改为公共仓储。也做了仓储的重置。现在GitHub上了有了云打包。我也不想说太多，参考了我的，在感谢里面加个我的名字不过分吧。可惜。。。没见过一个。就这样吧。
  * 我对flippy内核，基本的态度是一般小版本的提升。不会提升多少的性能。约一下。。基本等于零。对于要更新科学上网的，可以单独更新[IPK](https://github.com/mingxiaoyu/lede-ssr-plus) 。没必要刷机，那么复杂。欢迎大家去下载。
  * 一般隔一段时间，我会基于上述flippy版本，更新openwrt。没特别原因不会更新flippy的内核

