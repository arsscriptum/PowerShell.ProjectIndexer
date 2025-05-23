#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   ShowProject.ps1                                                              ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


[CmdletBinding(SupportsShouldProcess = $true)]
param ()

$CommonScript = "$PSScriptRoot\Common.ps1"
. "$CommonScript"

$DatabaseScript = "$PSScriptRoot\Database.ps1"
. "$DatabaseScript"
Add-SqlLiteTypes


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



function Show-ObjectTree {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [Object]$RootObject,
        [Parameter(Mandatory = $False)]
        [string]$RootObjectName = "Root"
    )

    # Recursive helper function to add object nodes to the TreeView
    function Add-Node {
        param (
            [System.Windows.Forms.TreeNode]$ParentNode,
            [string]$Key,
            [Object]$Value
        )

        if($Value -eq $Null){
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = "$Key`: NULL"
            [void]$ParentNode.Nodes.Add($node)
            return
        }
        $type = $Value.GetType()

        if ($Value -is [PSCustomObject]) {
            # Handle PSCustomObject (key-value pairs)
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = "$Key`: (Object)"
            [void]$ParentNode.Nodes.Add($node)

            $Value.PSObject.Properties | ForEach-Object {
                Add-Node $node $_.Name $_.Value
            }
        }
        elseif ($Value -is [Hashtable]) {
            # Handle Hashtable (key-value pairs)
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = "$Key`: (Hashtable)"
            [void]$ParentNode.Nodes.Add($node)

            $Value.GetEnumerator() | ForEach-Object {
                Add-Node $node $_.Key $_.Value
            }
        }
        elseif ($Value -is [System.Collections.ArrayList] -or $Value -is [Array]) {
            # Handle arrays and ArrayLists
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = "$Key`: (Array)"
            [void]$ParentNode.Nodes.Add($node)

            for ($i = 0; $i -lt $Value.Count; $i++) {
                Add-Node $node "[$i]" $Value[$i]
            }
        }
        else {
            # Handle primitive values
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = "$Key`: $Value [$type]"
            [void]$ParentNode.Nodes.Add($node)
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "json inspect $RootObjectName"
    [int]$TreeViewWndHeight = 640
    [int]$TreeViewWndWidth = 480
    $Form.Size = New-Object System.Drawing.Size($TreeViewWndHeight, $TreeViewWndWidth)
    # Set the properties
    $Form.StartPosition = "CenterScreen" # Set the startup location
    $Form.FormBorderStyle = "FixedSingle" # Set the border style to SingleBorderWindow
    $Form.MaximizeBox = $false          # Prevent resizing (disables the maximize button)
    $TreeView = New-Object System.Windows.Forms.TreeView
    $TreeView.Location = New-Object System.Drawing.Point(10, 10)
    $TreeView.Size = New-Object System.Drawing.Size(($TreeViewWndHeight-30), ($TreeViewWndWidth - 50))
    $Form.Controls.Add($TreeView)

    # Create the root node
    $rootNode = New-Object System.Windows.Forms.TreeNode
    $rootNode.Text = "$RootObjectName"
    [void]$TreeView.Nodes.Add($rootNode)

    # Add the object structure to the TreeView
    if ($RootObject -is [PSCustomObject]) {
        $RootObject.PSObject.Properties | ForEach-Object {
            Add-Node $rootNode $_.Name $_.Value
        }
    }
    elseif ($RootObject -is [Hashtable]) {
        $RootObject.GetEnumerator() | ForEach-Object {
            Add-Node $rootNode $_.Key $_.Value
        }
    }
    elseif ($RootObject -is [System.Collections.ArrayList] -or $RootObject -is [Array]) {
        for ($i = 0; $i -lt $RootObject.Count; $i++) {
            Add-Node $rootNode "[$i]" $RootObject[$i]
        }
    }
    else {
        Add-Node $rootNode "Value" $RootObject
    }

    $rootNode.Expand()

    $Form.Add_Shown({$Form.Activate()})
    [void]$Form.ShowDialog()

    $Form.Dispose()
}


# Load data from DB
$categories = Get-CategoryListFromDatabase | Select-Object -ExpandProperty Name
$languages = Get-LanguageListFromDatabase | Select-Object -ExpandProperty Name

# Add 'ALL' option
$categoriesList = @('ALL') + $categories
$languagesList = @('ALL') + $languages

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Project Browser"
$form.Size = New-Object System.Drawing.Size(1000, 730)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $true   # Or $false if you want to disable minimize too

# === Search GroupBox === (Left)
$groupBoxSearch = New-Object System.Windows.Forms.GroupBox
$groupBoxSearch.Text = "Search"
$groupBoxSearch.Size = New-Object System.Drawing.Size(460, 180)
$groupBoxSearch.Location = New-Object System.Drawing.Point(20, 20)

# Label: Categories
$labelCategories = New-Object System.Windows.Forms.Label
$labelCategories.Text = "Categories"
$labelCategories.Size = New-Object System.Drawing.Size(80, 20)
$labelCategories.Location = New-Object System.Drawing.Point(20, 30)

# ComboBox: Categories
$comboCategories = New-Object System.Windows.Forms.ComboBox
$comboCategories.Size = New-Object System.Drawing.Size(300, 20)
$comboCategories.Location = New-Object System.Drawing.Point(120, 30)
$comboCategories.DropDownStyle = 'DropDownList'
$comboCategories.Items.AddRange($categoriesList)
$comboCategories.SelectedIndex = 0

# Label: Languages
$labelLanguages = New-Object System.Windows.Forms.Label
$labelLanguages.Text = "Languages"
$labelLanguages.Size = New-Object System.Drawing.Size(80, 20)
$labelLanguages.Location = New-Object System.Drawing.Point(20, 65)

# ComboBox: Languages
$comboLanguages = New-Object System.Windows.Forms.ComboBox
$comboLanguages.Size = New-Object System.Drawing.Size(300, 20)
$comboLanguages.Location = New-Object System.Drawing.Point(120, 65)
$comboLanguages.DropDownStyle = 'DropDownList'
$comboLanguages.Items.AddRange($languagesList)
$comboLanguages.SelectedIndex = 0

# Label: Keywords
$labelKeywords = New-Object System.Windows.Forms.Label
$labelKeywords.Text = "Keywords"
$labelKeywords.Size = New-Object System.Drawing.Size(80, 20)
$labelKeywords.Location = New-Object System.Drawing.Point(20, 100)

# TextBox: Keywords
$textBoxKeywords = New-Object System.Windows.Forms.TextBox
$textBoxKeywords.Size = New-Object System.Drawing.Size(300, 20)
$textBoxKeywords.Location = New-Object System.Drawing.Point(120, 100)

# Button: Reset
$buttonReset = New-Object System.Windows.Forms.Button
$buttonReset.Text = "Reset"
$buttonReset.Size = New-Object System.Drawing.Size(100, 30)
$buttonReset.Location = New-Object System.Drawing.Point(120, 135)

# Button: Search
$buttonSearch = New-Object System.Windows.Forms.Button
$buttonSearch.Text = "Search"
$buttonSearch.Size = New-Object System.Drawing.Size(100, 30)
$buttonSearch.Location = New-Object System.Drawing.Point(240, 135)

# Add Search controls to GroupBox
$groupBoxSearch.Controls.Add($labelCategories)
$groupBoxSearch.Controls.Add($comboCategories)
$groupBoxSearch.Controls.Add($labelLanguages)
$groupBoxSearch.Controls.Add($comboLanguages)
$groupBoxSearch.Controls.Add($labelKeywords)
$groupBoxSearch.Controls.Add($textBoxKeywords)
$groupBoxSearch.Controls.Add($buttonReset)
$groupBoxSearch.Controls.Add($buttonSearch)

# === Import GroupBox === (Right)
$groupBoxImport = New-Object System.Windows.Forms.GroupBox
$groupBoxImport.Text = "Import"
$groupBoxImport.Size = New-Object System.Drawing.Size(440, 180)
$groupBoxImport.Location = New-Object System.Drawing.Point(520, 20)

# TextBox: Directory Path
$textBoxDirPath = New-Object System.Windows.Forms.TextBox
$textBoxDirPath.Size = New-Object System.Drawing.Size(340, 20)
$textBoxDirPath.Location = New-Object System.Drawing.Point(20, 30)

# Button: Browse (...)
$buttonBrowse = New-Object System.Windows.Forms.Button
$buttonBrowse.Text = "..."
$buttonBrowse.Size = New-Object System.Drawing.Size(40, 20)
$buttonBrowse.Location = New-Object System.Drawing.Point(370, 30)

# ListBox: Directory List
$listBoxDirs = New-Object System.Windows.Forms.ListBox
$listBoxDirs.Size = New-Object System.Drawing.Size(390, 80)
$listBoxDirs.Location = New-Object System.Drawing.Point(20, 60)

# Button: Add (+)
$buttonAddDir = New-Object System.Windows.Forms.Button
$buttonAddDir.Text = "+"
$buttonAddDir.Size = New-Object System.Drawing.Size(40, 20)
$buttonAddDir.Location = New-Object System.Drawing.Point(20, 150)

# Button: Remove (-)
$buttonRemoveDir = New-Object System.Windows.Forms.Button
$buttonRemoveDir.Text = "-"
$buttonRemoveDir.Size = New-Object System.Drawing.Size(40, 20)
$buttonRemoveDir.Location = New-Object System.Drawing.Point(80, 150)

$buttonImportDir = New-Object System.Windows.Forms.Button
$buttonImportDir.Text = "import"
$buttonImportDir.Size = New-Object System.Drawing.Size(80, 20)
$buttonImportDir.Location = New-Object System.Drawing.Point(150, 150)
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 5000      # Time tooltip stays visible (ms)
$toolTip.InitialDelay = 500       # Delay before it appears (ms)
$toolTip.ReshowDelay = 100        # Delay between tooltips
$toolTip.ShowAlways = $true       # Show even if the parent window is inactive
$toolTip.SetToolTip($buttonImportDir, "Import all projects from the selected directory.")



$buttonResetAll = New-Object System.Windows.Forms.Button
$buttonResetAll.Text = "reset all"
$buttonResetAll.Size = New-Object System.Drawing.Size(80, 20)
$buttonResetAll.Location = New-Object System.Drawing.Point(330, 150)
$toolTip1 = New-Object System.Windows.Forms.ToolTip
$toolTip1.AutoPopDelay = 5000      # Time tooltip stays visible (ms)
$toolTip1.InitialDelay = 500       # Delay before it appears (ms)
$toolTip1.ReshowDelay = 100        # Delay between tooltips
$toolTip1.ShowAlways = $true       # Show even if the parent window is inactive
$toolTip1.SetToolTip($buttonResetAll, "Remove all projects from the database and clear the list, then reimport")

# Add Import controls to GroupBox
$groupBoxImport.Controls.Add($textBoxDirPath)
$groupBoxImport.Controls.Add($buttonBrowse)
$groupBoxImport.Controls.Add($listBoxDirs)
$groupBoxImport.Controls.Add($buttonAddDir)
$groupBoxImport.Controls.Add($buttonRemoveDir)
$groupBoxImport.Controls.Add($buttonImportDir)
$groupBoxImport.Controls.Add($buttonResetAll)

# === Projects GroupBox ===
$groupBoxProjects = New-Object System.Windows.Forms.GroupBox
$groupBoxProjects.Text = "Projects"
$groupBoxProjects.Size = New-Object System.Drawing.Size(940, 420)
$groupBoxProjects.Location = New-Object System.Drawing.Point(20, 220)

# ListView: Projects (Details Mode)
$listViewProjects = New-Object System.Windows.Forms.ListView
$listViewProjects.Size = New-Object System.Drawing.Size(900, 370)
$listViewProjects.Location = New-Object System.Drawing.Point(20, 30)
$listViewProjects.View = 'Details'
$listViewProjects.FullRowSelect = $true
$listViewProjects.GridLines = $true
$listViewProjects.ShowItemToolTips = $true
# Add Columns
$listViewProjects.Columns.Add("Title", 120)
$listViewProjects.Columns.Add("Summary", 200)
$listViewProjects.Columns.Add("Author", 100)
$listViewProjects.Columns.Add("Date", 80)
$listViewProjects.Columns.Add("Permalink", 150)
$listViewProjects.Columns.Add("Categories", 100)
$listViewProjects.Columns.Add("Languages", 100)
$listViewProjects.Columns.Add("Keywords", 100)

# === Copyright Label ===
$labelCopyright = New-Object System.Windows.Forms.Label
$labelCopyright.Text = "Copyright Guillaume Plante 2024"
$labelCopyright.AutoSize = $true
$labelCopyright.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Regular)
$labelCopyright.Location = New-Object System.Drawing.Point(20, 650)  # Adjust Y position as needed

