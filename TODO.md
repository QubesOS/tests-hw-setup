Install kernel
--------------

host=hal9004
kver=5.15.92-ARCH+
scp -rp ../pikvm/boot-5.15/* root@$host:/boot/
rsync -av ../pikvm/modules-5.15/lib/modules/* root@$host:/lib/modules/
ssh root@$host depmod $kver
ssh root@$host ln -s "vmlinux-$kver" "/boot/Image-$kver"
ssh root@$host dracut --kver "$kver" -f
ssh root@$host cp /boot/Image-$kver /boot/vc-manual/kernel8.img
ssh root@$host cp /boot/initrd-$kver /boot/vc-manual/initrd.img
ssh root@$host cp /boot/dtbs/$kver/broadcom/\*.dtb /boot/vc-manual/
ssh root@$host cp -r /boot/dtbs/$kver/overlays /boot/vc-manual/

### restore working firmware (obsolete)

scp ../boot-working/*4x* ../boot-working/bootcode.bin root@$host:/boot/vc-manual/

Generate thor key
-----------------

ssh-keygen -t ed25519 -f /usr/local/openqa-cmds/test-1-control
ln -s test-1-control /usr/local/openqa-cmds/test-control

thor:
vim ~control/.ssh/authorized_keys

Prepare rescue image
--------------------

mkdir /srv/www/htdocs/rescue
scp -rp thor:/srv/tftp/rescue-qubes/* /srv/www/htdocs/rescue/
scp -rp thor:/srv/tftp/rescue-qubes/.treeinfo /srv/www/htdocs/rescue/

# adjust (ssh keys) /srv/www/htdocs/rescue/ks.cfg

# update IP!!!
cat > /srv/www/htdocs/rescue/grub.cfg <<EOF
set default=0
set timeout=1

menuentry "Rescue" {
	#multiboot2 /images/pxeboot/xen.gz placeholder smt=off
	#module2 /images/pxeboot/vmlinuz inst.stage2=http://192.168.190.135/rescue plymouth.ignore-serial-consoles inst.sshd rescue inst.ks=http://192.168.190.135/rescue/ks.cfg
	#module2 /images/pxeboot/initrd.img
	linux /images/pxeboot/vmlinuz inst.stage2=http://192.168.190.135/rescue plymouth.ignore-serial-consoles inst.sshd rescue inst.ks=http://192.168.190.135/rescue/ks.cfg
	initrd /images/pxeboot/initrd.img
}
EOF

mkfs.ext4 -d /srv/www/htdocs/rescue /root/boot-disk-rescue2.img


zypper in dosfstools
truncate -s 1G /root/boot-disk-rescue2.img
fdisk /root/boot-disk-rescue2.img
g
n


+50M
t
1
n



w
losetup -P -f /root/boot-disk-rescue2.img
mkfs.vfat -n EFI /dev/loop0p1
mount /dev/loop0p1 /mnt
cp -a /srv/www/htdocs/rescue/EFI /mnt/
umount /mnt
mkfs.ext4 -d /srv/www/htdocs/rescue -L RESCUE /dev/loop0p2
losetup -d /dev/loop0



gitlab-runner
-------------

Get runner token:
curl --request POST "https://gitlab.com/api/v4/runners" --form "token=<registration-token>" --form "description=hal9002" --form "tag_list=hal9002"

usermod --add-subuids 362144-$[ 362144 + 65536 ] gitlab-runner
usermod --add-subgids 362144-$[ 362144 + 65536 ] gitlab-runner
