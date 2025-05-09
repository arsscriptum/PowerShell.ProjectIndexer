[CmdletBinding(SupportsShouldProcess = $true)]
param ()

$CommonScript = "$PSScriptRoot\Common.ps1"
. "$CommonScript"

$DatabaseScript = "$PSScriptRoot\Database.ps1"
. "$DatabaseScript"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load data from DB
$categories = Get-CategoryListFromDatabase | Select-Object -ExpandProperty Name
$languages = Get-LanguageListFromDatabase | Select-Object -ExpandProperty Name

# Add 'ALL' option
$categoriesList = @('ALL') + $categories
$languagesList = @('ALL') + $languages

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Project Browser"
$form.Size = New-Object System.Drawing.Size(1000, 700)
$form.StartPosition = "CenterScreen"

# === Search GroupBox ===
$groupBoxSearch = New-Object System.Windows.Forms.GroupBox
$groupBoxSearch.Text = "Search"
$groupBoxSearch.Size = New-Object System.Drawing.Size(940, 180)
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

# Add Columns
$listViewProjects.Columns.Add("Title", 120)
$listViewProjects.Columns.Add("Summary", 200)
$listViewProjects.Columns.Add("Author", 100)
$listViewProjects.Columns.Add("Date", 80)
$listViewProjects.Columns.Add("Permalink", 150)
$listViewProjects.Columns.Add("Categories", 100)
$listViewProjects.Columns.Add("Languages", 100)
$listViewProjects.Columns.Add("Keywords", 100)

# Add ListView to Projects GroupBox
$groupBoxProjects.Controls.Add($listViewProjects)

# === Add groupboxes to Form ===
$form.Controls.Add($groupBoxSearch)
$form.Controls.Add($groupBoxProjects)

# --- Cache all projects once ---
$allProjectsCache = Get-ProjectListFromDatabase

# --- Function: Load Projects ---
function Load-Projects {
    param (
        [string]$SelectedCategory = 'ALL',
        [string]$SelectedLanguage = 'ALL',
        [string]$KeywordsPattern = ''
    )

    $listViewProjects.Items.Clear()

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
        $item.Tag = $proj
        $listViewProjects.Items.Add($item)
    }
    Write-Verbose "[Load-Projects] $($proj.Summary) $($proj.FilePath)"
}

# --- Button Handlers ---

$buttonReset.Add_Click({
    $comboCategories.SelectedIndex = 0
    $comboLanguages.SelectedIndex = 0
    $textBoxKeywords.Text = ''
    Load-Projects  # Reload all
})

$buttonSearch.Add_Click({
    $selectedCategory = $comboCategories.SelectedItem
    $selectedLanguage = $comboLanguages.SelectedItem
    $keywords = $textBoxKeywords.Text
    Load-Projects -SelectedCategory $selectedCategory -SelectedLanguage $selectedLanguage -KeywordsPattern $keywords
})

# --- Realtime Filtering on Keyword Change ---
$textBoxKeywords.Add_TextChanged({
    $selectedCategory = $comboCategories.SelectedItem
    $selectedLanguage = $comboLanguages.SelectedItem
    $keywords = $textBoxKeywords.Text
    Load-Projects -SelectedCategory $selectedCategory -SelectedLanguage $selectedLanguage -KeywordsPattern $keywords
})

# --- Context Menu ---
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuItemOpenUrl = New-Object System.Windows.Forms.ToolStripMenuItem "Open Project Url"
$menuItemOpenFolder = New-Object System.Windows.Forms.ToolStripMenuItem "Open Containing Folder"

# Add to context menu
$contextMenu.Items.AddRange(@($menuItemOpenUrl, $menuItemOpenFolder))

# Assign context menu to listview
$listViewProjects.ContextMenuStrip = $contextMenu

# Context menu event handlers

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

# --- Initial Load ---
Load-Projects

# Show Form
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
