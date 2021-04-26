#!/bin/bash

WORK_DIR="${PWD}/tmp"

source make.env

TGT_IMG="${WORK_DIR}/openwrt_k${KERNEL_VERSION}${SUBVER}.img"

cd $WORK_DIR
xz -z $TGT_IMG
