#!/bin/bash

# check cmd param
if [ "$1" == "" ];then
	echo "用法: $0 xxx.img"
	exit 1
fi

# check image file
IMG_NAME=$1
if [ ! -f "$IMG_NAME" ];then
	echo "$IMG_NAME 不存在!"
	exit 1
fi

# find boot partition 
BOOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | awk '$3~/^part$/ && $5 ~ /^\/boot$/ {print $0}')
if [ "${BOOT_PART_MSG}" == "" ];then
	echo "Boot 分区不存在，或是没有正确挂载, 因此无法继续升级!"
	exit 1
fi

BR_FLAG=1
echo -ne "你想要备份旧版本的配置，并将其还原到升级后的系统中吗? y/n [y]\b\b"
read yn
case $yn in
    n*|N*) BR_FLAG=0;;
esac

BOOT_NAME=$(echo $BOOT_PART_MSG | awk '{print $1}')
BOOT_PATH=$(echo $BOOT_PART_MSG | awk '{print $2}')
BOOT_UUID=$(echo $BOOT_PART_MSG | awk '{print $4}')

# find root partition 
ROOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | awk '$3~/^part$/ && $5 ~ /^\/$/ {print $0}')
ROOT_NAME=$(echo $ROOT_PART_MSG | awk '{print $1}')
ROOT_PATH=$(echo $ROOT_PART_MSG | awk '{print $2}')
ROOT_UUID=$(echo $ROOT_PART_MSG | awk '{print $4}')
case $ROOT_NAME in 
  mmcblk2p2) NEW_ROOT_NAME=mmcblk2p3
	     NEW_ROOT_LABEL=EMMC_ROOTFS2
	     ;;
  mmcblk2p3) NEW_ROOT_NAME=mmcblk2p2
	     NEW_ROOT_LABEL=EMMC_ROOTFS1
	     ;;
          *) echo "ROOTFS 分区位置不正确, 因此无法继续升级!"
             exit 1
             ;;
esac

# find new root partition
NEW_ROOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | grep "${NEW_ROOT_NAME}" | awk '$3 ~ /^part$/ && $5 !~ /^\/$/ && $5 !~ /^\/boot$/ {print $0}')
if [ "${NEW_ROOT_PART_MSG}" == "" ];then
        echo "新的 ROOTFS 分区不存在, 因此无法继续升级!"
	exit 1
fi
NEW_ROOT_NAME=$(echo $NEW_ROOT_PART_MSG | awk '{print $1}')
NEW_ROOT_PATH=$(echo $NEW_ROOT_PART_MSG | awk '{print $2}')
NEW_ROOT_UUID=$(echo $NEW_ROOT_PART_MSG | awk '{print $4}')
NEW_ROOT_MP=$(echo $NEW_ROOT_PART_MSG | awk '{print $5}')

# losetup
losetup -f -P $IMG_NAME
if [ $? -eq 0 ];then
	LOOP_DEV=$(losetup | grep "$IMG_NAME" | awk '{print $1}')
	if [ "$LOOP_DEV" == "" ];then
		echo "loop device not found!"
		exit 1
	fi
else
	echo "losetup $IMG_FILE failed!"
	exit 1
fi
WAIT=3
echo -n "The loopdev is $LOOP_DEV, wait ${WAIT} seconds "
while [ $WAIT -ge 1 ];do
	echo -n "."
	sleep 1
	WAIT=$(( WAIT - 1 ))
done
echo

# umount loop devices (openwrt will auto mount some partition)
MOUNTED_DEVS=$(lsblk -l -o NAME,PATH,MOUNTPOINT | grep "$LOOP_DEV" | awk '$3 !~ /^$/ {print $2}')
for dev in $MOUNTED_DEVS;do
	while : ;do
		echo -n "卸载 $dev ... "
		umount -f $dev
		sleep 1
		mnt=$(lsblk -l -o NAME,PATH,MOUNTPOINT | grep "$dev" | awk '$3 !~ /^$/ {print $2}')
		if [ "$mnt" == "" ];then
			echo "成功"
			break
		else 
			echo "重试 ..."
		fi
	done
done

# mount src part
WORK_DIR=$PWD
P1=${WORK_DIR}/boot
P2=${WORK_DIR}/root
mkdir -p $P1 $P2
echo -n "挂载 ${LOOP_DEV}p1 -> ${P1} ... "
mount -t vfat -o ro ${LOOP_DEV}p1 ${P1}
if [ $? -ne 0 ];then
	echo "挂载失败!"
	losetup -D
	exit 1
else 
	echo "成功"
fi	

echo -n "挂载 ${LOOP_DEV}p2 -> ${P2} ... "
mount -t btrfs -o ro,compress=zstd ${LOOP_DEV}p2 ${P2}
if [ $? -ne 0 ];then
	echo "挂载失败!"
	umount -f ${P1}
	losetup -D
	exit 1
else
	echo "成功"
fi	

#format NEW_ROOT
echo "卸载 ${NEW_ROOT_MP}"
umount -f "${NEW_ROOT_MP}"
if [ $? -ne 0 ];then
	echo "卸载失败, 请重启后再试一次!"
	umount -f ${P1}
	umount -f ${P2}
	losetup -D
	exit 1
