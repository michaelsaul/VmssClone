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

#Script Name: create_snapshots.sh
#Author: Michael Saul
#Version 0.2
#Description:
#  

#Setup variables
MOUNT_POINT="/data"
SNAPSHOT_NAME="misaul-vmss-snapshot"

#Login to az cli using MSI
echo "Logging in to az cli."
az login --msi

#Get my VM Name from the Metadata Service
VM_NAME=$(curl -H Metadata:true -s "http://169.254.169.254/metadata/instance/compute/name?api-version=2017-04-02&format=text")

#Get my VM Id
VM_ID=$(az vm list --query "[?contains(name,'${VM_NAME}')].id" -o tsv)
RG_NAME=$(az vm show --ids $VM_ID --query "resourceGroup" -o tsv)

#Get My Data Disk ID
DATA_DISK_ID=$(az vm show --id $VM_ID --query "storageProfile.dataDisks[0].managedDisk.id" -o tsv)
 
#Delete existing snapshot
az snapshot delete \
--name $SNAPSHOT_NAME \
--resource-group $RG_NAME \

#Create a Snapshot
echo "Creating snapshot."
sudo xfs_freeze -f $MOUNT_POINT

az snapshot create \
--name $SNAPSHOT_NAME \
--resource-group $RG_NAME \
--sku Premium_LRS \
--source $DATA_DISK_ID

sudo xfs_freeze -u $MOUNT_POINT