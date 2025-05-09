
function Add-ProxyListToDb {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$ProxyList,

        [Parameter(Mandatory = $false)]
        [int]$BatchSize = 50, # Default batch size for efficiency

        [Parameter(Mandatory = $false)]
        [switch]$RetryOnError
    )
    $sep = [string]::new('-', 50)

    # Check if there are proxies to insert
    if ($ProxyList.Count -eq 0) {
        Write-Host "No proxies to insert." -ForegroundColor Yellow
        return $false
    }

    # Connect to SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    $UnknownCountryId = Get-UnknownCountryId
    $UnknownProtocolId = Get-ProtocolUnknownProtocolId

    try {
        # Lookup all country codes and protocol IDs at once and store them in dictionaries
        $countryDict = @{}
        $protocolDict = @{}

        # Retrieve CountryId mappings
        $countryLookupCmd = $connection.CreateCommand()
        $countryLookupCmd.CommandText = "SELECT CountryCode, CountryId FROM Country"
        $reader = $countryLookupCmd.ExecuteReader()
        while ($reader.Read()) {
            $countryDict[$reader["CountryCode"]] = $reader["CountryId"]
        }
        $reader.Close()

        # Retrieve ProtocolId mappings
        $protocolLookupCmd = $connection.CreateCommand()
        $protocolLookupCmd.CommandText = "SELECT Name, ProtocolId FROM Protocol"
        $reader = $protocolLookupCmd.ExecuteReader()
        while ($reader.Read()) {
            $protocolDict[$reader["Name"]] = $reader["ProtocolId"]
        }
        $reader.Close()

        # Prepare batch insert

        $insertCommand = $connection.CreateCommand()
        [string]$valueStrings = ''
        $parameters = @{}

        $proxyBatchCounter = 0
        $currentBatchIndex = 0
        $proxyTotalCounter = 0
        $ProxyListCount = $ProxyList.Count
        $TotalBatchToDo = $ProxyListCount / $BatchSize

        $SortedProxyList = $ProxyList | sort -Property Hostname -Descending
        $proxySet = @{} # HashTable to track unique proxies
        [System.Collections.ArrayList]$valuesToInsert = [System.Collections.ArrayList]::new()

        foreach ($proxy in $ProxyList) {
            $key = "$($proxy.Hostname):$($proxy.Port)"
            if (-not $proxySet.ContainsKey($key)) {
                $proxySet[$key] = $true # Mark this proxy as seen

            } else {
                Write-Host "Found Duplicate! $key" -f DarkRed
                continue;
            }

            $pName = $proxy.ProtocolName
            $cnCode = $proxy.CountryCode
            # Validate CountryId and ProtocolId
            $countryId = $countryDict[$proxy.CountryCode]

            if ($Null -eq $($proxy.ProtocolName)) {
                $protocolId = $protocolDict['UNKNOWN']
            } else {
                $protocolId = $protocolDict[$proxy.ProtocolName]
            }

            $log = "Total Proxies [{0:d3}/{1:d3}] Total Batches [{2:d2}/{3:d2}] Current Batch [{4:d3}/{5:d3}] Insert {6}" -f ($proxyTotalCounter + 1), $ProxyListCount, ($currentBatchIndex + 1), $TotalBatchToDo, ($proxyBatchCounter + 1), $BatchSize, $key
            WRite-Host "$log" -f DarkCyan

            if (-not $countryId) {
                $countryId = $UnknownCountryId
                Write-Host "proxy $($proxy.Hostname): CountryCode '$($proxy.CountryCode)' not found. Using Unknown" -ForegroundColor Red
            }
            if (-not $protocolId) {
                $protocolId = $UnknownProtocolId
                Write-Host "proxy $($proxy.Hostname): Protocol '$($proxy.ProtocolName)' not found. Using Unknown" -ForegroundColor Red
            }
            $proxyBatchCounter++

            # Build parameterized query
            $paramIndex = $batchCounter
            [string]$tmpValues = "('{0}', {1}, {2}, {3}, {4})" -f $proxy.Hostname, $proxy.Port, $countryId, $protocolId, 0
            $valueStrings += "`n$tmpValues,"
            [void]$valuesToInsert.Add($tmpValues)

            # Execute batch when reaching the batch size
            if ($proxyBatchCounter -eq $BatchSize) {

                $currentBatchIndex++

                $AllValues = $valueStrings.TrimEnd(',') + ';'
                $CommandText = "INSERT OR IGNORE INTO Proxy (Hostname, Port, CountryId, ProtocolId, Flags) VALUES {0}" -f $AllValues
                Write-DebugLog "$CommandText"
                $insertCommand.CommandText = $CommandText

                $InsertFailed = $False

                try {
                    $Ret = $insertCommand.ExecuteNonQuery()
                    Write-Host "Success! $Ret Rows added " -f DarkGreen
                } catch {
                    $InsertFailed = $True
                    [System.Management.Automation.ErrorRecord]$record = $_
                    $msg = "[{1}] {0}" -f $record.ScriptStackTrace, $record.Exception.Message

                    Write-Host "[INSERT ERROR] " -f DarkRed
                    Write-Host "[$proxyBatchCounter ITEMS] $Ret" -f DarkYellow
                    Write-Host "$msg" -f DarkGray
                    Write-Host "`n$sep`n$($insertCommand.CommandText)`n$sep`n`n" -f Blue
                }

                if (($InsertFailed) -and ($RetryOnError)) {
                    $t = $valuesToInsert.Count
                    $i = 0
                    foreach ($values in $valuesToInsert) {
                        $CommandText = "INSERT OR IGNORE INTO Proxy (Hostname, Port, CountryId, ProtocolId, Flags) VALUES {0};" -f $values
                        Write-DebugLog "$CommandText"
                        $insertCommand.CommandText = $CommandText
                        $i++

                        Write-Host "SINGULAR INSERT ($i/$t) [$CommandText]" -f DarkYellow -NoNewline
                        try {
                            $Ret = $insertCommand.ExecuteNonQuery()
                            Write-Host "Success! $Ret Rows added " -f DarkGreen
                        } catch {

                            [System.Management.Automation.ErrorRecord]$record = $_
                            $msg = "[{1}] {0}" -f $record.ScriptStackTrace, $record.Exception.Message
                            $record.Exception | Select *
                            return


                            Write-Host "[INSERT ERROR] " -f DarkRed -NoNewline
                            Write-Host "[$proxyBatchCounter ITEMS] $Ret" -f DarkYellow -NoNewline
                            Write-Host "$msg" -f DarkGray
                            Write-Host "`n$sep`n$($insertCommand.CommandText)`n$sep`n`n" -f Blue
                        }
                    }
                }

                $valueStrings = ''

                $valuesToInsert.Clear()

                # Reset for next batch
                $proxyBatchCounter = 0

                $parameters.Clear()
            }

            $proxyTotalCounter++
        }

        Write-Host "Insert $proxyBatchCounter remaining items" -f DarkMagenta

        # Insert any remaining items
        if ($proxyBatchCounter -gt 0) {


            $currentBatchIndex++

            $AllValues = $valueStrings.TrimEnd(',') + ';'
            $CommandText = "INSERT OR IGNORE INTO Proxy (Hostname, Port, CountryId, ProtocolId, Flags) VALUES {0}" -f $AllValues
            Write-DebugLog "$CommandText"
            $insertCommand.CommandText = $CommandText

            $InsertFailed = $False


            try {
                $Ret = $insertCommand.ExecuteNonQuery()
                Write-Host "Success! $Ret Rows added " -f DarkGreen
            } catch {
                $InsertFailed = $True
                [System.Management.Automation.ErrorRecord]$record = $_
                $msg = "[{1}] {0}" -f $record.ScriptStackTrace, $record.Exception.Message

                Write-Host "[INSERT ERROR] " -f DarkRed -NoNewline
                Write-Host "[$proxyBatchCounter ITEMS] $Ret" -f DarkYellow -NoNewline
                Write-Host "$msg" -f DarkGray
                Write-Host "`n$sep`n$($insertCommand.CommandText)`n$sep`n`n" -f Blue
            }
            if (($InsertFailed) -and ($RetryOnError)) {
                $t = $valuesToInsert.Count
                $i = 0
                foreach ($values in $valuesToInsert) {
                    $i++
                    $CommandText = "INSERT OR IGNORE INTO Proxy (Hostname, Port, CountryId, ProtocolId, Flags) VALUES {0};" -f $values
                    Write-Host "SINGULAR INSERT ($i/$t) [$CommandText]" -f DarkYellow -NoNewline
                    $insertCommand.CommandText = $CommandText

                    try {
                        $Ret = $insertCommand.ExecuteNonQuery()
                        Write-Host "Success! $Ret Rows added " -f DarkGreen
                    } catch {
                        [System.Management.Automation.ErrorRecord]$record = $_
                        $msg = "[{1}] {0}" -f $record.ScriptStackTrace, $record.Exception.Message

                        Write-Host "[INSERT ERROR] " -f DarkRed -NoNewline
                        Write-Host "[$proxyBatchCounter ITEMS] $Ret" -f DarkYellow -NoNewline
                        Write-Host "$msg" -f DarkGray
                        Write-Host "`n$sep`n$($insertCommand.CommandText)`n$sep`n`n" -f Blue
                    }
                }
            }
            # Reset for next batch
            $proxyBatchCounter = 0
        }

        Write-Verbose "Proxies inserted successfully."
        return $true

    } catch {
        Show-ExceptionDetails ($_) -ShowStack
    }
    finally {
        $connection.Close()
    }
}