fi

echo "格式化 ${NEW_ROOT_PATH}"
NEW_ROOT_UUID=$(uuidgen)
mkfs.btrfs -f -U ${NEW_ROOT_UUID} -L ${NEW_ROOT_LABEL} -m single ${NEW_ROOT_PATH}
if [ $? -ne 0 ];then
	echo "格式化 ${NEW_ROOT_PATH} 失败!"
	umount -f ${P1}
	umount -f ${P2}
	losetup -D
	exit 1
fi

echo "挂载 ${NEW_ROOT_PATH} -> ${NEW_ROOT_MP}"
mount -t btrfs -o compress=zstd ${NEW_ROOT_PATH} ${NEW_ROOT_MP}
if [ $? -ne 0 ];then
	echo "挂载 ${NEW_ROOT_PATH} -> ${NEW_ROOT_MP} 失败!"
	umount -f ${P1}
	umount -f ${P2}
	losetup -D
	exit 1
fi

# begin copy rootfs
cd ${NEW_ROOT_MP}
echo "开始复制数据， 从 ${P2} 到 ${NEW_ROOT_MP} ..."
ENTRYS=$(ls)
for entry in $ENTRYS;do
	if [ "$entry" == "lost+found" ];then
		continue
	fi
	echo -n "移除旧的 $entry ... "
	rm -rf $entry 
	if [ $? -eq 0 ];then
		echo "成功"
	else
		echo "失败"
		exit 1
	fi
done
echo

echo -n "创建文件夹 ... "
mkdir -p .reserved bin boot dev etc lib opt mnt overlay proc rom root run sbin sys tmp usr www
ln -sf lib/ lib64
ln -sf tmp/ var
echo "完成"
echo

COPY_SRC="root etc bin sbin lib opt usr www"
echo "复制数据 ... "
for src in $COPY_SRC;do
	echo -n "复制 $src ... "
        (cd ${P2} && tar cf - $src) | tar mxf -
        sync
        echo "完成"
done
[ -d /mnt/mmcblk2p4/docker ] || mkdir -p /mnt/mmcblk2p4/docker
rm -rf opt/docker && ln -sf /mnt/mmcblk2p4/docker/ opt/docker

