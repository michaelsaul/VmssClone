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

#Script Name: 01-SetupEnvironment.sh
#Author: Michael Saul
#Version 0.3
#Description:
#  

#Source Config
source config.sh

#Create Resource Group
echo "Creating Resource Group."
az group create \
--name $RESOURCE_GROUP \
--location $LOCATION

#Get Resource Group ID
RESOURCE_GROUP_ID=$(az group show -n $RESOURCE_GROUP --query [id] -o tsv)

#Create source VM
echo "Creating source VM."
az vm create \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template \
--image $IMAGE \
--admin-username $ADMIN_USERNAME \
--vnet-name $VNET_NAME \
--subnet $SUBNET_NAME \
--size $VM_SIZE \
--ssh-key-value $SSH_KEY_VALUE \
--storage-sku Premium_LRS

#Get VM Public IP
VM_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name ${VM_NAME}-template --query "[publicIps]" -o tsv)

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
  #Install EPEL Repo
  wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  sudo rpm -ivh epel-release-latest-7.noarch.rpm
  #Upgrade packages
  sudo yum -y update
  #Install jq
  sudo yum -y install jq
  #Install Azure CLI
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
  sudo yum -y install azure-cli
  #Prepare machine for imaging
  sudo waagent -deprovision+user -force
EOF

#Deallocate and Generalize VM
echo "Deallocating and generalizing VM."
az vm deallocate \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template

az vm generalize \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template

#Capture VM image
echo "Capturing VM Image."
az image create \
--resource-group $RESOURCE_GROUP \
--name $IMAGE_NAME \
--source ${VM_NAME}-template

#Cleanup Template VM
echo "Deleting Template VM Resources."

OS_DISK_ID=$(az vm show --resource-group $RESOURCE_GROUP --name ${VM_NAME}-template --query storageProfile.osDisk.managedDisk.id -o tsv)

az vm delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-template \
-y

az network nic delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-templateVMNic

az network nsg delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-templateNSG

az network public-ip delete \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}-templatePublicIP

az disk delete \
--ids $OS_DISK_ID \
-y