function Add-Proxy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProxyAddress,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateSet("HTTP", "HTTPS", "SOCKS4", "SOCKS5")]
        [string]$Protocol,

        [Parameter(Mandatory = $false)]
        [string]$CountryCode,

        [Parameter(Mandatory = $false)]
        [ulong]$Flags = 0,

        [Parameter(Mandatory = $false)]
        [datetime]$RunningsinceUTC = (Get-Date -AsUTC),

        [Parameter(Mandatory = $false)]
        [switch]$ReplaceOnError
    )

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    try {

        $protocolId = Get-ProtocolIdFromProtocollName $Protocol
        $countryId = Get-CountryIdFromCountryCode $CountryCode
        # Insert into Proxy table
        $insertCommand = $connection.CreateCommand()
        $InsertStatement = 'INSERT INTO'
        if ($ReplaceOnError) { $InsertStatement = 'INSERT OR IGNORE INTO' }
        $FullStatement = '{0} Proxy (Hostname, Port, CountryId, ProtocolId, Flags) 
                          VALUES (@Hostname, @Port, @CountryId, @ProtocolId, @Flags)' -f $InsertStatement

        $insertCommand.CommandText = $FullStatement
        $insertCommand.Parameters.AddWithValue("@Hostname", $ProxyAddress) | Out-Null
        $insertCommand.Parameters.AddWithValue("@Port", $Port) | Out-Null
        $insertCommand.Parameters.AddWithValue("@CountryId", $countryId) | Out-Null
        $insertCommand.Parameters.AddWithValue("@ProtocolId", $protocolId) | Out-Null
        $insertCommand.Parameters.AddWithValue("@Flags", $Flags) | Out-Null

        Write-DebugDbCommand $InsertStatement $insertCommand

        $connection.Close()

        try {
            $Rows = $insertCommand.ExecuteNonQuery()
        } catch {
            $strError = "$_"
            if ($strError.IndexOf('UNIQUE constraint failed') -ne -1) {
                Write-Verbose "[Insert Error] Duplicate entry detected"
                return $False
            }
            Write-Verbose "$_"
            return $False
        }

        Write-Verbose "Proxy added successfully"
        return $True
    } catch {
        Show-ExceptionDetails ($_) -ShowStack
        return $False
    }
}



