export DISK="/dev/block/mmcblk1p1"
export MOUNTPT="/data/local/mnt"
export BINPATH="/data/local/bin"

#NETPERMS="groupadd -g 3001 aid_net_bt_admin\ngroupadd -g 3002 aid_net_bt\ngroupadd -g 3003 aid_inet\ngroupadd -g 3004 aid_inet_raw\ngroupadd -g 3005 aid_inet_admin\n\ngpasswd -a root aid_net_bt_admin\ngpasswd -a root aid_net_bt\ngpasswd -a root aid_inet\ngpasswd -a root aid_inet_raw\ngpasswd -a root aid_inet_admin"
NETPERMSPATH="/tmp/netperms.sh"

netpermsscript()
{
    cat <<EOF
        groupadd -g 3001 aid_net_bt_admin
        groupadd -g 3002 aid_net_bt
        groupadd -g 3003 aid_inet
        groupadd -g 3004 aid_inet_raw
        groupadd -g 3005 aid_inet_admin

        gpasswd -a $1 aid_net_bt_admin
        gpasswd -a $1 aid_net_bt
        gpasswd -a $1 aid_inet
        gpasswd -a $1 aid_inet_raw
        gpasswd -a $1 aid_inet_admin
EOF
}

#Helpers
chrootexec()
{
    $BINPATH/busybox chroot $MOUNTPT /usr/bin/env -i HOME=/root TERM="$TERM" LANG=$LANG PATH=/bin:/usr/bin:/sbin:/usr/sbin su - $1 -c "$2"
}

downloadbin()
{
    [ ! -d $MOUNTPT ] && mkdir -p $BINPATH
    wget https://github.com/jambonmcyeah/phonetools/releases/download/20171212/busybox -P $BINPATH
    wget https://github.com/jambonmcyeah/phonetools/releases/download/20171212/mke2fs -P $BINPATH
    chmod +x $BINPATH/busybox
    chmod +x $BINPATH/mke2fs
}

makedirs()
{
    [ ! -d $MOUNTPT ] && $BINPATH/busybox mkdir -p $MOUNTPT
}

makefs()
{
    $BINPATH/mke2fs -t ext4 -F $DISK
}

unziprootfs()
{
    $BINPATH/busybox mount $DISK $MOUNTPT
    wget $2 -O - > $MOUNTPT/rootfs
    cd $MOUNTPT
    $BINPATH/busybox tar $1 $MOUNTPT/rootfs

}

mountparts()
{
    $BINPATH/busybox mount $DISK $MOUNTPT

    $BINPATH/busybox mount -t proc /proc $MOUNTPT/proc
    $BINPATH/busybox mount --rbind /sys $MOUNTPT/sys
    $BINPATH/busybox mount --make-rslave $MOUNTPT/sys
    $BINPATH/busybox mount --rbind /dev $MOUNTPT/dev
    $BINPATH/busybox mount --make-rslave $MOUNTPT/dev
}

grantnetperms()
{
    netpermsscript > $MOUNTPT/$NETPERMSPATH
    chrootexec root "/bin/bash ${NETPERMSPATH}"
    chrootexec root "rm ${NETPERMSPATH}"
    echo "nameserver 8.8.8.8" > $MOUNTPT/etc/resolv.conf
}

configureservices()
{
    mkdir -p "${MOUNTPT}/run/dbus" "${MOUNTPT}/var/run/dbus"
    chrootexec root dbus-uuidgen > "${MOUNTPT}/etc/machine-id"
    chrootexec root "chmod 644 /etc/machine-id"
}

startservices()
{
    rm -rf $MOUNTPT/run/dbus/pid $MOUNTPT/run/dbus/messagebus.pid $MOUNTPT/var/run/dbus/pid $MOUNTPT/var/run/dbus/messagebus.pid
    chrootexec root "nohup dbus-daemon --system --fork" &
    disown
}

stopservices()
{
    $BINPATH/busybox kill $(cat $MOUNTPT/run/dbus/pid) $(cat $MOUNTPT/run/dbus/messagebus.pid) $($MOUNTPT/var/run/dbus/pid) $($MOUNTPT/var/run/dbus/messagebus.pid)
}

chrootshell()
{
    chrootexec root "/bin/bash"
}

unmountparts()
{
    $BINPATH/busybox umount -lf $MOUNTPT/proc
    $BINPATH/busybox umount -lf $MOUNTPT/sys
    $BINPATH/busybox umount -lf $MOUNTPT/dev

    $BINPATH/busybox umount $DISK
}


#distros
install-opensuse()
{
    downloadbin
    makedirs
    makefs
    unziprootfs xjvvf "http://download.opensuse.org/ports/armv7hl/factory/images/openSUSE-Tumbleweed-ARM-X11.armv7-rootfs.armv7l-Current.tbz"
    mountparts
    grantnetperms
    configureservices
}

start-opensuse()
{
    mountparts
    startservices
    chrootshell
}

$1

