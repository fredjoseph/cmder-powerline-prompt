#
# Theme
#
Import-Module oh-my-posh
$ThemeSettings.MyThemesLocation = "$PSScriptRoot/themes"
Set-Theme My-Agnoster
# Hide 'username@domain' in prompt
$DefaultUser = $env:USERNAME

[ScriptBlock]$Prompt = $function:prompt


#
# Aliases
#
Set-Alias ls Get-ChildItemColor -option AllScope -Force


#
# Enhancements
#
## Unload modules that slow down autocomplete
Remove-Module PackageManagement -Force

## Load unix tool as for 'cmder:cmd'
if(Test-Path env:GIT_INSTALL_ROOT) {
    $env:Path += $(";" + $env:GIT_INSTALL_ROOT + "\usr\bin")
}
