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

#Script Name: attach_disk_vmss.sh
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

SUBSCRIPTION_ID=$(az account list --query [0].id -o tsv)

echo "Getting REST Access Token"
ACCESS_TOKEN=$(curl -H Metadata:true -s http://localhost:50342/oauth2/token --data "resource=https://management.azure.com/" | jq -r ".access_token")

#Get my VM Name from the Metadata Service.
VM_NAME=$(curl -H Metadata:true -s "http://169.254.169.254/metadata/instance/compute/name?api-version=2017-04-02&format=text")

#Get the Instance Id and VMSS from the name.
INSTANCE_ID=${VM_NAME: -1}
VMSS_NAME=${VM_NAME%??}

#Get my Resource Group
RESOURCE_GROUP=$(az vmss list --query "[?contains(name, '$VMSS_NAME')].resourceGroup" -o tsv)

#Create a disk from the snapshot
az disk create \
--resource-group $RESOURCE_GROUP \
--name ${VM_NAME}_datadisk \
--source $SNAPSHOT_NAME

DATA_DISK_ID=$(az disk show --resource-group $RESOURCE_GROUP --name ${VM_NAME}_datadisk --query [id] -o tsv)

#Attach the disk
#MODEL=$(curl -s https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/VirtualMachineScaleSets/${VMSS_NAME}/virtualMachines/${INSTANCE_ID}?api-version=2017-12-01 -H "Authorization: Bearer ${ACCESS_TOKEN}")

DATA_DISK=$(cat << EOF
    {"lun": 0,
    "createOption": "Attach",
    "caching": "None",
    "managedDisk": {
        "storageAccountType": "Premium_LRS",
            "id": "$DATA_DISK_ID"
        }
    }
EOF
)

curl -s \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/VirtualMachineScaleSets/${VMSS_NAME}/virtualMachines/${INSTANCE_ID}?api-version=2017-12-01 \
    | jq ".properties.storageProfile.dataDisks += [${DATA_DISK}]" \
    | curl \
    -H "Content-Type: application/json" \
    -H "Authorization:Bearer ${ACCESS_TOKEN}" \
    -X PUT \
    -d @- \
    https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/VirtualMachineScaleSets/${VMSS_NAME}/virtualMachines/${INSTANCE_ID}?api-version=2017-12-01

    #Update VM from new model
    az vmss update-instances \
    --instance-ids $INSTANCE_ID \
    --name $VMSS_NAME \
    --resource-group $RESOURCE_GROUP
