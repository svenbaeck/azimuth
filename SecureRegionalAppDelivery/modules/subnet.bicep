param virtualNetworkName string
param subnetName string
param subnetAddressPrefix string = ''
param delegations array = []
param location string
param isAppGatewaySubnet bool = false
param isContainerSubnet bool = false

var containerInstanceRules = []

var appGatewayRules = [
      {
        name: 'AllowAppGatewayInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAppGatewayHealthProbe'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65503-65534'
          sourceAddressPrefix: 'AzureCloud'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: virtualNetworkName
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: '${subnetName}-nsg'
  location: location
  properties: {
    securityRules: isAppGatewaySubnet ? appGatewayRules : []
  }
}

resource Subnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: [for d in delegations: {
      name: d.name
      properties: {
        serviceName: d.serviceName
      }
    }]
    networkSecurityGroup: {
      id: nsg.id
    }
    serviceEndpoints: isContainerSubnet ? [
        {
          service: 'Microsoft.Storage'
        }
        {
          service: 'Microsoft.ContainerRegistry'
        }
      ] : []
  }
}

output SubnetId string = Subnet.id
