#!/bin/sh

CUSTOM="/DataVolume/custom"
C_ROOT="$CUSTOM/root"
C_OPT="$CUSTOM/opt"
C_VAR="$CUSTOM/var"

QUO="$CUSTOM/quo"

CHROOT_DIR='/var/opt/chroot'

#############################################

if [ -d $QUO ]; then
  chmod -R a+x $QUO/init.d
  chmod -R a+x $QUO/sbin
  chmod a+x $QUO/install.sh
fi

#############################################

return_quo() {
echo 'Set up customizations =)'
cd /

## CURRENT magic
# Cleaning root
rm -rf /root/* > /dev/null
mkdir -p /root
cd /root

# Mounting custom dirs
if [ ! -d $C_ROOT ]; then
  mkdir -p $C_ROOT
  mkdir -p $C_ROOT/.etc
  mkdir -p $C_ROOT/.bin
fi
mount --bind $C_ROOT /root

if [ ! -d $C_OPT ]; then
  mkdir -p $C_OPT
fi
mount --bind $C_OPT /opt

if [ ! -d $C_VAR ]; then
  mkdir -p $C_VAR
fi
mount --bind $C_VAR /var/opt

#############################################

## APT magic
echo 'APT: holding udev, enabling lenny repos instead of squeeze'
aptitude hold udev > /dev/null
sed -ie "s/deb .* squeeze/#&/g" /etc/apt/sources.list
echo 'deb http://ftp.us.debian.org/debian/ lenny main' >> /etc/apt/sources.list
aptitude clean > /dev/null

## HDD magic
echo 'HDD: fighting annoying parking'
$QUO/sbin/idle3ctl -d /dev/sda

#############################################

## MOUNT magic
  echo 'MOUNT: enabling necessary binded mounts at boot'
  $QUO/init.d/wedro_mount.sh install

#############################################

## OPTWARE magic
if [ -z "$(ls /opt)" ]; then
  echo "OPTWARE: is not installed. You should fix it with [$0 optware]"
  OPTWARE='1'
else
  script_optware
  export PATH=$PATH:/opt/bin:/opt/sbin:/root/.bin
fi

#############################################

## CHROOT magic
if [ ! -d $CHROOT_DIR ]; then
  echo "CHROOT: dir is absent. You should fix it with [$0 chroot]"
  CHROOT='1'
elif [ -z "$(ls $CHROOT_DIR)" ]; then
  echo "CHROOT: is empty. You should fix it with [$0 chroot]"
  CHROOT='1'
else
  script_chroot
fi

#############################################

## ETC magic
locale-gen

for BINARY in "$(ls $QUO/extra/bin)"; do
  cp $QUO/extra/bin/$BINARY /root/.bin
done
chmod -R a+x /root/.bin

# CRON
cp $QUO/extra/cron/mybooklive /etc/cron.daily
chmod a+x /etc/cron.daily/mybooklive
/etc/init.d/cron restart

# Settings
touch /root/.etc/chroot-services.list

if [ "$ZERO" != '1' ]; then
  /root/.etc/restore-configs.sh
else
  touch /root/.etc/restore-configs.sh
fi

# PATH
echo 'export PATH=$PATH:/root/.bin' >> /root/.profile

#############################################

export PATH=$PATH:/root/.bin

echo 'Returning finished!'
echo 'Please REBOOT WD MyBook Live after you end ALL configurations!'
source /root/.profile
}

#######################################################################################
#######################################################################################

return_optware() {
  echo 'OPTWARE: installing...'
  OLD_CWD=$CWD
  cd /tmp
  ## FIXME  
  #cp $QUO/pkg/ipkg-opt_0.99.163-10_powerpc.ipk /tmp
  $QUO/sbin/setup-mybooklive.sh > /dev/null
  cd $OLD_CWD
  ipkg update
  ipkg install htop mc screen

  script_optware
  echo 'ETC: fixing PATH for optware use'
  echo 'export PATH=$PATH:/opt/bin:/opt/sbin' >> /etc/profile
}

script_optware() {
  echo 'OPTWARE: enabling init scripts'
  $QUO/init.d/wedro_optware.sh install
}

#######################################################################################
#######################################################################################

return_chroot() {
  dpkg -i $QUO/pkg/debootstrap_1.0.10lenny1_all.deb > /dev/null
  ln -s -f /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/testing
  if [ -z "$(mount | grep '\/DataVolume\/custom\/var')" ]; then
    echo "CHROOT: custom /VAR was unmounted. Fixing..."
    mount --bind /DataVolume/custom/var /var/opt
  fi
  if [ ! -d $CHROOT_DIR ]; then
    echo "CHROOT: chroot dir was absent. Fixing..."
    mkdir -p $CHROOT_DIR
  fi
  debootstrap --variant=minbase --exclude=yaboot,udev,dbus --include=mc,aptitude testing $CHROOT_DIR http://ftp.ru.debian.org/debian/
  echo 'primary' > $CHROOT_DIR/etc/debian_chroot
  sed -i 's/^\(export PS1.*\)$/#\1/g' $CHROOT_DIR/root/.bashrc
  chroot $CHROOT_DIR apt-get -y update
  chroot $CHROOT_DIR apt-get -y install htop mc screen

  script_chroot
}

script_chroot() {
  echo 'CHROOT: enabling debian custom services in chroot'
  $QUO/init.d/wedro_chroot.sh install
}

#######################################################################################
#######################################################################################

update_packages() {
  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com AED4B06F473041FA > /dev/null
  apt-get update
}

#######################################################################################
#######################################################################################

do_zero() {
#  check internet connection
  ZERO='1'
  return_quo
  if [ "$OPTWARE" == '1' ]; then
    return_optware
  fi
  if [ "$CHROOT" == '1' ]; then
    return_chroot
  fi
  update_quo
}

#######################################################################################
#######################################################################################

update_quo() {
PATH="$PATH:/opt/sbin:/opt/bin"
if [ -z "$(ipkg status py27-mercurial | grep 'Status:' | grep 'installed')" ]; then
  ipkg update
  ipkg install py27-mercurial
fi
if [ ! -d $QUO/.hg ]; then
  mv -f $QUO $QUO.old
  hg-py2.7 clone https://dhameoelin@code.google.com/p/mybooklive/ $QUO
  echo -e '[hostfingerprints]\ncode.google.com = e2:9e:46:29:a0:fd:3c:57:a0:68:30:c5:0a:45:97:63:bf:8d:75:fc' >> $QUO/.hg/hgrc
  rm -rf $QUO.old
else
  OLD_CWD=$CWD
  cd $QUO
  hg-py2.7 pull && hg-py2.7 update
  cd $OLD_CWD
fi
chmod a+x $QUO/install.sh
chmod -R a+x $QUO/init.d
chmod -R a+x $QUO/sbin
}

#######################################################################################
#######################################################################################

update_scripts() {
  SCRIPTS="$(ls $QUO/init.d)"
  for ITEM in $SCRIPTS; do
    $QUO/init.d/$ITEM remove
    $QUO/init.d/$ITEM install
  done
}

#######################################################################################
#######################################################################################
#######################################################################################

case "$1" in
    init)
        return_quo
    ;;
    optware)
        return_optware
    ;;
    chroot)
        return_chroot
    ;;
    apt)
        update_packages
    ;;
    renew)
        update_scripts
    ;;
    update)
        update_quo
    ;;
    setup)
        do_zero
    ;;
    *)
        echo $"Usage: $0 {setup (!) | init | optware (*) | chroot (*) | update (*) | apt (*)}"
        echo "(*) - internet connection and completed [init] section required"
        echo "(!) [setup] will do complete installation on new system: [init], [optware], [chroot] and [update]"
        echo "[init] will (re)set up scripts and configs & mount /opt, /root and /var/opt into /DataVolume"
        echo "[optware] will install Optware into /opt"
        echo "[chroot] will install Debian testing via debootstrap into $CHROOT_DIR"
        echo "[update] will update QUO with mercurial (install hg-py27 before if none detected)"
        echo "[apt] will update packages in main system"
        exit 1
esac

exit $?
