try {
    Write-Output "Starting certificate deployment script"
    Write-Output "KeyVault Name: $Env:keyVaultName"
    
    # Test connectivity
    try {
        Get-AzContext
        Write-Output "Azure context established successfully"
    } catch {
        Write-Error "Failed to get Azure context: $_"
        throw
    }

    $certs = $Env:certs | ConvertFrom-Json
    Write-Output "Processing $($certs.Count) certificates"

    $DeploymentScriptOutputs = @{}

    foreach ($c in $certs)
    {
        $certificate = $c.value
        $certificateName = $c.name
        $certificatePassword = $c.password
        
        Write-Output "Processing certificate: $certificateName"
        
        try {
            $cert = Get-AzKeyVaultCertificate -VaultName $Env:keyVaultName -Name $certificateName -ErrorAction SilentlyContinue
        } catch {
            Write-Output "Certificate $certificateName not found in KeyVault, will import"
            $cert = $null
        }

        if ($null -ne $cert)
        {
            Write-Output "Certificate $certificateName already exists, checking thumbprint"
            if ([string]::IsNullOrEmpty($certificatePassword))
            {
                $local_thumb = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::fromBase64String($certificate)).Thumbprint
            } else {
                $local_thumb = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::fromBase64String($certificate), $certificatePassword).Thumbprint
            }

            if ($cert.Thumbprint -eq $local_thumb)
            {
                Write-Output "Certificate $certificateName already exists with matching thumbprint"
                $DeploymentScriptOutputs["secretId_${certificateName}"] = $cert.secretId.Substring(0, $cert.secretId.LastIndexOf('/'))
                continue
            } else {
                Write-Output "Certificate $certificateName exists but thumbprint differs, will update"
            }
        }

        Write-Output "Importing certificate: $certificateName"
        try {
            if ([string]::IsNullOrEmpty($certificatePassword))
            {
                $cert = Import-AzKeyVaultCertificate -VaultName "$Env:keyVaultName" -Name "$certificateName" -CertificateString "$certificate"
            } else {
                $sec_password = ConvertTo-SecureString -String "$certificatePassword" -AsPlainText -Force
                $cert = Import-AzKeyVaultCertificate -VaultName "$Env:keyVaultName" -Name "$certificateName" -CertificateString "$certificate" -Password $sec_password
            }
            
            Write-Output "Successfully imported certificate: $certificateName"
            $DeploymentScriptOutputs["secretId_${certificateName}"] = $cert.secretId.Substring(0, $cert.secretId.LastIndexOf('/'))
            
        } catch {
            Write-Error "Failed to import certificate ${certificateName}: $_"
            throw
        }
    }
    
    Write-Output "Certificate deployment completed successfully"
    Write-Output "Outputs: $($DeploymentScriptOutputs | ConvertTo-Json)"
    
} catch {
    Write-Error "Certificate deployment failed: $_"
    Write-Error $_.ScriptStackTrace
    throw
}   