function Test-AddMultipleProxies {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    try {
        # Lookup the CountryId based on CountryCode
        $lookupCommand = $connection.CreateCommand()
        $InsertStatement = @"
INSERT INTO Proxy (Hostname, Port, CountryId, ProtocolId, Flags) VALUES
('99.80.11.54', 3128, 82, 5, 0),
('95.164.117.150', 47745, 66, 5, 0),
('95.154.124.114', 58000, 143, 5, 0),
('91.65.103.3', 80, 66, 5, 0),
('91.132.132.188', 3128, 113, 5, 0),
('91.107.154.214', 80, 66, 5, 0);        
"@
        $lookupCommand.CommandText = $InsertStatement
        $RowsAdded = $lookupCommand.ExecuteNonQuery()

        $connection.Close()

        Write-Host "SUCCESS $RowsAdded Rows Added" -ForegroundColor DarkCyan

    } catch {
        throw $_
    }
}


function Delete-AllProxies {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    try {
        # Lookup the CountryId based on CountryCode
        $lookupCommand = $connection.CreateCommand()
        $DeleteStatement = "DELETE FROM Proxy;"
        $lookupCommand.CommandText = $DeleteStatement
        $RowsDeleted = $lookupCommand.ExecuteNonQuery()

        $connection.Close()

        Write-Host "SUCCESS Deleted $RowsDeleted Rows" -ForegroundColor DarkCyan

    } catch {
        throw $_
    }
}

