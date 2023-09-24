#!/bin/sh
#
# Build scipt for archlinux image on MangoPi MQ-Pro (risc-v 64)
#
# Derived from scripts by sehraf: https://github.com/sehraf/d1-riscv-arch-image-builder
#

# global variables
export CROSS_COMPILE='riscv64-linux-gnu-'
export ARCH='riscv'
export SOURCES=src
export OUT_DIR=output
export DOWNLOADS=downloads
export SBI_PLATFORM=generic
export MAINDIR=$(pwd)
export KERNEL_VERSION=6.5.4
export CORES=$(nproc)
export IMAGE=archboot.img
export TEMPDIR=tmp
export MOUNTDIR=mnt

# repositories
export OPEN_SBI_SRV=https://github.com/riscv-software-src/opensbi/archive/refs/tags/
export OPEN_SBI_RELEASE=1.3.1
export SOURCE_UBOOT='https://github.com/smaeul/u-boot'
export COMMIT_UBOOT='329e94f16ff84f9cf9341f8dfdff7af1b1e6ee9a' # equals d1-2022-10-31
export TAG_UBOOT='d1-2022-10-31'
export KERNEL_SOURCE=https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
export SOURCE_RTL8723='https://github.com/lwfinger/rtl8723ds.git'
export ROOTFS='archriscv-2023-09-13.tar.zst'
export ROOTFS_DL="https://archriscv.felixc.at/images/${ROOT_FS}"

# build steps

# prepare sources
mkdir -p ${SOURCES}
mkdir -p ${DOWNLOADS}
mkdir -p ${OUT_DIR}
mkdir -p ${TEMPDIR}
mkdir -p ${MOUNTDIR}


