targetScope = 'subscription'

param namePrefix string = 'ccrek'
param location string = 'swedencentral'
param keyVaultName string = '${namePrefix}-keyvault'	
param keyVaultResourceGroupName string = '${namePrefix}-keyvault-rg'
param appGatewayName string = '${namePrefix}-appgateway'
param appGatewayResourceGroupName string = '${namePrefix}-appgateway-rg'
param virtualNetworkResourceGroupName string
param virtualNetworkName string
param appGatewaySubnetName string = 'appGatewaySubnet'
param appGatewayAddressPrefix string = '10.0.1.100/24'
param appGatewayIpAddress string = '10.0.1.100'
param keyVaultSubnetName string = 'keyVaultSubnet'
param keyVaultAddressPrefix string = '10.0.2.100/24'
param containerSubnetName string = 'ContainerSubnet'
param containerAddressPrefix string = '10.0.4.100/24'
param keyVaultPrivateDnsZoneSubscription string
param keyVaultPrivateDnsZoneResourceGroup string

param certificates array = []

param forceUpdate string = utcNow()

resource keyVaultResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: keyVaultResourceGroupName
  location: location
}

resource AppGatewayResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: appGatewayResourceGroupName
  location: location
}

module appGatewaySubnet './subnet.bicep' = {
  name: '${appGatewaySubnetName}-deployment'
  scope: resourceGroup(virtualNetworkResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: appGatewaySubnetName
    subnetAddressPrefix: appGatewayAddressPrefix
    location: location
    isAppGatewaySubnet: true
  }
}

module keyVaultSubnet './subnet.bicep' = {
  name: '${keyVaultSubnetName}-deployment'
  scope: resourceGroup(virtualNetworkResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: keyVaultSubnetName
    subnetAddressPrefix: keyVaultAddressPrefix
    location: location
  }
}

module ContainerSubnet './subnet.bicep' = {
  name: '${keyVaultSubnetName}-cnt-deployment'
  scope: resourceGroup(virtualNetworkResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: containerSubnetName
    subnetAddressPrefix: containerAddressPrefix
    location: location
    isContainerSubnet: true
    delegations: [
      {
        name: 'containerDelegation'
        serviceName: 'Microsoft.ContainerInstance/containerGroups'
      }
    ]
  }
}

module keyVault './keyvault.bicep' = {
  scope: keyVaultResourceGroup
  name: '${keyVaultName}-deployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    certificates: certificates
    keyVaultSubnetId: keyVaultSubnet.outputs.SubnetId
    keyVaultPrivateDnsZoneSubscription: keyVaultPrivateDnsZoneSubscription
    keyVaultPrivateDnsZoneResourceGroup: keyVaultPrivateDnsZoneResourceGroup
    containerSubnetId: ContainerSubnet.outputs.SubnetId
    namePrefix: namePrefix
    forceUpdate: forceUpdate
  }
}

module appGateway './appgateway.bicep' = {
  scope: AppGatewayResourceGroup
  name: '${appGatewayName}-deployment'
  params: {
    appGatewayName: appGatewayName
    appGatewaySubnetId: appGatewaySubnet.outputs.SubnetId
    appGatewayPrivateIp: appGatewayIpAddress
    location: location
    keyVaultSecretIds: keyVault.outputs.keyVaultSecretIds
    userAssignedIdentityId: keyVault.outputs.managedIdentityId
  }
}
