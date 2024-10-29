$dataDir = "docs/data"
$csvFilePath = "docs/data/edubasealldata.csv"

$templateFile = "docs/index.html.template"
$outputFile = "docs/index.html"
$jsonDirectory = "docs/establishment"
$urnTemplateFile = "docs/establishment.html.template"
$htmlDirectory = "docs/establishment"



# Ensure the HTML directory exists
If (-Not (Test-Path -Path $htmlDirectory)) {
    New-Item -ItemType Directory -Path $htmlDirectory
}

try {
    Write-Host "Begin reading:  $csvFilePath"
    $data = Import-Csv -Path $csvFilePath
    Write-Host "End reading: $csvFilePath"

    # Take only the first 10 entries (for debugging / running locally)
    $data = $data | Select-Object -First 10

    # Create a hashset of all URNs in the CSV file for quick lookup
    $urnsInCsv = @{}

    # Process each row and create JSON files
    $rowIndex = 0
    foreach ($row in $data) {
        $rowIndex++
        if ($rowIndex % 1000 -eq 0) {
            Write-Host "Processing row ${rowIndex} of $($data.Length)"
        }

        $urn = $row.URN
        $urnsInCsv[$urn] = $true
        $jsonFile = Join-Path -Path $jsonDirectory -ChildPath ($urn + ".json")

        Write-Debug "Begin converting to JSON: $csvFilePath with URN $urn to $jsonFile"
        $json = $row | ConvertTo-Json -Depth 100
        Write-Debug "End converting to JSON: $csvFilePath with URN $urn to $jsonFile"

        Write-Debug "Begin writing JSON file: $jsonFile"
        Set-Content -Path $jsonFile -Value $json
        Write-Debug "End writing JSON file: $jsonFile"


        # Extract necessary fields from the JSON content
        $urn = $json.URN
        $name = $json."EstablishmentName"
        $jsonLink = "./data/establishment/$($jsonFile.Name)"
        $htmlLink = "./establishment/$($urn).html"

        # Store valid URNs
        $validUrns[$urn] = $true

        # Generate the individual HTML file using the template
        $htmlTemplate = Get-Content -Path $urnTemplateFile
        $htmlContent = $htmlTemplate -replace "<!-- Title Placeholder -->", "Establishment $name"
        $htmlContent = $htmlContent -replace "<!-- Data Placeholder -->", ($json | ConvertTo-Json -Depth 100 | Out-String)

        $urnHtmlFile = Join-Path -Path $htmlDirectory -ChildPath ($urn + ".html")
        $htmlContent | Out-File -FilePath $urnHtmlFile -Encoding utf8

        # Append URN, Name, and Link to HTML list
        $listDataHtmlString += "<li>URN: $urn - Name: $name - <a href='$jsonLink'>JSON File</a> - <a href='$htmlLink'>HTML File</a></li>`n"

    }

    $template = Get-Content -Path $templateFile
    $template = $template -replace "<!-- list placeholder -->", $listDataHtmlString
    Write-Host "End   generating HTML content"

    $htmlContent = $template
    $htmlContent | Set-Content -Path $outputFile
    Write-Host "Generated HTML file: $outputFile"

    # Remove JSON files for URNs that are no longer present in the CSV
    $existingJsonFiles = Get-ChildItem -Path $jsonDirectory -Filter *.json
    foreach ($jsonFile in $existingJsonFiles) {
        $urn = [System.IO.Path]::GetFileNameWithoutExtension($jsonFile.Name)
        if (-not $urnsInCsv.ContainsKey($urn)) {
            Write-Host "Removing outdated JSON file: $jsonFile"
            Remove-Item -Path $jsonFile.FullName
        }
    }

    # Remove HTML files that no longer have corresponding JSON files
    $existingHtmlFiles = Get-ChildItem -Path $htmlDirectory -Filter *.html
    foreach ($htmlFile in $existingHtmlFiles) {
        $urn = [System.IO.Path]::GetFileNameWithoutExtension($htmlFile.Name)
        if (-not $validUrns.ContainsKey($urn)) {
            Write-Host "Removing outdated HTML file: $htmlFile"
            Remove-Item -Path $htmlFile.FullName
        }
    }

} catch {
    Write-Host "Failed to convert: $csvFilePath"
    Write-Host $_.Exception.Message
}
