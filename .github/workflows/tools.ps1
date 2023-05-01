function Set-WorkerImageOutput {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $CommitMessage
    )
    
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module powershell-yaml -ErrorAction Stop
    $Commit = ConvertFrom-Json $CommitMessage
    ## Handle the pools and pluck them out
    $keys_index = $commit.IndexOf("keys:")
    $keys = if ($keys_index -ne -1) {
        $keys_value = $commit.Substring($keys_index + 5).Trim()
        if ($keys_value -match ",") {
            $keys_array = $keys_value.Split(",")
            foreach ($key in $keys_array) {
                $key.Trim()
            }
        }
        else {
            $keys_value.Trim()
        }
    }
    Foreach ($key in $keys) {
        $YAML = Convertfrom-Yaml (Get-Content "config/$key.yaml" -raw)
        $locations = ($YAML.azure.locations | ConvertTo-Json -Compress)
        Write-Output "LOCATIONS=$locations" >> $ENV:GITHUB_OUTPUT
        Write-Output "KEY=$Key" >> $ENV:GITHUB_OUTPUT
    }
}

function New-WorkerImage {
    [CmdletBinding()]
    param (
        [String]
        $Location,

        [String]
        $CommitMessage
    )

    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module powershell-yaml -ErrorAction Stop
    $Commit = ConvertFrom-Json $CommitMessage
    ## Handle the pools and pluck them out
    $keys_index = $commit.IndexOf("keys:")
    $keys = if ($keys_index -ne -1) {
        $keys_value = $commit.Substring($keys_index + 5).Trim()
        if ($keys_value -match ",") {
            $keys_array = $keys_value.Split(",")
            foreach ($key in $keys_array) {
                $key.Trim()
            }
        }
        else {
            $keys_value.Trim()
        }
    }

    $ENV:PKR_VAR_location = $Location
    $ENV:PKR_VAR_resource_group = $ResourceGroup

    Foreach ($key in $keys) {
        $YAML = Convertfrom-Yaml (Get-Content "config/$key.yaml" -raw)
        $ENV:PKR_VAR_image_publisher = $YAML.image["publisher"]
        $ENV:PKR_VAR_offer = $YAML.image["offer"]
        $ENV:PKR_VAR_image_sku = $YAML.image["sku"]
        $ENV:PKR_VAR_vm_size = $YAML.vm["size"]
        $ENV:PKR_VAR_base_image = $YAML.vm.tags["base_image"]
        $ENV:PKR_VAR_source_branch = $YAML.vm.tags["sourceBranch"]
        $ENV:PKR_VAR_source_repository = $YAML.vm.tags["sourceRepository"]
        $ENV:PKR_VAR_source_organization = $YAML.vm.tags["sourceOrganization"]
        $ENV:PKR_VAR_deployment_id = $YAML.vm.tags["deploymentId"]
        $ENV:PKR_VAR_bootstrap_script = $YAML.azure["bootstrapscript"]
        $ENV:PKR_VAR_client_id = $ENV:client_id
        $ENV:PKR_VAR_tenant_id = $ENV:tenant_id
        $ENV:PKR_VAR_subscription_id = $ENV:subscription_id
        $ENV:PKR_VAR_client_secret = $ENV:client_secret
        $ENV:PKR_VAR_managed_image_name = ('{0}-{1}-alpha' -f $YAML.azure["worker_pool_id"], $ENV:PKR_VAR_image_sku)
        $ENV:PKR_VAR_image_version = $ImageVersion
        if (Test-Path "windows.pkr.hcl") {
            packer build -force ./windows.pkr.hcl
        }
        else {
            Write-Error "Cannot find windows.pkr.hcl"
            Exit 1
        }
    }
}