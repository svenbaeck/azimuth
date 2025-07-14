
For testing purpose, certificates can be generated using Powershell:

```powershell
# Quick certificate generation
New-SelfSignedCertificate -Subject "CN=contosoairlines.local" `
    -DnsName "contosoairlines.local","www.contosoairlines.local" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable |
    Export-PfxCertificate -FilePath ".\sslCert_contosoairlines_1.pfx" `
    -Password (ConvertTo-SecureString -String "contosoairlines" -Force -AsPlainText)
```

Deploying the code through Powershell is easy using `deploy.ps1`.