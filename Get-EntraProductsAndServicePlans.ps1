<#PSScriptInfo

    .VERSION 1.1.1
    .GUID 66d8b653-3887-4839-941b-37d6f4f459ca
    .AUTHOR Erlend Westervik
    .COMPANYNAME
    .COPYRIGHT
    .TAGS Entra, Azure, EntraID, Entra ID, Licence, Licences, Product, ID, GUID, Service, Plan, O365, Office 365, Service plan, Licensing, CSV, Identifiers, Product names, Microsoft Entra, Microsoft
    .LICENSEURI
    .PROJECTURI https://github.com/erlwes/EntraLicenseIdToProductName
    .ICONURI
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES
        Version: 1.0.2 - Original published version (EntraLicenseIDToProductName)
        Version: 1.1.0 - Re-write script to download CSV-file from same page, now that this has become avaliable, using new property names from CSV, rather than from HTLM-table (no spaces - yay!)
        Version: 1.1.1 - Extend on logic to only check for new versions and download if nessasary + more parameters for searching directly, rather than using filters in gridview. This uses regexp with ignore case + hacked support for negate match by starting string with "!"
        
#>

<# 

.DESCRIPTION 
    Get product names from GUID or visa-versa. Search all products, service plans and lists Microsoft online service products and provide their various ID values.

.PARAMETER GUID
    Specifies the guid of the licence you want to look up.

.EXAMPLE
    .\Get-EntraProductsAndServicePlans.ps1 -GUID '06ebc4ee-1bb5-47dd-8120-11324bc54e06' -ProductOnly

.EXAMPLE
    .\Get-EntraProductsAndServicePlans.ps1 | Out-GridView

.EXAMPLE
    .\Get-EntraProductsAndServicePlans.ps1 -ProductDisplayName "^Microsoft 365 E5$" | Select-Object -ExpandProperty Service_Plans_Included_Friendly_Names

.EXAMPLE
    .\Get-EntraProductsAndServicePlans.ps1 -ProductDisplayName "(faculty|students)"

.EXAMPLE
    .\Get-EntraProductsAndServicePlans.ps1 | Where-Object {$_.Service_Plans_Included_Friendly_Names -match 'Microsoft Entra ID P2'} | select Product_Display_Name

.EXAMPLE
    .\Get-EntraProductsAndServicePlans.ps1 -ForceDownload -VerboseLogging   

#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
Param(
    [Parameter(ParameterSetName='1')]
    [regex]$GUID,
    
    [Parameter(ParameterSetName='2')]
    [regex]$ProductDisplayName,

    [Parameter(ParameterSetName='3')]
    [regex]$ServicePlanNames,

    [Parameter(ParameterSetName='4')]
    [switch]$ForceDownload,

    [Parameter(ParameterSetName='1')][Parameter(ParameterSetName='2')][Parameter(ParameterSetName='3')][Parameter(ParameterSetName='4')][Parameter(ParameterSetName='Default')]
    [switch]$VerboseLogging,

    [Parameter(ParameterSetName='1')][Parameter(ParameterSetName='2')][Parameter(ParameterSetName='3')][Parameter(ParameterSetName='Default')]
    [switch]$ProductOnly,    

    [Parameter(ParameterSetName='1')][Parameter(ParameterSetName='2')][Parameter(ParameterSetName='3')][Parameter(ParameterSetName='Default')]
    [string]$PathLocalStore = "$PSScriptRoot\Product names and service plan identifiers for licensing.csv",

    [Parameter(ParameterSetName='Default')]
    [switch]$Dummy = $false
)

# Function to parse HTML in PS-core on Windows
function ParseHtml($string) {
    $unicode = [System.Text.Encoding]::Unicode.GetBytes($string)
    $html = New-Object -Com 'HTMLFile'
    if ($html.PSObject.Methods.Name -Contains 'IHTMLDocument2_Write') {
        $html.IHTMLDocument2_Write($unicode)
    } 
    else {
        $html.write($Unicode)
    }
    $html.Close()
    $html
}

