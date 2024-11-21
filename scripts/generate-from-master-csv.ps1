$dataDir = "docs/data"
$csvFilePath = "docs/data/edubasealldata.csv"
$templateFile = "docs/index.template.html"
$outputFile = "docs/index.html"
$jsonDirectory = "docs/establishment"
$urnTemplateFile = "docs/establishment.template.html"
$htmlDirectory = "docs/establishment"

# Ensure the input CSV file exists
If (-Not (Test-Path -Path $csvFilePath)) {
    Write-Host "CSV file not found: $csvFilePath"
    Exit
}

# Ensure the directories exists
If (-Not (Test-Path -Path $htmlDirectory)) {
    New-Item -ItemType Directory -Path $htmlDirectory
}
If (-Not (Test-Path -Path $jsonDirectory)) {
    New-Item -ItemType Directory -Path $jsonDirectory
}

# Initialize variables
$listDataHtmlBuilder = New-Object -TypeName System.Text.StringBuilder
$validUrns = @{}
$urnsInCsv = @{}

try {
    Write-Host "Begin reading: $csvFilePath"
    $data = Import-Csv -Path $csvFilePath
    Write-Host "End   reading: $csvFilePath"

    ## Take only the first 10 entries (for debugging / running locally)
    #$data = $data | Select-Object -First 10

    # Process each row and create JSON files
    $rowIndex = 0
    foreach ($row in $data) {
        $rowIndex++
        if ($rowIndex % 1000 -eq 0) {
            Write-Host "Processing row $rowIndex of $($data.Length)"
        }

        $urn = $row.URN
        if (-not $urn) {
            Write-Warning "Skipping row $rowIndex due to missing URN"
            continue
        }

        $urnsInCsv[$urn] = $true

        $jsonFile = Join-Path -Path $jsonDirectory -ChildPath ($urn + ".json")
        Write-Debug "Begin converting to JSON: $csvFilePath with URN $urn to $jsonFile"
        $json = $row | ConvertTo-Json -Depth 100
        Write-Debug "End   converting to JSON: $csvFilePath with URN $urn to $jsonFile"

        Write-Debug "Begin writing JSON file: $jsonFile"
        $json | Set-Content -Path $jsonFile -Force
        Write-Debug "End   writing JSON file: $jsonFile"

        $name = $row."EstablishmentName"
        if (-not $name) {
            Write-Warning "Skipping row $rowIndex due to missing EstablishmentName"
            continue
        }

        $jsonLink = "./establishment/$($urn).json"
        $htmlLink = "./establishment/$($urn).html"
        $validUrns[$urn] = $true

        # Generate the individual HTML file using the template
        $htmlTemplate = Get-Content -Path $urnTemplateFile

        foreach ($key in $row.PSObject.Properties.Name) {
            $value = $row.$key
            $placeholder = "<!-- $key Placeholder -->"
            $htmlTemplate = $htmlTemplate -replace [regex]::Escape($placeholder), $value
        }

        $htmlContent = $htmlTemplate -replace "<!-- Title Placeholder -->", "Establishment $name"
        $urnHtmlFile = Join-Path -Path $htmlDirectory -ChildPath ($urn + ".html")
        $htmlContent | Out-File -FilePath $urnHtmlFile -Encoding utf8

        # Append URN, Name, and Link to HTML list
        [void]$listDataHtmlBuilder.AppendLine("<li>URN: $urn - Name: $name - <a href='$jsonLink'>JSON File</a> - <a href='$htmlLink'>HTML File</a></li>")
    }

    # Replace the placeholder in the template with the generated HTML list
    $template = Get-Content -Path $templateFile
    $template = $template -replace "<!-- list placeholder -->", $listDataHtmlBuilder.ToString()
    Write-Host "End   generating HTML content"

    Write-Host "Saving to $outputFile"
    $template | Set-Content -Path $outputFile
    Write-Host "Saved  to $outputFile"
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
