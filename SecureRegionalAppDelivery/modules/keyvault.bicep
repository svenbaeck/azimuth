targetScope = 'resourceGroup'

param appGatewayName string = 'appGateway'

param keyVaultName string = 'keyvault'
param location string = resourceGroup().location
param identityName string = '${appGatewayName}-mi'

param certificates array = [ ]

param subnetId string = ''

param keyVaultPrivateDnsZoneSubscription string
param keyVaultPrivateDnsZoneResourceGroup string

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
  }
}

resource cert 'Microsoft.Resources/deploymentScripts@2023-08-01' = [for certificate in certificates: {
  name: '${certificate.name}-cert-deployment'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deployIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '10.0'	
    environmentVariables: [
      {
        name: 'certificate'
        value: certificate.value
      }
      {
        name: 'certificatePassword'
        value: certificate.password
      }
      {
        name: 'keyVaultName'
        value: keyVaultName
      }
      {
        name: 'certificateName'
        value: certificate.name
      }
    ]
    scriptContent: '''
      $cert = Get-AzKeyVaultCertificate -VaultName $Env:keyVaultName -Name $Env:certificateName
      if ($cert -ne $null)
      {
        if ([string]::IsNullOrEmpty($Env:certificatePassword))
        {
          $local_thumb = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::fromBase64String($Env:certificate)).Thumbprint
        } else {
          $local_thumb = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::fromBase64String($Env:certificate), $Env:certificatePassword).Thumbprint
        }

        $DeploymentScriptOutputs = @{}

        if ($cert.Thumbprint -eq $local_thumb)
        {
          Write-Output "The certificate already exists in KeyVault"
          $length = $cert.secretId.Length
          $DeploymentScriptOutputs['secretId'] = $cert.secretId.Substring(0, $length - 1)
          return
        }
      }

      if ([string]::IsNullOrEmpty($Env:certificatePassword))
      {
        $cert = Import-AzKeyVaultCertificate -VaultName "$Env:keyVaultName" -Name "$Env:certificateName" -CertificateString "$Env:certificate"
      } else {
        $sec_password = ConvertTo-SecureString -String "$Env:certificatePassword" -AsPlainText -Force
        $cert= Import-AzKeyVaultCertificate -VaultName "$Env:keyVaultName" -Name "$Env:certificateName" -CertificateString "$Env:certificate" -Password $sec_password
      }

      $length = $cert.secretId.Length
      $DeploymentScriptOutputs['secretId'] = $cert.secretId.Substring(0, $length - 1)
      
    '''
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    certOfficerRoleAssignment
  ]
}]

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
      id: subnetId
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
        name: 'keyvault-dns'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
  parent: keyVaultPrivateEndpoint
}

output SecretUserIdentityId string = identity.properties.principalId
//output keyVaultSecretId string = cert.properties.outputs.secretId // secret.properties.secretUri
output keyVaultSecretIds array = [for (c, i) in certificates : {
    secretId: substring( cert[i].properties.outputs.secretId, 0, lastIndexOf( cert[i].properties.outputs.secretId, '/'))
    name : c.name
  }]
output managedIdentityId string = identity.id