# Function for console-logging
 Function Write-Console {
    param(
        [ValidateSet(0, 1, 2, 3, 4)]
        [int]$Level,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $Message = $Message.Replace("`r",'').Replace("`n",' ')
    switch ($Level) {
        0 { $Status = 'Info'        ;$FGColor = 'White'   }
        1 { $Status = 'Success'     ;$FGColor = 'Green'   }
        2 { $Status = 'Warning'     ;$FGColor = 'Yellow'  }
        3 { $Status = 'Error'       ;$FGColor = 'Red'     }
        4 { $Status = 'Highlight'   ;$FGColor = 'Gray'    }        
        Default { $Status = ''      ;$FGColor = 'Black'   }
    }
    if ($VerboseLogging) {
        Write-Host "$((Get-Date).ToString()) " -ForegroundColor 'DarkGray' -NoNewline
        Write-Host "$Status" -ForegroundColor $FGColor -NoNewline

        if ($level -eq 4) {
            Write-Host ("`t " + $Message) -ForegroundColor 'Cyan'
        }
        else {
            Write-Host ("`t " + $Message) -ForegroundColor 'White'
        }
    }
    if ($Level -eq 3) {
        $LogErrors += $Message
    }
}

Write-Console -Level 0 "Start"
Write-Console -Level 0 "CSV: Location '$PathLocalStore' is used"

# If -ForceDownload is set, set ReDownload to true also
if ($ForceDownload) {
    $ReDownload = $true
}

# If CSV-file already exist, inspect it
if (Test-Path $PathLocalStore) {
    Write-Console -Level 0 "CSV: File exist (Test-Path)"

    # If download is forced - delete the old file
    if ($ReDownload) {
        Write-Console -Level 0 "CSV: -ForceDownload parameter is used - will download CSV"
        try {
            Remove-Item $PathLocalStore -Confirm:$false -Force
            Write-Console -Level 1 "CSV: File deleted (Remove-Item)"
        }
        catch {
            Write-Console -Level 3 "CSV: Failed to delete file (Remove-Item). Error: $($_.Exception.Message)"
        }
    }

    # Else, compare todays date vs. date on csv-file to see if its more than 1d old
    else {                    
        [datetime]$LocalDataTimestamp = (Get-Item $PathLocalStore).LastWriteTime
        Write-Console -Level 0 "CSV: Local file dated '$LocalDataTimestamp'"
        
        $DaysSinceDownload = ((Get-Date) - (Get-Date $LocalDataTimestamp)).Totaldays
        if ($DaysSinceDownload -lt 1) {
            $LocalCopyCouldBeOutDated = $false
            Write-Console -Level 0 "CSV: Local file is less than 1 day old ($DaysSinceDownload). No need to check for newer versions online"
        }
        else {
            $LocalCopyCouldBeOutDated = $true
            Write-Console -Level 0 "CSV: Local file is more than 1 day old ($DaysSinceDownload). Will check for newer versions online"
        }
    }
}

# Else, we need to download it
else {
    Write-Console -Level 0 "CSV: File not found ($PathLocalStore)"
    $ReDownload = $true
}

#If local copy more than 1 day old, or if the -ReDownload parameter is set (from -ForceDownload or otherwise), load licensing service plan reference from learn.microsoft.com
if ($LocalCopyCouldBeOutDated -or $ReDownload) {
    
    # Do the webrequest
    try {
        $WR = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference' -ErrorAction Stop
        Write-Console -Level 1 "Invoke-WebRequest: 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference' (StatusCode: $($WR.StatusCode))"
    }
    catch {
        Write-Console -Level 3 "Invoke-WebRequest: Failed. Error: $($_.Exception.Message)"
    }

    #Parse the web response using diffent methods depending on PowerShell version
    if ($host.version.Major -gt 5) {
        Write-Console -Level 0 -Message "Parse HTML - PowerShell Core detected ($($host.version.Major).$($host.version.Minor)). Parsing HTML using 'ParseHTLM function'"
        $document = ParseHtml $WR.Content
        $DownloadURL = $document.getElementsByTagName('a') | Select-Object -ExpandProperty href | Where-Object {$_-Match "\/download\.microsoft\.com\/download" -and $_ -match 'licensing.csv'}
        $OnlineDataTimestamp = (($document.getElementsByTagName('p') | Select-Object -ExpandProperty innerText | Where-Object {$_ -match "This information was last updated on"}) -split "`n")[0] -replace "This information was last updated on " -replace "\."
    }
    else {
        Write-Console -Level 0 -Message "Parse HTML - Windows PowerShell detected ($($host.version.Major).$($host.version.Minor)). Using built in 'parsedHtml'"        
        $DownloadURL = $WR.ParsedHtml.getElementsByTagName('a') | Select-Object -ExpandProperty href | Where-Object {$_-Match "\/download\.microsoft\.com\/download" -and $_ -match 'licensing.csv'}
        $OnlineDataTimestamp = (($WR.ParsedHtml.getElementsByTagName('p') | Select-Object -ExpandProperty innerText | Where-Object {$_ -match "This information was last updated on"}) -split "`n")[0] -replace "This information was last updated on " -replace "\."
    }

    # If re-download parameter is not used, compare local version vs. online to see if the local copy still needs updating
    if (!$ReDownload) {
        $DaysSinceLastUpdate = ($LocalDataTimestamp - (Get-Date $OnlineDataTimestamp)).Totaldays #Negative values means that the online version is newer.
        if ($DaysSinceLastUpdate -le 0) {
            $LocalCopyIsOutDated = $true
            Write-Console -Level 2 -Message "Compare versions - Online version is newer than local copy of CSV. Will re-download."
        }
        else {
            $LocalCopyIsOutDated = $false
            Write-Console -Level 0 -Message "Compare versions - Local version not older than online copy of CSV. Will use local copy."        
            (Get-Item $PathLocalStore).LastWriteTime = Get-Date
            Write-Console -Level 0 -Message "Get-Item - Updated 'LastWriteTime' on '$PathLocalStore' to todays date ($(Get-Date)), so that next intra-day runs can skip online checks."
        }
    }

    # If re-download parameter is used, or 
    if ($ReDownload -or $LocalCopyIsOutDated) {
        try {
            Invoke-WebRequest -Uri $DownloadURL -OutFile "C:\Script\Product names and service plan identifiers for licensing.csv" -ErrorAction Stop
            Write-Console -Level 1 "Invoke-WebRequest: Downloaded ($PathLocalStore)"
        }
        catch {
            Write-Console -Level 3 "Invoke-WebRequest: Failed to download ($PathLocalStore). Error: $($_.Exception.Message)"
        }
    }
}

# Import CSV (same location regardless if it was must redownloaded or cache was used, so import it)
if (!$ForceDownload) {
    try {
        $Lookup = Import-Csv '.\Product names and service plan identifiers for licensing.csv' -Delimiter ',' -Encoding UTF8 -ErrorAction Stop
        Write-Console -Level 1 'CSV: Imported (Import-Csv)'
    }
    catch {
        Write-Console -Level 3 "CSV: Failed to import (Import-Csv). Error: $($_.Exception.Message)"
    }
}

# Download forced? Dont display results
if ($ForceDownload) {
    Write-Console -Level 0 "End"
    Break    
}

# Lookup on GUID
elseif ($GUID) {
    $GUID = "(?i)$GUID"
    Write-Console -Level 0 "Lookup: Finding results with 'GUID' matching regexp '$GUID'"
    $Result = $Lookup | Where-Object {$_.GUID -match $GUID}
}

# Lookup on product name
elseif ($ProductDisplayName) {
    $ProductDisplayName = "(?i)$ProductDisplayName"
    if ($ProductDisplayName -match "!") {
        $ProductDisplayName = $ProductDisplayName -replace "!"        
        Write-Console -Level 0 "Lookup: Finding results with 'Product_Display_Name' not matching regexp '$ProductDisplayName'" 
        $Result = $Lookup | Where-Object {$_.Product_Display_Name -notmatch $ProductDisplayName}
    }
    else {
        Write-Console -Level 0 "Lookup: Finding results with 'Product_Display_Name' matching regexp '$ProductDisplayName'"
        $Result = $Lookup | Where-Object {$_.Product_Display_Name -match $ProductDisplayName}
    }    
}

# Lookup on product name
elseif ($ServicePlanNames) {
    $ServicePlanNames = "(?i)$ServicePlanNames"
    if ($ServicePlanNames -match "!") {
        $ServicePlanNames = $ServicePlanNames -replace "!"        
        Write-Console -Level 0 "Lookup: Finding results with 'Service_Plan_Name' -or 'Service_Plans_Included_Friendly_Names' not matching regexp '$ServicePlanNames'" 
        $Result = $Lookup | Where-Object {$_.Service_Plan_Name -notmatch $ServicePlanNames -or $_.Service_Plans_Included_Friendly_Names -match $ServicePlanNames}
    }
    else {
        Write-Console -Level 0 "Lookup: Finding results with 'Service_Plan_Name' -or 'Service_Plans_Included_Friendly_Names' matching regexp '$ServicePlanNames'"
        $Result = $Lookup | Where-Object {$_.Service_Plan_Name -match $ServicePlanNames -or $_.Service_Plans_Included_Friendly_Names -match $ServicePlanNames}
    }    
}

# If no "search"-parameters are provided, return everything
elseif (!$GUID -and !$ProductDisplayName -and !$ServicePlanNames) {
    $Result = $Lookup
}

# If -ProductOnly is specified, dont return service plan properties
if ($ProductOnly) {
    $Result = $Result | Select-Object Product_Display_Name, String_Id, GUID -Unique
}
Write-Console -Level 0 "End"

# Return the results
Return $Result
