![PowerShell](https://img.shields.io/badge/PowerShell-5+-blue)
![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Get-EntraProductsAndServicePlans)

# Get-EntraProductsAndServicePlans
PowerShell script to map Microsoft Entra license GUIDs to friendly product names and vice versa. It downloads and caches the [official Microsoft CSV listing](https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference) license product names, service plans, and identifiers.

<img width="938" height="188" alt="image" src="https://github.com/user-attachments/assets/12cb339c-7dc2-47aa-b761-ef79a18a8196" />

### Install
```PowerShell
Install-Script -Name Get-EntraProductsAndServicePlans
```

### Usage
```PowerShell
Get-EntraProductsAndServicePlans.ps1 [-GUID <regex>] [-ProductDisplayName <regex>] [-ServicePlanNames <regex>] [-ProductOnly] [-VerboseLogging] [-ForceDownload]
```

### Parameters
| Name                 | Type     | Description                                                        |
| -------------------- | -------- | ------------------------------------------------------------------ |
| `GUID`               | `regex`  | Regex to match Entra license GUIDs                                 |
| `ProductDisplayName` | `regex`  | Regex to match the product display name (case-insensitive)         |
| `ServicePlanNames`   | `regex`  | Regex to match service plan names or included friendly names       |
| `ProductOnly`        | `switch` | If set, only shows product display names, string IDs, and GUIDs    |
| `VerboseLogging`     | `switch` | Enables detailed output for debugging/logging                      |
| `ForceDownload`      | `switch` | Forces a re-download of the CSV from Microsoft                     |
| `PathLocalStore`     | `string` | Local path to store the downloaded CSV (default: script directory) |

### Examples
```PowerShell
# Lookup a specific license by GUID
Get-EntraProductsAndServicePlans.ps1 -GUID '06ebc4ee-1bb5-47dd-8120-11324bc54e06' -ProductOnly

# Open all results in a GUI grid view
Get-EntraProductsAndServicePlans.ps1 | Out-GridView

# Filter products with specific display name (exact match) and show all service plans
Get-EntraProductsAndServicePlans.ps1 -ProductDisplayName "^Microsoft 365 E5$" | Select-Object -ExpandProperty Service_Plans_Included_Friendly_Names

# Use regex to filter for education-related licenses
Get-EntraProductsAndServicePlans.ps1 -ProductDisplayName "(faculty|students)"

# Find products that include a specific service plan
Get-EntraProductsAndServicePlans.ps1 | Where-Object {$_.Service_Plans_Included_Friendly_Names -match 'Microsoft Entra ID P2'} | select Product_Display_Name

# Force download of the latest CSV and enable verbose output
Get-EntraProductsAndServicePlans.ps1 -ForceDownload -VerboseLogging
```

### Screenshots

Get-EntraProductsAndServicePlans.ps1 -GUID '06ebc4ee-1bb5-47dd-8120-11324bc54e06' -VerboseLogging | select -First 2
<img width="1306" height="448" alt="image" src="https://github.com/user-attachments/assets/da77bc37-b12a-4fb2-9c65-6cbb1347825d" />

Get-EntraProductsAndServicePlans.ps1 | Out-GridView
<img width="1407" height="631" alt="image" src="https://github.com/user-attachments/assets/79fa332b-b721-4e53-be1a-5c2e772239f6" />

