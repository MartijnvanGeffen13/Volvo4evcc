$script:ModuleRoot = $PSScriptRoot

foreach ($File in (Get-ChildItem "$PSScriptRoot\scripts" -Recurse -Filter *.ps1)) {
	. $File.FullName
}

foreach ($File in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -Filter *.ps1)) {
	. $File.FullName
}

foreach ($File in (Get-ChildItem "$PSScriptRoot\internal" -Recurse -Filter *.ps1)) {
	. $File.FullName
}