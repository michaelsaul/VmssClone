#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2018 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#Script Name: 02-CreateSourceVM.sh
#Author: Michael Saul
#Version 0.2
#Description:
#  

#Source Config
source config.sh

#Get Resource Group ID
RESOURCE_GROUP_ID=$(az group show -n $RESOURCE_GROUP --query [id] -o tsv)

#Create source VM from Image
echo "Creating new source VM from Image."
az vm create \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-source \
--image $IMAGE_NAME \
--admin-username $ADMIN_USERNAME \
--vnet-name $VNET_NAME \
--subnet $SUBNET_NAME \
--size $VM_SIZE \
--ssh-key-value $SSH_KEY_VALUE \
--data-disk-size $DATA_DISK_SIZE \
--storage-sku Premium_LRS

#Enable VM for MSI
echo "Enabling MSI on Resource Group."
az vm assign-identity \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-source \
--scope $RESOURCE_GROUP_ID

#Configure scripts on Source VM
#Get VM Public IP
VM_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name ${VM_NAME}-source --query "[publicIps]" -o tsv)


#SSH to Server to configure
echo "Connecting to soure machine to configure."
#
#    ***   WARNING   ***
#    THIS IS INSECURE AND CAN OPEN YOU TO A MITM ATTACK
#    BEFORE USING IN PRODUCTION, ENABLE HOST KEY CHECKING
#    ***   WARNING   ***
#

ssh -o StrictHostKeyChecking=no -i $SSH_PRIV_KEY $ADMIN_USERNAME@$VM_IP << EOF
  #Upgrade packages
  sudo yum -y update
  #Connect data disk and mount
  sudo mkdir -p $MOUNT_POINT
  (echo n; echo p; echo 1; echo ; echo ; echo w) | sudo fdisk /dev/sdc
  sudo mkfs -t xfs /dev/sdc1
  sudo mount /dev/sdc1 $MOUNT_POINT
  echo 'Hello World!' | sudo tee $MOUNT_POINT/file1.txt
  #Download snapshot script
  sudo curl -s $SNAPSHOT_SCRIPT --output /usr/local/bin/create_snapshots.sh
  sudo chmod +x /usr/local/bin/create_snapshots.sh
  #Add snapshot script to cron
  crontab -l | { cat; echo "*/5 * * * * /usr/local/bin/create_snapshots.sh"; } | crontab -
EOF

#Finish configuration
echo "Source VM Created, ssh to ${VM_IP} to finish configration"