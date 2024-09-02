#!/usr/bin/env bash

set -e

update_for_version() {
    local arch="$1"; shift
    local version="$1"; shift
    local fdt="$1"; shift
    local bootargs="$1"; shift

    local vmlinuz=/boot/vmlinuz-"${version}"
    local vmlinuz_uimage="${vmlinuz}".uImage
    mkimage -q -A "${arch}" -a 40080000 -e 40080000 -T kernel -C none \
        -d "${vmlinuz}" "${vmlinuz_uimage}"

    local initrd=/boot/initrd.img-"${version}"
    local initrd_uimage="${initrd}".uImage
    mkimage -q -A "${arch}" -C none -a 0 -e 0 -T ramdisk -n uInitrd \
        -d "${initrd}" "${initrd_uimage}"

    local boot_cmd=/boot/boot-"${version}".cmd
    local boot_scr=/boot/boot-"${version}".scr

    cat > "${boot_cmd}"  <<END
setenv bootargs ${bootargs}

setenv kernel ${vmlinuz_uimage}
setenv fdt ${fdt}
setenv ramdisk ${initrd_uimage}

load mmc 0:1 \${kernel_addr_r} \${kernel}
load mmc 0:1 \${fdt_addr_r} \${fdt}
load mmc 0:1 \${ramdisk_addr_r} \${ramdisk}

bootm \${kernel_addr_r} \${ramdisk_addr_r} \${fdt_addr_r}
END
    mkimage -q -C none -A "${arch}" -T script -d "${boot_cmd}" "${boot_scr}"

    if readlink -f /vmlinuz | grep -q "${version}"; then
        pushd "$(dirname "${boot_scr}")"
            ln -sf "$(basename "${boot_scr}")" boot.scr
        popd
    fi
}

main() {
    local fdt="$1"
    local bootargs="$2"
    local arch
    arch="$(dpkg-architecture -q DEB_TARGET_ARCH)"
    local kernel_package_pattern='linux-image-*-'"${arch}"

    dpkg-query -W -f '${Package}\n' "${kernel_package_pattern}" \
            | while read -r package; do
        local version=${package##linux-image-}
        update_for_version "${arch}" "${version}" "${fdt}" "${bootargs}"
    done
}

main \
    /boot/sun50i-h5-orangepi-zero-plus.dtb \
    "root=UUID=1f741eb9-124c-4aa6-bf88-30fda94d99e4"
