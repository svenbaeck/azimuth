targetScope = 'managementGroup'

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

param privateDnsZoneSubscription string
param privateDnsZoneResourceGroup string

param appDeliverySubscriptionId string

param certificates array = []

module linkPrivateDnsZone './modules/linkPrivateDnsZone.bicep' = {
  name: 'link-private-dns-zone-deployment'
  scope: resourceGroup(privateDnsZoneSubscription, privateDnsZoneResourceGroup)
  params: {
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
    vnetId : resourceId(appDeliverySubscriptionId, virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
  }
}

module appDelivery './modules/appGatewayEnvironment.bicep' = {
  name: 'app-delivery-deployment'
  scope: subscription(appDeliverySubscriptionId)
  params: {
    namePrefix: namePrefix
    location: location
    keyVaultName: keyVaultName
    keyVaultResourceGroupName: keyVaultResourceGroupName
    appGatewayName: appGatewayName
    appGatewayResourceGroupName: appGatewayResourceGroupName
    virtualNetworkResourceGroupName: virtualNetworkResourceGroupName
    virtualNetworkName: virtualNetworkName
    appGatewaySubnetName: appGatewaySubnetName
    appGatewayAddressPrefix: appGatewayAddressPrefix
    appGatewayIpAddress: appGatewayIpAddress
    keyVaultSubnetName: keyVaultSubnetName
    keyVaultAddressPrefix: keyVaultAddressPrefix
    keyVaultPrivateDnsZoneSubscription: privateDnsZoneSubscription
    keyVaultPrivateDnsZoneResourceGroup: privateDnsZoneResourceGroup
    certificates: certificates
  }
}
