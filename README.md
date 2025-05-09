<p align="center">
  <img src="img/banner.png" alt="Banner" style="max-width: 100%;">
</p>

This Tool is Database driven program to list and search projects based on languages, categories, keywords, etc...

Create a a ```project.nfo``` file:

```powershell
New-ProjectDataFile `
    -Title "mseek - process scanner" `
    -Summary "memory search tool for strings and regular expressions" `
    -Author "guillaume plante" `
    -Category "general" `
    -Date (Get-Date '2020-10-16') `
    -Languages @("c++", "powershell") `
    -Keywords @("memory", "scan") `
    -Permalink "https://github.com/arsscriptum/mseek" `
    -Thumbnail "https://github.com/arsscriptum/mseek/raw/refs/heads/mseek_stable/img/banner_s.png" 
```

Outputs:

```powershell

{
  "Title": "mseek - process scanner",
  "Summary": "memory search tool for strings and regular expressions",
  "Author": "guillaume plante",
  "Date": "2020-10-16T00:00:00",
  "Category": "general",
  "Languages": [
    "c++",
    "powershell"
  ],
  "Keywords": [
    "memory",
    "scan"
  ],
  "Permalink": "https://github.com/arsscriptum/mseek",
  "Thumbnail": "https://github.com/arsscriptum/mseek/raw/refs/heads/mseek_stable/img/banner_s.png"
}


```

so

```powershell
New-ProjectDataFile `
    -Title "mseek - process scanner" `
    -Summary "memory search tool for strings and regular expressions" `
    -Author "guillaume plante" `
    -Category "general" `
    -Date (Get-Date '2020-10-16') `
    -Languages @("c++", "powershell") `
    -Keywords @("memory", "scan") `
    -Permalink "https://github.com/arsscriptum/mseek" `
    -Thumbnail "https://github.com/arsscriptum/mseek/raw/refs/heads/mseek_stable/img/banner_s.png" | Set-Content "project.nfo"
```
