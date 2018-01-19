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

#Script Name: x02-Delete.sh
#Author: Michael Saul
#Version 0.3
#Description:
#  

#Source Config
source config.sh

OS_DISK_ID=$(az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME-source --query storageProfile.osDisk.managedDisk.id -o tsv)
DATA_DISK_ID=$(az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME-source --query storageProfile.dataDisks[0].managedDisk.id -o tsv)


echo "Deleting resources from step 02."

az vm delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-source \
-y

az network nic delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-sourceVMNic

az network nsg delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-sourceNSG

az network public-ip delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-sourcePublicIP

az disk delete \
--ids $OS_DISK_ID \
-y

az disk delete \
--ids $DATA_DISK_ID \
-y