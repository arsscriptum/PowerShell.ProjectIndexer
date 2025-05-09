function Write-DebugLog {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [Alias('f')]
        [ConsoleColor]$ForegroundColor = "White",

        [Parameter(Mandatory = $false)]
        [Alias('b')]
        [ConsoleColor]$BackgroundColor,

        [Parameter(Mandatory = $false)]
        [Alias('n')]
        [switch]$NoNewLine
    )

    begin {
        # Read the DebugLog environment variable
        $debugLogEnabled = $ENV:DebugLog -ne $false
    }

    process {
        if ($debugLogEnabled) {
            # Build Write-DebugLog command dynamically
            $params = @{ "Object" = $Message; "ForegroundColor" = $ForegroundColor }
            if ($PSBoundParameters.ContainsKey("BackgroundColor")) {
                $params["BackgroundColor"] = $BackgroundColor
            }
            if ($NoNewLine) {
                $params["NoNewLine"] = $true
            }

            Write-Host @params
        }
    }
}

function Write-DebugLogToFile {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [Alias('f')]
        [ConsoleColor]$ForegroundColor = "White",

        [Parameter(Mandatory = $false)]
        [Alias('b')]
        [ConsoleColor]$BackgroundColor,

        [Parameter(Mandatory = $false)]
        [Alias('n')]
        [switch]$NoNewLine
    )

    begin {
        # Determine log file path
        $logFile = "d:\Tmp\Logs\TestOpenPortChecks.log"
        if(!([string]::IsNullOrEmpty($ENV:DebugLogFilePath))){
            $logFile = "$ENV:DebugLogFilePath"
        }
        
        if(!(Test-Path -Path "$logFile" -PathType Leaf)){
            New-Item -Path "$logFile" -ItemType File -Force -ErrorAction Ignore | Out-Null
            [DateTime]$StartTime = [DateTime]::Now
            $StartimStr = $StartTime.GetDateTimeFormats()[23]
            $StartTimeStrLen = $StartimStr.Length
            $sep = [string]::new('=',$StartTimeStrLen)
            $LogHeader = @"
`n`n===================================================================
  ================== TEST STARTED AT $StartimStr =================
===================================================================
`n`n
"@
            Set-Content -Path $logFile -Value $LogHeader -Force
        }
        $debugLogToFileEnabled = $ENV:DebugLogToFile -ne $false
        $debugLogConsoleEnabled = $ENV:DebugLogToConsole -ne $false
    }

    process {
        if ($debugLogToFileEnabled) {
            # Format log message with timestamp
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] $Message"

            # Handle NoNewLine flag
            Add-Content -Path $logFile -Value $logEntry
        }
        if ($debugLogConsoleEnabled) {
            # Build Write-DebugLog command dynamically
            $params = @{ "Object" = $Message; "ForegroundColor" = $ForegroundColor }
            if ($PSBoundParameters.ContainsKey("BackgroundColor")) {
                $params["BackgroundColor"] = $BackgroundColor
            }
            if ($NoNewLine) {
                $params["NoNewLine"] = $true
            }

            Write-Host @params
        }
    }
}


function Write-DebugDbCommand {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Statement,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Data.Common.DbCommand]$Command,
        [Parameter(Position = 2, Mandatory = $false)]
        [string]$TableName
    )

    begin {
        # Read the DebugLog environment variable
        $debugLogEnabled = $ENV:DebugLog -ne $false
        $tname = 'table'
        if ($TableName) {
            $tname = $TableName
        }

    }

    process {
        if ($debugLogEnabled) {
            $lt1 = ''
            $lt2 = ''

            $insertCommand.Parameters | % {
                $n = $_.ParameterName.TrimStart('@')
                $v = $_.Value
                $lt1 += "$n "
                $lt2 += "$v "
            }
            $lt1 = $lt1.TrimEnd(', ')
            $lt2 = $lt2.TrimEnd(', ')
            Write-DebugLog "`n$Statement $TableName ($lt1) VALUES ($lt2)`n" -f DarkMagenta

        }
    }
}


