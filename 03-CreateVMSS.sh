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

#Script Name: 03-CreateVMSS.sh
#Author: Michael Saul
#Version 0.2
#Description:
#  

#Source Config
source config.sh

#Get Resource Group ID
RESOURCE_GROUP_ID=$(az group show -n $RESOURCE_GROUP --query [id] -o tsv)

#Create VMSS from Image
echo "Creating VMSS."
az vmss create \
--resource-group $RESOURCE_GROUP \
--name $VMSS_NAME \
--image $IMAGE_NAME \
--instance-count $VMSS_SIZE \
--admin-username $ADMIN_USERNAME \
--ssh-key-value $SSH_KEY_VALUE \
--vm-sku $VM_SIZE \
--storage-sku Premium_LRS \
--vnet-name $VNET_NAME \
--subnet $SUBNET_NAME

#Add MSI to VMSS for Resource Group
echo "Enabling MSI on Resource Group."
az vmss assign-identity \
--resource-group $RESOURCE_GROUP \
--name $VMSS_NAME \
--role Contributor \
--scope $RESOURCE_GROUP_ID

#Add custom script extension to mount disk
echo "Executing VM extension."
az vmss extension set \
--vmss-name $VMSS_NAME \
--resource-group $RESOURCE_GROUP \
--name CustomScript \
--publisher Microsoft.Azure.Extensions \
--version 2.0 \
--settings ./public.json

#Update all instances to match model
echo "Updating VMSS Instances."
az vmss update-instances \
--resource-group $RESOURCE_GROUP \
--name $VMSS_NAME \
--instance-ids "*"