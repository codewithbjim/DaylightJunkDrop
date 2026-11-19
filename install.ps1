# Copies the addon into the game's AddOns folder for testing: only the addon's own
# files (no .git, .github or this script), with the version filled in from git.
$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
$dst = "F:\Battle.net\World of Warcraft\_forever_\Interface\AddOns\DaylightJunkDrop"

$version = (git -C $src describe --tags --always 2>$null)
if (-not $version) { $version = "dev" }

New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem $dst -File | Remove-Item -Force
foreach ($f in "DaylightJunkDrop.toc", "JunkDrop.lua", "Bindings.xml", "icon.png", "README.md", "CHANGELOG.md", "LICENSE") {
    Copy-Item (Join-Path $src $f) $dst
}

$toc = Join-Path $dst "DaylightJunkDrop.toc"
$text = [IO.File]::ReadAllText($toc).Replace("@project-version@", $version)
[IO.File]::WriteAllText($toc, $text, (New-Object Text.UTF8Encoding $false))
Write-Host "Installed DaylightJunkDrop $version to $dst"