function Write-SqlScriptStats {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateScript({ Test-Path -Path "$_" -PathType Leaf })]
        [string]$Path
    )

    try {
        [string[]]$Statements = @(
            "CREATE TABLE", "INSERT INTO", "DROP TABLE", "CREATE INDEX",
            "ALTER TABLE", "CREATE VIEW", "DROP VIEW", "CREATE TRIGGER", "DROP TRIGGER",
            "CREATE FUNCTION", "DROP FUNCTION", "CREATE PROCEDURE", "DROP PROCEDURE",
            "UPDATE", "DELETE FROM", "SELECT",
            "ANALYZE", "VACUUM", "REINDEX",
            "BEGIN TRANSACTION", "COMMIT", "ROLLBACK"
        )
        $l = $Path.Length + 19
        $sep = [string]::new('=', $l)

        Write-DebugLog "$sep" -f DarkGray
        Write-DebugLog " Sql Script Stats $Path" -f White
        Write-DebugLog "$sep" -f DarkGray
        $File = Get-Item $Path
        $FileSize = $File.Length
        $log = "{0} bytes`tFile Size" -f $FileSize

        Write-DebugLog "$log" -f Cyan

        foreach ($st in $Statements) {
            $matchArray = Select-String -Path $Path -Pattern "$st"
            $matchCount = $matchArray.Count
            if ($matchCount -gt 0) {
                $log = "{0}`t`t{1}" -f $matchCount, "`"$st`""
                Write-DebugLog "$log" -f DarkCyan
            }
        }
        Write-DebugLog "$sep" -f DarkGray
    }
    catch {
        Write-Error "An error occurred in Write-SqlScriptStats: $_"
        throw "Error in Write-SqlScriptStats function."
    }
}

function Invoke-ExecuteSqlScript {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateScript({ Test-Path -Path "$_" -PathType Leaf })]
        [string]$Path
    )

    try {
        # Load the SQLite assembly using Add-SqlLiteTypes function
        Add-SqlLiteTypes
        [int]$AffectedRows = 0


        # Create and open the SQLite connection

        $databasePath = Get-DatabaseFilePath
        $connectionString = "Data Source=$databasePath;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
        $connection.Open()

        try {
            $Size = (Get-Item -Path "$Path").Length
            Write-SqlScriptStats $Path
            Write-DebugLog "Invoke-ExecuteSqlScript `"$Path`"" -f Blue
            # SQL command to create the schema_version table if it doesn't exist
            $sqlScriptContent = Get-Content -Path "$Path" -Raw
            # Execute the SQL command to create the table
            $command = $connection.CreateCommand()
            $command.CommandText = $sqlScriptContent
            $AffectedRows = $command.ExecuteNonQuery()

        }

        catch {
            Write-Error "An error occurred while adding the version table: $_"
            throw "Error executing SQL commands. Please verify the database connection and SQL syntax."
        }
        finally {
            # Close the connection
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
            $connection.Dispose()
        }
        return $AffectedRows
    }
    catch {
        Show-ExceptionDetails ($_) -ShowStack
    }

}


function Add-ProjectsDbTables {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    try {
        $CommonScript = "$PSScriptRoot\Common.ps1"
        . "$CommonScript"
        # Load the SQLite assembly using Add-SqlLiteTypes function
        Add-SqlLiteTypes

        # Create and open the SQLite connection

        $CreateTablesSqlPath = Join-Path -Path (Get-SqlPath) -ChildPath "CreateTables.sql"
        $AddLanguagesSqlPath = Join-Path -Path (Get-SqlPath) -ChildPath "AddLanguages.sql"
        $AddCategoriesSqlPath = Join-Path -Path (Get-SqlPath) -ChildPath "AddCategories.sql"


        $Scripts = @($CreateTablesSqlPath, $AddLanguagesSqlPath, $AddCategoriesSqlPath)


        try {
            foreach ($s in $Scripts) {
                $Rows = Invoke-ExecuteSqlScript $s
                Write-DebugLog "Running $s " -f Blue -NoNewline
                Write-DebugLog "changed $Rows rows" -f DarkYellow
            }
        }
        catch {
            Write-Error "An error occurred while adding the version table: $_"
            throw "Error executing SQL commands. Please verify the database connection and SQL syntax."
        }
        finally {
            # Close the connection
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
            if ($connection) {
                $connection.Dispose()
            }

        }
    }
    catch {
        Show-ExceptionDetails ($_) -ShowStack
    }
}


function Get-LanguageListFromDatabase {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$WithOpenPort
    )

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    $LanguageList = New-Object System.Collections.ArrayList

    try {
        # Base query
        $query = "select LanguageId,Name,DisplayName,Description FROM Language;"



        $command = $connection.CreateCommand()
        $command.CommandText = $query

        $reader = $command.ExecuteReader()

        while ($reader.Read()) {
            $proxy = [pscustomobject]@{
                LanguageId = $reader["LanguageId"]
                Name = $reader["Name"]
                DisplayName = $reader["DisplayName"]
                Description = $reader["Description"]
            }
            [void]$LanguageList.Add($proxy)
        }

        $reader.Close()
        return $LanguageList
    }
    catch {
        Write-Error "Error retrieving proxy list: $_"
        return $null
    }
    finally {
        $connection.Close()
    }
}


