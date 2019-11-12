#!/bin/bash

# Prepare zero superblock
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f,g,h}
# Create RAID 1
mdadm --create --verbose /dev/md0 -l 1 -n 2 /dev/sd{b,c}
# Create RAID 6
mdadm --create --verbose /dev/md1 -l 6 -n 5 /dev/sd{d,e,f,g,h}
# Create mdadm.config
mkdir /etc/mdadm
chmod 757 /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
# Brake RAID 6
mdadm /dev/md1 --fail /dev/sdf
# Remove brake disk
mdadm /dev/md1 --remove /dev/sdf
# Replace braked dist and rebuild RAID
mdadm /dev/md1 --add /dev/sdf
# Create GPT on RAID 6
parted -s /dev/md1 mklabel gpt
# Create partitions
parted /dev/md1 mkpart primary ext4 0% 20%
parted /dev/md1 mkpart primary ext4 20% 40%
parted /dev/md1 mkpart primary ext4 40% 60%
parted /dev/md1 mkpart primary ext4 60% 80%
parted /dev/md1 mkpart primary ext4 80% 100%
# Create fail system on new partitions
for i in $(seq 1 5);
do mkfs.ext4 /dev/md1p$i;
done
# Mount partitions to directories
# Create directories
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5);
do mount /dev/md1p$i /raid/part$i;
done
