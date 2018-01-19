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

#Script Name: 03-UpdateImage.sh
#Author: Michael Saul
#Version 0.2
#Description:
#  

#Source Config
source config.sh

#Create a disk from the latest snapshot
echo "Creating disk from latest snapshot."
az disk create \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2_disk2 \
--source $SNAPSHOT_NAME \
--sku Premium_LRS \
--size $DATA_DISK_SIZE \

#Create a VM from the image and connect the new disk

#Create source VM
echo "Creating template2 VM."
az vm create \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2 \
--image $IMAGE_NAME \
--admin-username $ADMIN_USERNAME \
--vnet-name $VNET_NAME \
--subnet $SUBNET_NAME \
--size $VM_SIZE \
--ssh-key-value $SSH_KEY_VALUE \
--attach-data-disks ${VM_NAME}-template2_disk2 \
--storage-sku Premium_LRS

#Get VM Public IP
VM_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name ${VM_NAME}-template2 --query "[publicIps]" -o tsv)

#Prepare VM for image capture
#Directions here: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image
#First need to run command in VM: sudo waagent -deprovision+user

#SSH to Server to configure
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
  sudo mount /dev/sdc1 $MOUNT_POINT
  #echo 'Hello World!' | sudo tee $MOUNT_POINT/file1.txt
  #Prepare machine for imaging
  sudo waagent -deprovision+user -force
EOF

#Deallocate and Generalize VM
echo "Deallocating and generalizing VM."
az vm deallocate \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2

az vm generalize \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2

#Delete VM Image if it exists.
if [[ $(az image show --resource-group $RESOURCE_GROUP --name ${IMAGE_NAME}2) ]]; then \
  echo "Deleting previous image."
  az image delete \
  --resource-group $RESOURCE_GROUP \
  --name ${IMAGE_NAME}2
fi

#Capture VM image
echo "Capturing VM Image."
az image create \
--resource-group $RESOURCE_GROUP \
--name ${IMAGE_NAME}2 \
--source ${VM_NAME}-template2

#Cleanup Template VM
echo "Deleting Template VM Resources."

OS_DISK_ID=$(az vm show --resource-group $RESOURCE_GROUP --name ${VM_NAME}-template2 --query storageProfile.osDisk.managedDisk.id -o tsv)
DATA_DISK_ID=$(az vm show --resource-group $RESOURCE_GROUP --name ${VM_NAME}-template2 --query storageProfile.dataDisks[0].managedDisk.id -o tsv)

az vm delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2 \
-y

az network nic delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2VMNic

az network nsg delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2NSG

az network public-ip delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template2PublicIP

az disk delete \
--ids $OS_DISK_ID \
-y

az disk delete \
--ids $DATA_DISK_ID \
-y