function Get-CategoryListFromDatabase {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$WithOpenPort
    )

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    $CategoryList = New-Object System.Collections.ArrayList

    try {
        # Base query
        $query = "select CategoryId,Name,Description FROM Category;"



        $command = $connection.CreateCommand()
        $command.CommandText = $query

        $reader = $command.ExecuteReader()

        while ($reader.Read()) {
            $proxy = [pscustomobject]@{
                CategoryId = $reader["CategoryId"]
                Name = $reader["Name"]
                Description = $reader["Description"]
            }
            [void]$CategoryList.Add($proxy)
        }

        $reader.Close()
        return $CategoryList
    }
    catch {
        Write-Error "Error retrieving proxy list: $_"
        return $null
    }
    finally {
        $connection.Close()
    }
}

function Get-ProjectListFromDatabase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()
$CommonScript = "$PSScriptRoot\Common.ps1"
        . "$CommonScript"
        
    $dbPath = Get-DatabasePath  # Use your helper to get the DB path

    $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $connection.Open()

    $projects = @()

    try {
        # 1️⃣ Get all projects
        $projectCmd = $connection.CreateCommand()
        $projectCmd.CommandText = "SELECT * FROM Project ORDER BY Title ASC;"
        $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($projectCmd)
        $dataSet = New-Object System.Data.DataSet
        [void]$adapter.Fill($dataSet)

        foreach ($row in $dataSet.Tables[0].Rows) {
            $projectId = $row.ProjectId

            # 2️⃣ Get associated languages
            $langCmd = $connection.CreateCommand()
            $langCmd.CommandText = @"
SELECT L.Name
FROM ProjectLanguage PL
INNER JOIN Language L ON PL.LanguageId = L.LanguageId
WHERE PL.ProjectId = @ProjectId;
"@
            $langCmd.Parameters.AddWithValue("@ProjectId", $projectId) | Out-Null
            $langReader = $langCmd.ExecuteReader()
            $languages = @()
            while ($langReader.Read()) {
                $languages += $langReader["Name"]
            }
            $langReader.Close()

            # 3️⃣ Get associated categories
            $catCmd = $connection.CreateCommand()
            $catCmd.CommandText = @"
SELECT C.Name
FROM ProjectCategory PC
INNER JOIN Category C ON PC.CategoryId = C.CategoryId
WHERE PC.ProjectId = @ProjectId;
"@
            $catCmd.Parameters.AddWithValue("@ProjectId", $projectId) | Out-Null
            $catReader = $catCmd.ExecuteReader()
            $categories = @()
            while ($catReader.Read()) {
                $categories += $catReader["Name"]
            }
            $catReader.Close()

            # 4️⃣ Build the project object
            $projectObj = [PSCustomObject]@{
                ProjectId = $projectId
                Title     = $row.Title
                Summary   = $row.Summary
                Author    = $row.Author
                Date      = [datetime]$row.Date
                Keywords  = if ($row.Keywords) { $row.Keywords -split ',' | ForEach-Object { $_.Trim() } } else { @() }
                Permalink = $row.Permalink
                Thumbnail = $row.Thumbnail
                FilePath = $row.FilePath
                Categories = $categories
                Languages  = $languages
            }

            $projects += $projectObj
        }
    } catch {
        Write-Error "❌ An error occurred while retrieving projects: $_"
    } finally {
        $connection.Close()
    }

    return $projects
}


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


function Import-ProjectFilesToDatabase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Root path where project data files are stored')]
        [string]$Path
    )

    $projectFiles = Get-ProjectFiles -Path $Path

    if (-not $projectFiles -or $projectFiles.Count -eq 0) {
        Write-Warning "No project files found in: $Path"
        return
    }

    # Get the list of categories and languages from the database
    $categoryList = Get-CategoryListFromDatabase
    $languageList = Get-LanguageListFromDatabase

    foreach ($project in $projectFiles) {
        # 🏷 Get CategoryId
        $categoryName = $project.Category
        $categoryRow = $categoryList | Where-Object { $_.Name -eq $categoryName }

        if (-not $categoryRow) {
            Write-Warning "⚠️ Category '$categoryName' not found in database. Skipping project: $($project.Title)"
            continue
        }
        $categoryId = $categoryRow.CategoryId

        # 🏷 Get LanguageIds
        $languageIds = @()
        foreach ($lang in $project.Languages) {
            $langRow = $languageList | Where-Object { $_.Name -eq $lang }
            if ($langRow) {
                $languageIds += $langRow.LanguageId
            } else {
                Write-Warning "⚠️ Language '$lang' not found in database for project: $($project.Title)"
            }
        }

        if ($languageIds.Count -eq 0) {
            Write-Warning "⚠️ No valid languages found for project: $($project.Title). Skipping."
            continue
        }

        # 📦 Prepare Keywords
        $keywords = @()
        if ($project.Keywords) {
            $keywords = $project.Keywords
        }

        # 🗂 Add project to database
        Add-ProjectToDatabase `
            -Title $project.Title `
            -Summary $project.Summary `
            -Author $project.Author `
            -Date ([datetime]$project.Date) `
            -Keywords $keywords `
            -Permalink $project.Permalink `
            -Thumbnail $project.Thumbnail `
            -LanguageIds $languageIds `
            -FilePath $project.FilePath `
            -CategoryIds @($categoryId)

        Write-Host "✅ Project '$($project.Title)' imported successfully."
    }
}