function Get-ProtocolUnknownProtocolId {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    try {
        Write-DebugLog "Lookup the ProtocolId based on Protocol '$Protocol' ... " -ForegroundColor Cyan -NoNewline
        $lookupCommand = $connection.CreateCommand()
        $lookupCommand.CommandText = "SELECT ProtocolId FROM Protocol WHERE Name = 'UNKNOWN'"
        $UnknownProtocolId = $lookupCommand.ExecuteScalar()

        $connection.Close()

        if (-not $UnknownProtocolId) {
            Write-DebugLog "`n[ERROR] UNKNOWN not found in Protocol table." -ForegroundColor Red
            return -1
        }
        Write-DebugLog "Found ID $protocolId for '$Protocol'" -ForegroundColor DarkCyan

        return $UnknownProtocolId
    } catch {
        throw $_
    }
}


function Get-ProtocolIdFromProtocollName {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateSet("HTTP", "HTTPS", "SOCKS4", "SOCKS5", "UNKNOWN")]
        [string]$Protocol
    )

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()



    try {
        Write-DebugLog "Lookup the ProtocolId based on Protocol '$Protocol' ... " -ForegroundColor Cyan -NoNewline


        # Lookup the ProtocolId based on Protocol
        $lookupCommand = $connection.CreateCommand()
        $lookupCommand.CommandText = "SELECT ProtocolId FROM Protocol WHERE Name = @Name"
        $lookupCommand.Parameters.AddWithValue("@Name", $Protocol) | Out-Null
        $protocolId = $lookupCommand.ExecuteScalar()
        $connection.Close()

        if (-not $protocolId) {
            $UnknownProtocolId = Get-ProtocolUnknownProtocolId
            Write-DebugLog "`n[ERROR] Protocol '$Protocol' not found in the Protocol table." -ForegroundColor Red
            return $UnknownProtocolId
        }
        Write-DebugLog "Found ID $protocolId for '$Protocol'" -ForegroundColor DarkCyan

        return $protocolId
    } catch {
        throw $_
    }
}


function Get-UnknownCountryId {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    try {
        Write-DebugLog "Lookup the CountryId based on CountryCode '$CountryCode' ... " -ForegroundColor Cyan -NoNewline
        # Lookup the CountryId based on CountryCode
        $lookupCommand = $connection.CreateCommand()
        $lookupCommand.CommandText = "SELECT CountryId FROM Country WHERE CountryCode = 'ZZ'"
        $UnknownCountryId = $lookupCommand.ExecuteScalar()

        $connection.Close()

        if (-not $UnknownCountryId) {
            Write-DebugLog "`n[ERROR] UNKNOWN not found in Country table." -ForegroundColor Red
            return -1
        }
        Write-DebugLog " Found ID $countryId for '$CountryCode'" -ForegroundColor DarkCyan

        return $UnknownCountryId
    } catch {
        throw $_
    }
}

function Get-CountryIdFromCountryCode {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$CountryCode
    )

    # Connect to the SQLite database
    $databasePath = Get-DatabaseFilePath
    $connectionString = "Data Source=$databasePath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection ($connectionString)
    $connection.Open()

    try {
        Write-DebugLog "Lookup the CountryId based on CountryCode '$CountryCode' ... " -ForegroundColor Cyan -NoNewline
        # Lookup the CountryId based on CountryCode
        $lookupCommand = $connection.CreateCommand()
        $lookupCommand.CommandText = "SELECT CountryId FROM Country WHERE CountryCode = @CountryCode"
        $lookupCommand.Parameters.AddWithValue("@CountryCode", $CountryCode) | Out-Null
        $countryId = $lookupCommand.ExecuteScalar()
        $connection.Close()

        if (-not $countryId) {
            Write-DebugLog "`n[ERROR] CountryCode '$CountryCode' not found in the Country table." -ForegroundColor Red
            $UnknownCountryId = Get-UnknownCountryId
            return $UnknownCountryId
        }
        Write-DebugLog " Found ID $countryId for '$CountryCode'" -ForegroundColor DarkCyan

        return $countryId
    } catch {
        throw $_
    }
}



