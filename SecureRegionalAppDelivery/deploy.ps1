# Set variables
$BicepFile = "appDelivery.bicep"
$ParametersFile = "appDelivery.bicepparam"
$ManagementGroupId = "f1e96d91-910e-43ff-beb7-58980fca8bc4" # Root group

# Deploy the Bicep module to the management group
New-AzManagementGroupDeployment `
    -ManagementGroupId $ManagementGroupId `
    -TemplateFile $BicepFile `
    -TemplateParameterFile $ParametersFile `
    -Location "Sweden Central"