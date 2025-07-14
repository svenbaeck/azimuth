targetScope = 'resourceGroup'

/*
IMPORTANT: A read-only lock on an Application Gateway prevents you from getting the backend health of the application gateway. That operation uses a POST method, which a read-only lock blocks.
*/

param location string
param appGatewayName string
param appGatewaySubnetId string
param keyVaultSecretIds array
param appGatewayPrivateIp string
param userAssignedIdentityId string

resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${appGatewayName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: ['1', '2', '3'	]
  properties: { 
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: appGatewayName
    }
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-07-01' = {
  name: '${appGatewayName}-waf-policy'
  location: location
  properties: {
    policySettings: {
      state: 'enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.0'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2024-07-01' = {
  name: appGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  zones: ['1', '2', '3'	]
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 2
    }
    sslCertificates: [ for secret in keyVaultSecretIds : { 
        name: secret.name
        properties: {
          keyVaultSecretId: secret.secretId
        }
      }]
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: 'publicFrontend'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIp.id
          }
        }
      }
      {
        name: 'privateFrontend'
        properties: {
          privateIPAddress: appGatewayPrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'bing-backendpool'
        properties: {
          backendAddresses: [
            {
              fqdn: 'www.bing.com'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'bing-backendHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          affinityCookieName: 'ApplicationGatewayAffinity'
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'bing-httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'publicFrontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
          }
          protocol: 'Https'
          hostNames: []
          requireServerNameIndication: false
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, keyVaultSecretIds[0].name)
            }
        }
      }
    ]
    requestRoutingRules: [

      {
        name: 'bing-routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 1
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'bing-httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'bing-backendpool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'bing-backendHttpSettings')
          }
        }
      }
    ]
  }
}