function Add-ProjectToDatabase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Project title')]
        [string]$Title,

        [Parameter(Mandatory = $false, HelpMessage = 'Project summary')]
        [string]$Summary,

        [Parameter(Mandatory = $true, HelpMessage = 'Project author')]
        [string]$Author,

        [Parameter(Mandatory = $true, HelpMessage = 'Project date')]
        [datetime]$Date,

        [Parameter(Mandatory = $false, HelpMessage = 'Project keywords')]
        [string[]]$Keywords,

        [Parameter(Mandatory = $false, HelpMessage = 'Project permalink')]
        [string]$Permalink,

        [Parameter(Mandatory = $false, HelpMessage = 'Project FilePath')]
        [string]$FilePath,

        [Parameter(Mandatory = $false, HelpMessage = 'Project thumbnail')]
        [string]$Thumbnail,

        [Parameter(Mandatory = $true, HelpMessage = 'List of LanguageIds')]
        [int[]]$LanguageIds,

        [Parameter(Mandatory = $true, HelpMessage = 'List of CategoryIds')]
        [int[]]$CategoryIds
    )

    # Prepare values
    $keywordsString = $null
    if ($Keywords) {
        $keywordsString = ($Keywords -join ', ')
    }

    # Open SQLite connection
    $dbPath = Get-DatabaseFilePath  # assuming you have this in Common.ps1 / Database.ps1
    $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $connection.Open()

    try {
        $transaction = $connection.BeginTransaction()

        # 1️⃣ Insert Project
        $insertProjectCmd = $connection.CreateCommand()
        $insertProjectCmd.CommandText = @"
INSERT INTO Project (Title, Summary, Author, Date, Keywords, Permalink, Thumbnail, FilePath)
VALUES (@Title, @Summary, @Author, @Date, @Keywords, @Permalink, @Thumbnail, @FilePath);
"@
        $insertProjectCmd.Parameters.AddWithValue("@Title", $Title) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@Summary", $Summary) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@Author", $Author) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@Date", $Date.ToString("yyyy-MM-dd")) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@Keywords", $keywordsString) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@Permalink", $Permalink) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@Thumbnail", $Thumbnail) | Out-Null
        $insertProjectCmd.Parameters.AddWithValue("@FilePath", $FilePath) | Out-Null

        $insertProjectCmd.ExecuteNonQuery() | Out-Null

        # Get the last inserted ProjectId
        $projectId = $connection.LastInsertRowId
        Write-Host "✅ Project added with ProjectId: $projectId"

        # 2️⃣ Insert into ProjectLanguage
        foreach ($langId in $LanguageIds) {
            $insertLangCmd = $connection.CreateCommand()
            $insertLangCmd.CommandText = "INSERT INTO ProjectLanguage (ProjectId, LanguageId) VALUES (@ProjectId, @LanguageId);"
            $insertLangCmd.Parameters.AddWithValue("@ProjectId", $projectId) | Out-Null
            $insertLangCmd.Parameters.AddWithValue("@LanguageId", $langId) | Out-Null
            $insertLangCmd.ExecuteNonQuery() | Out-Null
            Write-Host "🔗 Linked to LanguageId: $langId"
        }

        # 3️⃣ Insert into ProjectCategory
        foreach ($catId in $CategoryIds) {
            $insertCatCmd = $connection.CreateCommand()
            $insertCatCmd.CommandText = "INSERT INTO ProjectCategory (ProjectId, CategoryId) VALUES (@ProjectId, @CategoryId);"
            $insertCatCmd.Parameters.AddWithValue("@ProjectId", $projectId) | Out-Null
            $insertCatCmd.Parameters.AddWithValue("@CategoryId", $catId) | Out-Null
            $insertCatCmd.ExecuteNonQuery() | Out-Null
            Write-Host "🔗 Linked to CategoryId: $catId"
        }

        # Commit transaction
        $transaction.Commit()
        Write-Host "✅ Transaction committed successfully."

    } catch {
        Write-Error "❌ An error occurred: $_"
        $transaction.Rollback()
    } finally {
        $connection.Close()
    }
}
