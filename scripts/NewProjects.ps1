

function Get-ProjectFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Project title')]
        [string]$Path
    )

    try{
        [System.Collections.ArrayList]$ProjectFiles = [System.Collections.ArrayList]::new()
        $AllFiles = Get-ChildItem -Path "$Path" -File -Filter "project.nfo" -Recurse -Depth 2 -ErrorAction Stop
        ForEach($project in $AllFiles){
            $Fullname = $project.FullName
            $FileName = $project.Name
            $JsonObject = Get-Content -Path $Fullname | ConvertFrom-Json
            Add-Member -InputObject $JsonObject -MemberType NoteProperty -Name "FilePath" -Value "$Fullname"
            [void]$ProjectFiles.Add($JsonObject)
        }$ProjectFiles
    }catch{}
}


function New-ProjectDataFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Project title')]
        [string]$Title,

        [Parameter(Mandatory = $true, HelpMessage = 'Project summary')]
        [string]$Summary,

        [Parameter(Mandatory = $true, HelpMessage = 'Project author')]
        [string]$Author,

        [Parameter(Mandatory = $true, HelpMessage = 'Project date')]
        [datetime]$Date,

        [Parameter(Mandatory = $true, HelpMessage = 'Project languages')]
        [string[]]$Languages,
        [Parameter(Mandatory = $true, HelpMessage = 'Project category')]
        [string]$Category,
        [Parameter(Mandatory = $true, HelpMessage = 'Project keywords')]
        [string[]]$Keywords,

        [Parameter(Mandatory = $true, HelpMessage = 'Project permalink')]
        [string]$Permalink,

        [Parameter(Mandatory = $true, HelpMessage = 'Project thumbnail')]
        [string]$Thumbnail,

        [Parameter(Mandatory = $false, HelpMessage = 'Output format')]
        [ValidateSet('json', 'text')]
        [string]$Format="json"
    )

    $obj = [PSCustomObject]@{
        Title     = $Title
        Summary   = $Summary
        Author    = $Author
        Date      = $Date
        Category  = $Category
        Languages = $Languages
        Keywords  = $Keywords
        Permalink = $Permalink
        Thumbnail = $Thumbnail
    }

    switch ($Format.ToLower()) {
        'json' {
            $obj | ConvertTo-Json -Depth 3
        }
        'text' {
            $languagesStr = ($Languages -join ', ')
            $keywordsStr = ($Keywords -join ', ')
            @"
---begin.project.nfo---
title:   $Title
summary: $Summary
author:  $Author
date:    '$($Date.ToString('yyyy-MM-dd'))'
languages: $languagesStr
keywords: $keywordsStr
category: $Category
permalink: $Permalink
thumbnail: $Thumbnail
---end.project.nfo---
"@
        }
    }
}

<#

$ProjectText = New-ProjectDataFile `
    -Title "mseek - process scanner" `
    -Summary "memory search tool for strings and regular expressions" `
    -Author "guillaume plante" `
    -Category "general" `
    -Date (Get-Date '2020-10-16') `
    -Languages @("c++", "powershell") `
    -Keywords @("memory", "scan") `
    -Permalink "https://github.com/arsscriptum/mseek" `
    -Thumbnail "https://github.com/arsscriptum/mseek/raw/refs/heads/mseek_stable/img/banner_s.png" `



#>
