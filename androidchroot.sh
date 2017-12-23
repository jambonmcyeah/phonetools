export DISK="/dev/block/mmcblk1p1"
export MOUNTPT="/data/local/mnt"
export BINPATH="/data/local/bin"

NETPERMS="groupadd -g 3001 aid_net_bt_admin\ngroupadd -g 3002 aid_net_bt\ngroupadd -g 3003 aid_inet\ngroupadd -g 3004 aid_inet_raw\ngroupadd -g 3005 aid_inet_admin\n\ngpasswd -a root aid_net_bt_admin\ngpasswd -a root aid_net_bt\ngpasswd -a root aid_inet\ngpasswd -a root aid_inet_raw\ngpasswd -a root aid_inet_admin"
NETPERMSPATH="/tmp/netperms.sh"

#Helpers
function chrootexec
{
    $BINPATH/busybox chroot $MOUNTPT /usr/bin/env -i HOME=/root TERM="$TERM" LANG=$LANG PATH=/bin:/usr/bin:/sbin:/usr/sbin su - $1 -c $2
}

function downloadbin
{
    [ ! -d $MOUNTPT ] && mkdir -p $BINPATH
    wget https://github.com/jambonmcyeah/phonetools/releases/download/20171212/busybox -P $BINPATH
    wget https://github.com/jambonmcyeah/phonetools/releases/download/20171212/mke2fs -P $BINPATH
    chmod +x $BINPATH/busybox
    chmod +x $BINPATH/mke2fs
}

function makedirs
{
    [ ! -d $MOUNTPT ] && $BINPATH/busybox mkdir -p $MOUNTPT
}

function makefs
{
    $BINPATH/mke2fs -t ext4 -F $DISK
}

function unziprootfs
{
    $BINPATH/busybox mount $DISK $MOUNTPT
    wget $2 -O - > $MOUNTPT/rootfs
    cd $MOUNTPT
    $BINPATH/busybox tar $1 $MOUNTPT/rootfs

}

function mountparts
{
    $BINPATH/busybox mount $DISK $MOUNTPT

    $BINPATH/busybox mount -t proc /proc $MOUNTPT/proc
    $BINPATH/busybox mount --rbind /sys $MOUNTPT/sys
    $BINPATH/busybox mount --make-rslave $MOUNTPT/sys
    $BINPATH/busybox mount --rbind /dev $MOUNTPT/dev
    $BINPATH/busybox mount --make-rslave $MOUNTPT/dev
}

function grantnetperms
{
    echo -e $NETPERMS > $MOUNTPT/$NETPERMSPATH
    chrootexec root "sh $NETPERMSPATH"
    chrootexec root "rm $NETPERMSPATH"
    echo "nameserver 8.8.8.8" > $MOUNTPT/etc/resolv.conf
}

function configureservices
{
    mkdir -p "${MOUNTPT}/run/dbus" "${MOUNTPT}/var/run/dbus"
    chmod 644 "${MOUNTPT}/etc/machine-id"
    chrootexec root dbus-uuidgen > "${MOUNTPT}/etc/machine-id"
}

function startservices
{
    rm -rf $MOUNTPT/run/dbus/pid $MOUNTPT/run/dbus/messagebus.pid $MOUNTPT/var/run/dbus/pid $MOUNTPT/var/run/dbus/messagebus.pid
    $BINPATH/busybox nohup chrootexec root "dbus-daemon --system --fork" &
    disown
}

function stopservices
{
    $BINPATH/busybox kill $(cat $MOUNTPT/run/dbus/pid) $(cat $MOUNTPT/run/dbus/messagebus.pid) $($MOUNTPT/var/run/dbus/pid) $($MOUNTPT/var/run/dbus/messagebus.pid)
}

function chrootshell
{
    chrootexec root "/bin/bash"
}

function unmountparts
{
    $BINPATH/busybox umount $MOUNTPT/proc
    $BINPATH/busybox umount $MOUNTPT/sys
    $BINPATH/busybox umount $MOUNTPT/dev

    $BINPATH/busybox umount $DISK
}


$1