# Add to the Form
$form.Controls.Add($labelCopyright)

# Add ListView to Projects GroupBox
$groupBoxProjects.Controls.Add($listViewProjects)

# Add GroupBoxes to Form
$form.Controls.Add($groupBoxSearch)
$form.Controls.Add($groupBoxImport)
$form.Controls.Add($groupBoxProjects)

# --- Cache all projects once ---
$allProjectsCache = Get-ProjectListFromDatabase

# --- Function: Load Projects ---
function Update-ProjectList {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$SelectedCategory = 'ALL',
        [Parameter(Mandatory = $false)]
        [string]$SelectedLanguage = 'ALL',
        [Parameter(Mandatory = $false)]
        [string]$KeywordsPattern = '',
        [Parameter(Mandatory = $false)]
        [switch]$Clear
    )
    if($Clear){
        $listViewProjects.Items.Clear()
    }

    $filtered = $allProjectsCache | Where-Object {
        ($SelectedCategory -eq 'ALL' -or ($_.Categories -contains $SelectedCategory)) -and
        ($SelectedLanguage -eq 'ALL' -or ($_.Languages -contains $SelectedLanguage)) -and
        (
            [string]::IsNullOrWhiteSpace($KeywordsPattern) -or 
            ($_.Keywords -join ' ' -match $KeywordsPattern)
        )
    }

    foreach ($proj in $filtered) {
        $item = New-Object System.Windows.Forms.ListViewItem($proj.Title)
        $item.SubItems.Add($proj.Summary)
        $item.SubItems.Add($proj.Author)
        $item.SubItems.Add($proj.Date.ToString("yyyy-MM-dd"))
        $item.SubItems.Add($proj.Permalink)
        $item.SubItems.Add(($proj.Categories -join ', '))
        $item.SubItems.Add(($proj.Languages -join ', '))
        $item.SubItems.Add(($proj.Keywords -join ', '))
        $item.ToolTipText = "Right-click for options on: $($proj.Title)"

        $item.Tag = $proj
        $listViewProjects.Items.Add($item)

    }
}

