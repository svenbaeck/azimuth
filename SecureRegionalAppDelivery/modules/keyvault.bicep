targetScope = 'resourceGroup'

param appGatewayName string = 'appGateway'
param namePrefix string = ''
param keyVaultName string = 'keyvault'
param location string = resourceGroup().location
param identityName string = '${appGatewayName}-mi'
param certificates array = [ ]
param keyVaultSubnetId string = ''
param keyVaultPrivateDnsZoneSubscription string
param keyVaultPrivateDnsZoneResourceGroup string
param containerSubnetId string = ''
param forceUpdate string = utcNow()

var keyVaultPrivateDnsZoneId = resourceId(
  keyVaultPrivateDnsZoneSubscription,
  keyVaultPrivateDnsZoneResourceGroup,
  'Microsoft.Network/privateDnsZones',
  'privatelink.vaultcore.azure.net'
)

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource deployIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${appGatewayName}-deploy-identity'	
  location: location
}

var certOfficerRoleDefinitionID = 'a4417e6f-fecd-4de8-b567-7b0420556985' // KeyVault Certificate Officer
var certOfficerroleAssignmentName = guid(keyVaultName, certOfficerRoleDefinitionID, resourceGroup().id)
var roleNameStorageFileDataPrivilegedContributor = '69566ab7-960f-475b-8e7c-b3118f30c6bd'
var storageAccountName = '${namePrefix}${uniqueString(resourceGroup().id, keyVaultName, location)}'

resource certOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: certOfficerroleAssignmentName
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', certOfficerRoleDefinitionID)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal' // required to avoid replicateion delay errors
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      name: 'premium'
      family: 'A'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  kind: 'StorageV2'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: !empty(containerSubnetId) ? [
        {
            id: containerSubnetId
            action: 'Allow'
        }
      ] : []
    }
  }
}

resource storageFileDataPrivilegedContributorReference 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roleNameStorageFileDataPrivilegedContributor
  scope: tenant()
}

resource storageFileDataPrivilegedContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageFileDataPrivilegedContributorReference.id, deployIdentity.id, storageAccount.id)
  scope: storageAccount
  properties: {
    principalId: deployIdentity.properties.principalId
    roleDefinitionId: storageFileDataPrivilegedContributorReference.id
    principalType: 'ServicePrincipal'
  }
}

// Add Key Vault access for deployment script identity
resource deployIdentityKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, certOfficerRoleDefinitionID, deployIdentity.id)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', certOfficerRoleDefinitionID)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cert 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'certs-deployment-${uniqueString(resourceGroup().id, string(certificates))}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deployIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: forceUpdate
    storageAccountSettings: {
      storageAccountName: storageAccount.name
    }
    containerSettings: empty(containerSubnetId) ? null : {
      subnetIds: [
        {
          id: containerSubnetId
        }
      ]
    }
    azPowerShellVersion: '10.0'
    environmentVariables: [
      {
        name: 'certs'
        value: string(certificates)
      }
      {
        name: 'keyVaultName'
        value: keyVaultName
      }
    ]
    scriptContent: loadTextContent('./deployment_script.ps1')
    retentionInterval: 'PT1H'
    timeout: 'PT15M'
  }
  dependsOn: [
    certOfficerRoleAssignment
    deployIdentityKeyVaultAccess
    storageFileDataPrivilegedContributorRoleAssignment
    keyVaultPrivateEndpoint
    keyVaultPrivateDnsZoneGroup
  ]
}

var roleDefinitionID = '4633458b-17de-408a-b874-0445c86b69e6' // KeyVault Secrets User
var roleAssignmentName= guid(keyVaultName, roleDefinitionID, resourceGroup().id)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal' // required to avoid replicateion delay errors
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${keyVaultName}-pe'
  location: location
  properties: {
    subnet: {
      id: keyVaultSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-kv-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-07-01' = {
  name: '${keyVaultPrivateEndpoint.name}-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${keyVaultPrivateEndpoint.name}-dns'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
  parent: keyVaultPrivateEndpoint
}

output SecretUserIdentityId string = identity.properties.principalId
output keyVaultSecretIds array = [for (c, i) in certificates : {
    secretId: cert.properties.outputs['secretId_${c.name}']
    name : c.name
  }]
output managedIdentityId string = identity.id
