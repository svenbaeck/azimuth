using './appDelivery.bicep'

param namePrefix = 'ccrek'
param location = 'swedencentral'
param keyVaultName = '${namePrefix}-keyvault'
param keyVaultResourceGroupName = '${namePrefix}-keyvault-rg'
param appGatewayName = '${namePrefix}-appgateway'
param appGatewayResourceGroupName = '${namePrefix}-appgateway-rg'
param virtualNetworkResourceGroupName = 'rg-ccrek-appgw'
param virtualNetworkName = 'vnet-ccrek-appgw'
param appGatewaySubnetName = 'appGatewaySubnet'
param appGatewayAddressPrefix = '10.0.1.0/24'
param appGatewayIpAddress = '10.0.1.100'
param keyVaultSubnetName = 'keyVaultSubnet'
param keyVaultAddressPrefix = '10.0.2.0/24'
param containerSubnetName = 'ContainerSubnet'
param containerAddressPrefix = '10.0.4.0/24'
param privateDnsZoneSubscription = '50b9932b-ea7f-477d-ac9f-5ae89de48fc5'
param privateDnsZoneResourceGroup = 'rg-priv-dns'
param appDeliverySubscriptionId = '68cc8493-012c-4ac4-9984-2b3fb6682497'
param certificates = [
      {
        name: 'certContosoAirlines1' 
        value: loadFileAsBase64('./certs/sslCert_contosoairlines_1.pfx')
        password: 'contosoairlines' // or leave blank if not needed
      }
     {
        name: 'certContosoAirlines2' 
        value: loadFileAsBase64('./certs/sslCert_contosoairlines_2.pfx')
        password: 'contosoairlines' // or leave blank if not needed
      }
    ]