# --- Load existing directories on start ---
try {
    $dirList = Import-ProjectDirList
    if ($dirList) {
        foreach ($dir in $dirList) {
            $listBoxDirs.Items.Add($dir)
        }
    }
} catch {
    Write-Warning "Failed to load directory list: $_"
}

# --- Button Handlers: ---

$buttonBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq 'OK') {
        $textBoxDirPath.Text = $folderBrowser.SelectedPath
    }
})

$buttonAddDir.Add_Click({
    $dir = $textBoxDirPath.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not ($listBoxDirs.Items -contains $dir)) {
        $listBoxDirs.Items.Add($dir)
        Save-ProjectDirList -Directories ($listBoxDirs.Items)
    }
})

$buttonRemoveDir.Add_Click({
    $index = $listBoxDirs.SelectedIndex
    if ($index -ge 0) {
        $listBoxDirs.Items.RemoveAt($index)
        Save-ProjectDirList -Directories ($listBoxDirs.Items)
    }
})

$buttonReset.Add_Click({
    $comboCategories.SelectedIndex = 0
    $comboLanguages.SelectedIndex = 0
    $textBoxKeywords.Text = ''
    Update-ProjectList -Clear
})

$buttonSearch.Add_Click({
    $selectedCategory = $comboCategories.SelectedItem
    $selectedLanguage = $comboLanguages.SelectedItem
    $keywords = $textBoxKeywords.Text
    Update-ProjectList -SelectedCategory $selectedCategory -SelectedLanguage $selectedLanguage -KeywordsPattern $keywords -Clear
})