if [ -f /mnt/${NEW_ROOT_NAME}/etc/config/AdGuardHome ];then
	[ -d /mnt/mmcblk2p4/AdGuardHome/data ] || mkdir -p /mnt/mmcblk2p4/AdGuardHome/data
      	if [ ! -L /usr/bin/AdGuardHome ];then
		[ -d /usr/bin/AdGuardHome ] && \
		cp -a /usr/bin/AdGuardHome/* /mnt/mmcblk2p4/AdGuardHome/

	fi
	ln -sf /mnt/mmcblk2p4/AdGuardHome /mnt/${NEW_ROOT_NAME}/usr/bin/AdGuardHome
fi

BOOTLOADER="./lib/u-boot/hk1box-bootloader.img"
if [ -f ${BOOTLOADER} ];then
	if dmesg | grep 'AMedia X96 Max+';then
		echo "*** 写入 u-boot ... "
		# write u-boot
		dd if=${BOOTLOADER} of=/dev/mmcblk2 bs=1 count=442 conv=fsync
		dd if=${BOOTLOADER} of=/dev/mmcblk2 bs=512 skip=1 seek=1 conv=fsync
		echo "*** 完成"
	fi
fi

rm -f /mnt/${NEW_ROOT_NAME}/root/install-to-emmc.sh
sync
echo "复制完成"
echo

BACKUP_LIST=$(${P2}/usr/sbin/flippy -p)
if [ $BR_FLAG -eq 1 ];then
    # restore old config files
    OLD_RELEASE=$(grep "DISTRIB_REVISION=" /etc/openwrt_release | awk -F "'" '{print $2}'|awk -F 'R' '{print $2}' | awk -F '.' '{printf("%02d%02d%02d\n", $1,$2,$3)}')
    NEW_RELEASE=$(grep "DISTRIB_REVISION=" ./etc/uci-defaults/99-default-settings | awk -F "'" '{print $2}'|awk -F 'R' '{print $2}' | awk -F '.' '{printf("%02d%02d%02d\n", $1,$2,$3)}')
    if [ ${OLD_RELEASE} -le 200311 ] && [ ${NEW_RELEASE} -ge 200319 ];then
	    mv ./etc/config/shadowsocksr ./etc/config/shadowsocksr.${NEW_RELEASE}
    fi
    mv ./etc/config/qbittorrent ./etc/config/qbittorrent.orig

    echo -n "开始还原从旧系统备份的配置文件 ... "
    (
      cd /
      eval tar czf ${NEW_ROOT_MP}/.reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null
    )
    tar xzf ${NEW_ROOT_MP}/.reserved/openwrt_config.tar.gz
    if [ ${OLD_RELEASE} -le 200311 ] && [ ${NEW_RELEASE} -ge 200319 ];then
	    mv ./etc/config/shadowsocksr ./etc/config/shadowsocksr.${OLD_RELEASE}
	    mv ./etc/config/shadowsocksr.${NEW_RELEASE} ./etc/config/shadowsocksr
    fi
    if grep 'config qbittorrent' ./etc/config/qbittorrent; then
	rm -f ./etc/config/qbittorrent.orig
    else
	mv ./etc/config/qbittorrent.orig ./etc/config/qbittorrent
    fi
    sed -e "s/option wan_mode 'false'/option wan_mode 'true'/" -i ./etc/config/dockerman 2>/dev/null
    sed -e 's/config setting/config verysync/' -i ./etc/config/verysync
    sync
    echo "完成"
    echo
fi

echo "修改配置文件 ... "
rm -f "./etc/rc.local.orig" "./usr/bin/mk_newpart.sh" "./etc/part_size"
rm -rf "./opt/docker" && ln -sf "/mnt/mmcblk2p4/docker" "./opt/docker"
cat > ./etc/fstab <<EOF
UUID=${NEW_ROOT_UUID} / btrfs compress=zstd 0 1
LABEL=EMMC_BOOT /boot vfat defaults 0 2
#tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF

cat > ./etc/config/fstab <<EOF
config global
        option anon_swap '0'
        option anon_mount '1'
        option auto_swap '0'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'

config mount
        option target '/overlay'
        option uuid '${NEW_ROOT_UUID}'
        option enabled '1'
        option enabled_fsck '1'
        option fstype 'btrfs'
        option options 'compress=zstd'

config mount
        option target '/boot'
        option label 'EMMC_BOOT'
        option enabled '1'
        option enabled_fsck '0'
        option fstype 'vfat'
                
EOF

rm -f ./etc/bench.log
cat >> ./etc/crontabs/root << EOF
17 3 * * * /etc/coremark.sh
EOF

sed -e 's/ttyAMA0/ttyAML0/' -i ./etc/inittab
sed -e 's/ttyS0/tty0/' -i ./etc/inittab
sss=$(date +%s)
ddd=$((sss/86400))
sed -e "s/:0:0:99999:7:::/:${ddd}:0:99999:7:::/" -i ./etc/shadow
if [ `grep "sshd:x:22:22" ./etc/passwd | wc -l` -eq 0 ];then
    echo "sshd:x:22:22:sshd:/var/run/sshd:/bin/false" >> ./etc/passwd
    echo "sshd:x:22:sshd" >> ./etc/group
    echo "sshd:x:${ddd}:0:99999:7:::" >> ./etc/shadow
fi

if [ $BR_FLAG -eq 1 ];then
    #cp ${P2}/etc/config/passwall_rule/chnroute ./etc/config/passwall_rule/ 2>/dev/null
    #cp ${P2}/etc/config/passwall_rule/gfwlist.conf ./etc/config/passwall_rule/ 2>/dev/null
    sync
    echo "完成"
    echo
fi
eval tar czf .reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null

rm -f ./etc/part_size ./usr/bin/mk_newpart.sh
if [ -x ./usr/sbin/balethirq.pl ];then
    if grep "balethirq.pl" "./etc/rc.local";then
	echo "balance irq is enabled"
    else
	echo "enable balance irq"
        sed -e "/exit/i\/usr/sbin/balethirq.pl" -i ./etc/rc.local
    fi
fi
mv ./etc/rc.local ./etc/rc.local.orig

cat > ./etc/rc.local <<EOF
if [ ! -f /etc/rc.d/*dockerd ];then
	/etc/init.d/dockerd enable
	/etc/init.d/dockerd start
fi
mv /etc/rc.local.orig /etc/rc.local
exec /etc/rc.local
exit
EOF

chmod 755 ./etc/rc.local*

cd ${WORK_DIR}
 
echo "开始复制数据， 从 ${P1} 到 /boot ..."
cd /boot
echo -n "删除旧的 boot 文件 ..."
cp uEnv.txt /tmp/uEnv.txt
U_BOOT_EMMC=0
[ -f u-boot.emmc ] && U_BOOT_EMMC=1
rm -rf *
echo "完成"
echo -n "复制新的 boot 文件 ... " 
(cd ${P1} && tar cf - . ) | tar mxf -
[ $U_BOOT_EMMC -eq 1 ] && cp u-boot.sd u-boot.emmc
rm -f aml_autoscript* s905_autoscript*
sync
echo "完成"
echo

echo -n "更新 boot 参数 ... "
if [ -f /tmp/uEnv.txt ];then
	lines=$(wc -l < /tmp/uEnv.txt)
	lines=$(( lines - 1 ))
	head -n $lines /tmp/uEnv.txt > uEnv.txt
	cat >> uEnv.txt <<EOF
APPEND=root=UUID=${NEW_ROOT_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF
else
	cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

FDT=/dtb/amlogic/meson-sm1-x96-max-plus.dtb

APPEND=root=UUID=${NEW_ROOT_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF
fi

sync
echo "完成"
echo

cd $WORK_DIR
umount -f ${P1} ${P2}
losetup -D
rmdir ${P1} ${P2}
echo "升级已完成, 请重启系统!"
echo