# delete sources 
rm -Rf ${SOURCES}/*

#
# 1. OpenSBI
#
export SBI_FILENAME=v${OPEN_SBI_RELEASE}.tar.gz
if [ ! -f "${DOWNLOADS}/${SBI_FILENAME}" ]; then
    wget -P ${DOWNLOADS} ${OPEN_SBI_SRV}/${SBI_FILENAME}
fi

if [ ! -f "${OUT_DIR}/fw_dynamic.bin" ]; then
    tar xvzf ${DOWNLOADS}/${SBI_FILENAME} -C ${SOURCES}
    cd ${SOURCES}/opensbi-${OPEN_SBI_RELEASE}
    make PLATFORM=${SBI_PLATFORM}
    cp build/platform/generic/firmware/fw_dynamic.bin ${MAINDIR}/${OUT_DIR}
    cd ${MAINDIR}
fi


#
# 2. U-Boot
#
if [ ! -f "${OUT_DIR}/u-boot-sunxi-with-spl.bin" ]; then
    DIR='u-boot'
    cd ${SOURCES}
    git clone --depth 1 "${SOURCE_UBOOT}" -b "${TAG_UBOOT}"
    cd ${DIR}
    git checkout ${COMMIT_UBOOT}
    
    make nezha_defconfig
    make OPENSBI="${MAINDIR}/${OUT_DIR}/fw_dynamic.bin" -j ${CORES}
    cp u-boot-sunxi-with-spl.bin ${MAINDIR}/${OUT_DIR}/
    cd ${MAINDIR}
fi

#
# 3. Kernel
#
if [ ! -f "${DOWNLOADS}/linux-${KERNEL_VERSION}.tar.xz" ]; then
    wget -P ${DOWNLOADS} ${KERNEL_SOURCE}
fi

if [ ! -f "${OUT_DIR}/Image" ] || [ ! -f "${OUT_DIR}/Image.gz" ];  then
    tar xf ${DOWNLOADS}/linux-${KERNEL_VERSION}.tar.xz -C ${SOURCES}
    cd ${SOURCES}
    mv linux-${KERNEL_VERSION} linux
    mkdir linux-build
    cd linux
    
    # create default config
    make O=../linux-build defconfig
    
    # patch needed options
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SYSVIPC
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SYSVIPC_SYSCTL
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SWAP
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_ZSWAP
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_PANEL
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_SUN4I
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_SUN6I_DSI
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_SUN8I_DW_HDMI
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_SUN8I_MIXER
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_SUN8I_TCON_TOP
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SUN20I_PPU
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_BINFMT_MISC
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DRM_DW_HDMI
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_FIRMWARE_EDID
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_BACKLIGHT_CLASS_DEVICE
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_BACKLIGHT_PWM
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DMA_SUN6I
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_UDMABUF
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_STAGING
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_STAGING_MEDIA
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_MEDIA_SUPPORT 
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_MEDIA_CONTROLLER 
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_MEDIA_CONTROLLER_REQUEST_API
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_V4L_MEM2MEM_DRIVERS
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_VIDEO_SUNXI
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_VIDEO_SUNXI_CEDRUS
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SND_SUN20I_CODEC
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SND_SUN4I_I2S
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_SND_SUN50I_DMIC
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_CONNECTOR
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_PROC_EVENTS
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_ZRAM
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_ZRAM_DEF_COP_LZORLE
    ./scripts/config --file "../linux-build/.config" --module CONFIG_CFG80211
    
    # enable debug messages
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DEBUG_INFO
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_DEBUG_DRIVER
    
    # SOC selection
    ./scripts/config --file "../linux-build/.config" --enable CONFIG_ARCH_SUNXI
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_ARCH_MICROCHIP_POLARFIRE
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_SOC_MICROCHIP_POLARFIRE
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_ARCH_RENESAS
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_ARCH_SIFIVE
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_SOC_SIFIVE
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_ARCH_STARFIVE
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_SOC_STARFIVE
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_ARCH_THEAD
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_ARCH_VIRT
    ./scripts/config --file "../linux-build/.config" --disable CONFIG_SOC_VIRT
    
    # default new options
    make O=../linux-build olddefconfig
    
    # build kernel
    cd ..
    make -j ${CORES} -C linux-build
    
    
    KERNEL_RELEASE=$(make -C linux-build -s kernelversion)
    echo "compiled kernel version '$KERNEL_RELEASE'"

    cp linux-build/arch/riscv/boot/Image.gz "${MAINDIR}/${OUT_DIR}"
    cp linux-build/arch/riscv/boot/Image "${MAINDIR}/${OUT_DIR}"

    # prepare modules
    mkdir linux-modules
    make INSTALL_MOD_PATH="../linux-modules" KERNELRELEASE="${KERNEL_RELEASE}" -C linux-build modules_install
    sudo rm -Rf ${MAINDIR}/${OUT_DIR}/modules
    mv linux-modules/lib/modules "${MAINDIR}/${OUT_DIR}"
    cd $MAINDIR
fi

if [ ! -f "${OUT_DIR}/8723ds.ko" ]; then
    cd ${SOURCES}
    git clone "${SOURCE_RTL8723}"
    cd rtl8723ds
    make KSRC=../linux-build -j ${CORES} modules || true
    cd ${MAINDIR}
    cp src/rtl8723ds/8723ds.ko "${OUT_DIR}"
fi

if [ ! -f ${DOWNLOADS}/${ROOTFS} ]; then
    echo Downloading root fs
    wget -P ${DOWNLOADS} ${ROOTFS_DL}/${ROOTFS}
fi

# now prepare sdcard image and run depmod for module meta files to be created
echo Creating SD image

dd if=/dev/zero of=${TEMPDIR}/${IMAGE} bs=4096 count=512288
sudo losetup -f -P ${TEMPDIR}/${IMAGE}
DEVICE=$(losetup -l |grep ${TEMPDIR}/${IMAGE}  |awk '{ print $1 }')
if [ "${DEVICE}" == "" ]; then
    echo "Loop device not created, exiting!"
    exit -1
fi
sudo parted -s -a optimal -- "${DEVICE}" mklabel gpt
sudo parted -s -a optimal -- "${DEVICE}" mkpart primary fat32 40MiB 1024MiB
sudo parted -s -a optimal -- "${DEVICE}" mkpart primary ext4 1064MiB 100%
sudo partprobe "${DEVICE}"

sudo mkfs.ext2 -F -L boot "${DEVICE}p1"
sudo mkfs.ext4 -F -L root "${DEVICE}p2"

# flash boot things
sudo dd if="${OUT_DIR}/u-boot-sunxi-with-spl.bin" of="${DEVICE}" bs=1024 seek=128

sudo mount "${DEVICE}p2" "${MOUNTDIR}"
sudo mkdir -p "${MOUNTDIR}/boot"
sudo mount "${DEVICE}p1" "${MOUNTDIR}/boot"

# unpack root fs
sudo tar -x --zstd -f ${DOWNLOADS}/${ROOTFS} -C ${MOUNTDIR}

# copy kernel and modules
sudo cp "${OUT_DIR}/Image.gz" "${OUT_DIR}/Image" "${MOUNTDIR}/boot/"

sudo mkdir -p "${MOUNTDIR}/lib/modules"
sudo cp -a "${OUT_DIR}/modules/${KERNEL_VERSION}" "${MOUNTDIR}/lib/modules"
sudo install -D -p -m 644 "${OUT_DIR}/8723ds.ko" "${MOUNTDIR}/lib/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/8723ds.ko"

sudo rm "${MOUNTDIR}/lib/modules/${KERNEL_VERSION}/build"
sudo rm "${MOUNTDIR}/lib/modules/${KERNEL_VERSION}/source"

sudo depmod -a -b "${MOUNTDIR}" "${KERNEL_VERSION}"
echo '8723ds' >> "${OUT_DIR}/8723ds.conf"
sudo cp "${OUT_DIR}/8723ds.conf" "${MOUNTDIR}/etc/modules-load.d"

# create boot-config
sudo mkdir -p "${MOUNTDIR}/boot/extlinux"
(
    echo "label default
    linux   /Image
    append  earlycon=sbi console=ttyS0,115200n8 root=/dev/mmcblk0p2 rootwait cma=96M"
) > ${OUT_DIR}/extlinux.conf
sudo mv ${OUT_DIR}/extlinux.conf "${MOUNTDIR}/boot/extlinux/extlinux.conf"


# create fstab
(
    echo '# <device>    <dir>        <type>        <options>            <dump> <pass>
LABEL=boot    /boot        ext2          rw,defaults,noatime  0      1
LABEL=root    /            ext4          rw,defaults,noatime  0      2'
) > ${OUT_DIR}/fstab
sudo mv ${OUT_DIR}/fstab "${MOUNTDIR}/etc/fstab"

# set hostname
echo 'archrv' > ${OUT_DIR}/hostname
sudo mv ${OUT_DIR}/hostname "${MOUNTDIR}/etc/"

# unmount and compress image
sudo umount -R "${MOUNTDIR}"

cd ${TEMPDIR}
tar -c --zstd -f ${IMAGE}.xz ${IMAGE}

cd ${MAINDIR}

echo DONE! Bootable image in ${TEMPDIR}



