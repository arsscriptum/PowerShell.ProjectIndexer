#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Common.ps1                                                                   ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


function Get-RootPath {
    return (Resolve-Path "$PSScriptRoot\..").Path
}

function Get-ProxyScriptsPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "scripts"
}

function Get-ProxyDbPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "db"
}

function Get-ProxyDataPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "data"
}

function Get-ProxyLibPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "lib"
}

function Get-SqlPath {
    return Join-Path -Path (Get-RootPath) -ChildPath "sql"
}

function Get-DatabaseFilePath {
    $databasePath = Join-Path -Path (Get-ProxyDbPath) -ChildPath "projects.db"
    return $databasePath
}

function Get-DatabasePath {
    $databasePath = Join-Path -Path (Get-ProxyDbPath) -ChildPath "projects.db"
    return $databasePath
}


function Add-SqlLiteTypes {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $False, HelpMessage = "Force Reload")]
        [switch]$Force
    )
    $IsLoaded = $False
    $assemblyPath = Join-Path -Path (Get-ProxyLibPath) -ChildPath "System.Data.SQLite.dll"
    try {
        if ([System.Data.SQLite.SQLiteModule] -as [type]) {
            $IsLoaded = $True
        } else {
            $IsLoaded = $False
        }
    } catch {
        $IsLoaded = $False
    }

    $ShouldLoadAssembly = $False
    if ($Force) {
        Write-Verbose "[Add-SqlLiteTypes] Force Reload"
        $ShouldLoadAssembly = $True
    } elseif ($IsLoaded -eq $False) {
        Write-Verbose "[Add-SqlLiteTypes] Not Loaded. Will load."
        $ShouldLoadAssembly = $True
    } else {
        Write-Verbose "[Add-SqlLiteTypes] alrady loaded"
        $ShouldLoadAssembly = $False
    }

    if ($ShouldLoadAssembly) {
        try {
            Add-Type -Path "$assemblyPath" -ErrorAction Stop
        } catch {
            Write-Warning "Failed to load SQLite assembly $assembly : $_"
        }
    }

}


function Get-ProjectFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Project title')]
        [string[]]$Path
    )

    try{
        [System.Collections.ArrayList]$ProjectFiles = [System.Collections.ArrayList]::new()
        $AllFiles = Get-ChildItem -Path $Path -File -Filter "project.nfo" -Recurse -Depth 2 -ErrorAction Stop
        ForEach($project in $AllFiles){
            $Fullname = $project.FullName
            $FileName = $project.Name
            $JsonObject = Get-Content -Path $Fullname | ConvertFrom-Json
            Add-Member -InputObject $JsonObject -MemberType NoteProperty -Name "FilePath" -Value "$Fullname"
            [void]$ProjectFiles.Add($JsonObject)
        }$ProjectFiles
    }catch{}
}

function Import-ProjectDirList {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    try{
        $ProjectSettingsPath = "$ENV:LOCALAPPDATA\ProjectBrowser"
        $ProjectSettingsFile = Join-Path $ProjectSettingsPath "Directories.json"
        if(!(Test-Path $ProjectSettingsFile)){throw "missing Project settings"}
        $DirList = Get-Content -Path $ProjectSettingsFile | ConvertFrom-Json
        $DirList
    }catch{
        throw $_
    }
}

function Save-ProjectDirList {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Project Directories')]
        [string[]]$Directories
    )

    try{
        $ProjectSettingsPath = "$ENV:LOCALAPPDATA\ProjectBrowser"
        $ProjectSettingsFile = Join-Path $ProjectSettingsPath "Directories.json"
        if(!(Test-Path $ProjectSettingsFile)){
             New-Item -Path "$ProjectSettingsFile" -ItemType FIle -Force -ErrorAction Ignore | Out-Null
        }
        $JsonData = $Directories | ConvertTo-Json
        Set-Content -Path $ProjectSettingsFile -Value $JsonData

    }catch{}
}

