# Config

This directory contains the configuration file used within packer. Additionally, it stores the respective machine image software bill of materials.

## Software Bill of Materials

The software bill of materials are dyanmically generated markdown files stored within this repository, such as [windows 11 24h2](win11-64-24h2-alpha.md)

## YAML Definition

`image`: This contains information about the cloud image itself, along with some optional parameters for supporting shared image gallery.

```
image:
  publisher: MicrosoftWindowsDesktop
  offer: Windows-11
  sku: win11-22h2-avd
  version: latest
  gallery_name: "ronin_t_windows11_64_2009_prod"
  image_name: "win11-64-2009"
  image_version: 1.0.0
```

`azure`: This contains information specific to azure required by packer

```
azure:
  managed_image_resource_group_name: rg-packer-through-cib
  managed_image_storage_account_type: Standard_LRS
  build_location: eastus
  locations:
    - canadacentral
    - centralindia
    - centralus
    - eastus
    - eastus2
    - northcentralus
    - northeurope
    - southindia
    - westus
    - westus2
    - westus3
```

`vm`: This contains some key value pairs used within packer and some packer powershell provisioners

```
vm:
  puppet_version: 8.5.1
  size: Standard_F8s_v2
  tags:
    base_image: win11642009azure
    worker_pool_id: win11-64-2009
    sourceOrganization: mozilla-platform-ops
    sourceRepository: ronin_puppet
    sourceBranch: windows
    deploymentId: "db0c108"
    managed_by: packer
```

`tests`: This is an ordered list of pester tests that will be run on the image at the end of the packer build process

```
tests:
  - microsoft_tools_tester.tests.ps1
  - disable_services.tests.ps1
  - error_reporting.tests.ps1
  - suppress_dialog_boxes.tests.ps1
  - files_system_management.tests.ps1
  - firewall.tests.ps1
  - network.tests.ps1
  - ntp.tests.ps1
  - power_management.tests.ps1
  - scheduled_tasks.tests.ps1
  - azure_vm_agent.tests.ps1
  - virtual_drivers.tests.ps1
  - logging.tests.ps1
  - common_tools.tests.ps1
  - git.tests.ps1
  - mozilla_build_tester.tests.ps1
  - mozilla_maintenance_service.tests.ps1
  - windows_worker_runner.tests.ps1
  - gpu_drivers_latest.tests.ps1
```