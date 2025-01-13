# EntraLicenseIdToProductName
Designed to help easily find the product name associated with a specific GUID (Globally Unique Identifier) used in Microsoft licensing.
The script retrieves and processes a lookup table from an online source, allowing you to search for product details using a GUID. 

The complete product names and service plan identifiers for licensing in Entra ID and Office 365 is found here:
https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference

In short, the HTML-table is retrived from the above website, then parsed into a PowerShell-Object, and saved to disk as a CSV-file for next lookup.
If the CSV already exsists, it will do the lookup directly vs. the local file.

The intention is illustrate how to create the lookup-table, and then use it in other scripts, to display friendly productnames instead of GUID or string IDs. This script alone, has limited value.

### Install
```PowerShell
Install-Script -Name EntraLicenseIdToProductName
```


### 🔵 Example 1 - Lookup a single GUID/SkuID
```PowerShell
EntraLicenseIdToProductName.ps1 -GUID '06ebc4ee-1bb5-47dd-8120-11324bc54e06'
```

![image](https://github.com/user-attachments/assets/afc27251-b3d9-49cc-9dbd-6f737f8fd075)



### 🔵 Example 2 - Display the complete table
```PowerShell
EntraLicenseIdToProductName.ps1 -ShowCompleteTable
```

![image](https://github.com/user-attachments/assets/c51453b4-60e4-4983-b3ae-5178e4e07642)