$textBoxKeywords.Add_TextChanged({
    $selectedCategory = $comboCategories.SelectedItem
    $selectedLanguage = $comboLanguages.SelectedItem
    $keywords = $textBoxKeywords.Text
    Update-ProjectList -SelectedCategory $selectedCategory -SelectedLanguage $selectedLanguage -KeywordsPattern $keywords -Clear
})

$comboCategories.Add_SelectedIndexChanged({
    $selectedCategory = $comboCategories.SelectedItem
    $selectedLanguage = $comboLanguages.SelectedItem
    $keywords = $textBoxKeywords.Text
    Update-ProjectList -SelectedCategory $selectedCategory -SelectedLanguage $selectedLanguage -KeywordsPattern $keywords -Clear
})

$comboLanguages.Add_SelectedIndexChanged({
    $selectedCategory = $comboCategories.SelectedItem
    $selectedLanguage = $comboLanguages.SelectedItem
    $keywords = $textBoxKeywords.Text
    Update-ProjectList -SelectedCategory $selectedCategory -SelectedLanguage $selectedLanguage -KeywordsPattern $keywords -Clear
})


$buttonImportDir.Add_Click({
    if ($listBoxDirs.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("The directory list is empty. Nothing to import.", "Info", 'OK', 'Information')
        return
    }
    $index = $listBoxDirs.SelectedIndex
    if ($index -ge 0) {
        $NewPath = $listBoxDirs.Items[$index]
        Write-Verbose "Import-ProjectFilesToDatabase -Path `"$NewPath`""
        try {
            Import-ProjectFilesToDatabase -Path "$NewPath"
            # Refresh the cache and reload the projects
            $global:allProjectsCache = Get-ProjectListFromDatabase
            Update-ProjectList -SelectedCategory $comboCategories.SelectedItem `
                          -SelectedLanguage $comboLanguages.SelectedItem `
                          -KeywordsPattern $textBoxKeywords.Text -Clear
            [System.Windows.Forms.MessageBox]::Show("Import completed and project list refreshed for: $NewPath", "Import Done", 'OK', 'Information')
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error during import: $($_.Exception.Message)", "Error", 'OK', 'Error')
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a directory from the list to import.", "No Selection", 'OK', 'Warning')
    }
})


$buttonResetAll.Add_Click({
    $listViewProjects.Items.Clear()

    Remove-AllProjectsFromDatabase
    if ($listBoxDirs.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("The directory list is empty. Nothing to import.", "Info", 'OK', 'Information')
        return
    }

    # Collect all paths into a string array
    $paths = @()
    foreach ($item in $listBoxDirs.Items) {
        $paths += $item.ToString()
    }

    Write-Verbose "Importing projects from paths: $($paths -join ', ')"

    try {
        Import-ProjectFilesToDatabase -Path $paths
        # Refresh the cache and reload the projects
        $global:allProjectsCache = Get-ProjectListFromDatabase
        Update-ProjectList -SelectedCategory $comboCategories.SelectedItem `
                      -SelectedLanguage $comboLanguages.SelectedItem `
                      -KeywordsPattern $textBoxKeywords.Text
        [System.Windows.Forms.MessageBox]::Show("Import completed and project list refreshed.", "Import Done", 'OK', 'Information')
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error during import: $($_.Exception.Message)", "Error", 'OK', 'Error')
    }
})

$form.Add_FormClosing({
    Save-ProjectDirList -Directories ($listBoxDirs.Items)
})

# --- Context Menu ---
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemOpenUrl = New-Object System.Windows.Forms.ToolStripMenuItem "Open Project Url"
$menuItemOpenFolder = New-Object System.Windows.Forms.ToolStripMenuItem "Open Containing Folder"
$contextMenu.Items.AddRange(@($menuItemOpenUrl, $menuItemOpenFolder))
$listViewProjects.ContextMenuStrip = $contextMenu

$menuItemOpenUrl.Add_Click({
    if ($listViewProjects.SelectedItems.Count -gt 0) {
        $selectedItem = $listViewProjects.SelectedItems[0]
        $proj = $selectedItem.Tag
        if ($proj.Permalink) {
            Start-Process "cmd.exe" "/c start $($proj.Permalink)"
        } else {
            [System.Windows.Forms.MessageBox]::Show("No Permalink available.", "Info")
        }
    }
})

$menuItemOpenFolder.Add_Click({
    if ($listViewProjects.SelectedItems.Count -gt 0) {
        $selectedItem = $listViewProjects.SelectedItems[0]
        $proj = $selectedItem.Tag
        $FilePath = $proj.FilePath
        if (!([string]::IsNullOrEmpty($FilePath))) {
            $Exists = Test-Path -Path "$FilePath" -PathType Leaf
            if ($Exists) {
                $folderPath = (Get-Item "$FilePath").DirectoryName
                Start-Process "explorer.exe" $folderPath
            } else {
                [System.Windows.Forms.MessageBox]::Show("File not found: $FilePath", "Error")
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("No FilePath available.", "Info")
        }
    }
})

$listViewProjects.Add_DoubleClick({
    if ($listViewProjects.SelectedItems.Count -gt 0) {
        $selectedItem = $listViewProjects.SelectedItems[0]
        $proj = $selectedItem.Tag
        $filePath = $proj.FilePath

        if ([string]::IsNullOrWhiteSpace($filePath)) {
            [System.Windows.Forms.MessageBox]::Show("No FilePath available for this project.", "Error", 'OK', 'Error')
            return
        }

        if (!(Test-Path -Path $filePath -PathType Leaf)) {
            [System.Windows.Forms.MessageBox]::Show("Project file not found: $filePath", "Error", 'OK', 'Error')
            return
        }

        try {
            $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
            Show-ObjectTree $jsonContent 
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load or parse the project JSON: $($_.Exception.Message)", "Error", 'OK', 'Error')
        }
    }
})


# === Splash Screen ===
# === Splash Screen ===
$splash = New-Object System.Windows.Forms.Form
$splash.FormBorderStyle = 'None'
$splash.StartPosition = 'CenterScreen'
$splash.Size = New-Object System.Drawing.Size(400, 200)
$splash.BackColor = 'DarkGray'

$ImgSplash = "$PSScriptRoot\splash.png"
# ✅ Set background image
$splash.BackgroundImage = [System.Drawing.Image]::FromFile($ImgSplash)
$splash.BackgroundImageLayout = 'Stretch'   # Options: None, Tile, Center, Zoom, Stretch


# Add a label for App name
$labelAppName = New-Object System.Windows.Forms.Label
$labelAppName.Text = "Project Browser"
$labelAppName.BackColor = [System.Drawing.Color]::Transparent
$labelAppName.ForeColor = [System.Drawing.Color]::White   # ✅ White text
$labelAppName.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$labelAppName.AutoSize = $true
$labelAppName.Location = New-Object System.Drawing.Point(100, 50)

$labelCopyrightSplash = New-Object System.Windows.Forms.Label
$labelCopyrightSplash.Text = "© Guillaume Plante 2024"
$labelCopyrightSplash.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$labelCopyrightSplash.ForeColor = [System.Drawing.Color]::White   # ✅ White text
$labelCopyrightSplash.BackColor = [System.Drawing.Color]::Transparent
$labelCopyrightSplash.AutoSize = $true
$labelCopyrightSplash.Location = New-Object System.Drawing.Point(10, 170)


# Add controls to splash screen
$splash.Controls.Add($labelAppName)
$splash.Controls.Add($labelCopyrightSplash)


# Show splash non-blocking
$splash.TopMost = $true
$splash.Show()

# Wait a bit (simulate loading)
Start-Sleep -Milliseconds 1500

# Close splash
$splash.Close()

# --- Initial Load ---
Update-ProjectList
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
