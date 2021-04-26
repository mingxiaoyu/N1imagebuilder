#!/bin/bash

WORK_DIR="${PWD}/tmp"

source make.env
SOC=s905d
BOARD=n1

TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"

cd $WORK_DIR
xz -z $TGT_IMG
rm -rf TGT_IMG
