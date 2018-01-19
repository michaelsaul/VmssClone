!/bin/bash

#Script Name: mount_data_disk.sh
#Author: Michael Saul
#Version 0.2
#Description:
# This script will mount a data disk of a given size, and add the disk to /etc/fstab.
# To run, use the following syntax: mount_data_disk.sh DATA_DIRECTORY DISK_SIZE

if [ "$#" -ne 3 ]; then
  echo "Incorrect parameters, please use the following syntax \"mount_data_disk.sh [DATA_DIRECTORY] [DISK_SIZE] [FILE_SYSTEM]\""
  exit 1
fi

#Setup Variables
DATA_DIRECTORY=$1
DISK_SIZE=$2
FILE_SYSTEM=$3

#Create directory
echo "Creating data directory at: $DATA_DIRECTORY"
mkdir -p $DATA_DIRECTORY

#Mount volume and add to fstab
for b in $(lsblk -d | awk -v DISK_SIZE="$DISK_SIZE" '$4==DISK_SIZE {print $1}')
do
  UUID=$(blkid -s UUID -o value /dev/"$b"1)
  #Skip if UUID already exists in /etc/fstab
  grep -q "^[^#]*$UUID" /etc/fstab && echo "UUID already in /etc/fstab for $b" && continue
  echo "UUID=$UUID $DATA_DIRECTORY  $FILE_SYSTEM defaults,nofail,barrier=0 1 2" >> /etc/fstab && echo "Added $b to /etc/fstab"
  mount $DATA_DIRECTORY && echo "Mounted $b"
done