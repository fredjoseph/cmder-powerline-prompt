;= @echo off
;= rem Call DOSKEY and use this file as the macrofile
;= %SystemRoot%\system32\doskey /listsize=1000 /macrofile=%0%
;= rem In batch mode, jump to the end of the file
;= goto:eof
;= Add aliases below here
e.=explorer .
gl=git log --oneline --all --graph --decorate  $*
ls=ls --show-control-chars -F --color $*
pwd=cd
clear=cls
history=cat "%CMDER_ROOT%\config\.history"
unalias=alias /d $1
vi=vim $*
cmderr=cd /d "%CMDER_ROOT%"
..=cd ..
~=cd %HOMEPATH%
ll=ls -gohlat --show-control-chars -F --color $*
treeall=tree /a /f
scoopimport=powershell "Get-Content $* | sls '(.+) \(' |% { $_.matches.groups[1].value } |% {scoop install $_}" rem installs previously exported scoop apps
gpa=%GIT_INSTALL_ROOT%/usr/bin/find . -mindepth 1 -maxdepth 1 -type d -execdir test -d '{}/.git' ; -exec echo -e "\n{}" ; -exec git --git-dir="{}"/.git --work-tree="{}" pull ;
gsa=%GIT_INSTALL_ROOT%/usr/bin/find . -mindepth 1 -maxdepth 1 -type d -execdir test -d '{}/.git' ; -exec echo -e "\n{}" ; -exec git --git-dir="{}"/.git --work-tree="{}" status ;
toFR=curl "https://de.pons.com/_translate/translate" --data "source_language=en&target_language=fr&service=deepl&text=""$*""&lookup=true&requested_by=Web&source_language_confirmed=true" | jq .translation
toEN=curl "https://de.pons.com/_translate/translate" --data "source_language=fr&target_language=en&service=deepl&text=""$*""&lookup=true&requested_by=Web&source_language_confirmed=true" | jq .translation
