# Import common module
$ErrorActionPreference = 'Stop'
Import-Module $PSScriptRoot/ktsu-build-common.ps1

# Configure git
Set-GitUserConfig

# Commit metadata files
git add VERSION.md LICENSE.md AUTHORS.md COPYRIGHT.md CHANGELOG.md PROJECT_URL.url AUTHORS.url
git commit -m "[bot][skip ci] Update Metadata"
git push

# Get and set release hash
$RELEASE_HASH = (git rev-parse HEAD)
Write-Host "RELEASE_HASH: $RELEASE_HASH"
Set-GithubEnv -Name "RELEASE_HASH" -Value $RELEASE_HASH
