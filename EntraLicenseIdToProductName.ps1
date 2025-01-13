Param(
    [String]$GUID,
    [Switch]$ShowCompleteTable
)

# Function to parse HTML if PS core, and not Win PS
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

# A CSV-file containing the lookuptable will be created in current directory
$csvPath = "$((Get-Location).Path)\LicenseSkuIdLookup.csv"

# If the CSV-file already exists, import it
if (Test-Path $csvPath) {
    $skuIdLookupTable = Import-Csv -Path $csvPath -Delimiter ';' -Encoding utf8    
}

# If not, get the HTML-table online, convert it to a PSObject and save it as CSV for next time
else {
    $webrequest = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference'

    if ($host.version.Major -gt 5) {
        $document = ParseHtml $webrequest.Content
        $table = $document.getElementsByTagName('table')[0]
    }
    else {
        $table = $webrequest.ParsedHtml.getElementsByTagName('Table')[0]
    }

    $skuIdLookupTable = @()
    $headers = ($table.Rows[0].Cells | Select-Object -ExpandProperty innerText).trim()

    foreach ($tablerow in ($table.Rows | Select-Object -Skip 1)) {
        $cells = ($tablerow.Cells | Select-Object -ExpandProperty innerText).trim()
        $obj = New-Object -TypeName PSObject
        $count = 0;
        foreach ($cell in $cells) {
            if ($count -lt $headers.count) {
                $obj | Add-Member -MemberType NoteProperty -Name $headers[$count++] -Value $cell
            }
        }
        $skuIdLookupTable += $obj
    }    
    $skuIdLookupTable | Export-Csv -Delimiter ';' -Encoding utf8 -Path $csvPath -Confirm:$false -Force

}

# Lookup GUID to product name/friendly name
if ($GUID) {
    $skuIdLookupTable | Where-Object {$_.GUID -eq $GUID} | Select-Object 'Product name', 'String ID', GUID
}

# Show the complete lookup-table in a gridview
if ($ShowCompleteTable) {
    $skuIdLookupTable | Out-GridView
}
