param (
    [Parameter(Mandatory, Position=0)]
    [string]$github_sha = "" # SHA of the commit
)

# Import common module
$ErrorActionPreference = 'Stop'
Import-Module $PSScriptRoot/ktsu-build-common.ps1

# Initialize git configuration
Initialize-GitConfig

# Find the last version that was released
$ALL_TAGS = Get-GitTags
$LAST_TAG = $ALL_TAGS[0]

Write-Host "Last tag: $LAST_TAG"

$LAST_VERSION = $LAST_TAG -replace 'v', ''
Write-Host "Last version: $LAST_VERSION"

$IS_PRERELEASE = $LAST_VERSION.Contains('-')

$LAST_VERSION = $LAST_VERSION -replace '-alpha', ''
$LAST_VERSION = $LAST_VERSION -replace '-beta', ''
$LAST_VERSION = $LAST_VERSION -replace '-rc', ''
$LAST_VERSION = $LAST_VERSION -replace '-pre', ''

Write-Host "Cleaned version: $LAST_VERSION"

$LAST_VERSION_COMPONENTS = $LAST_VERSION -split '\.'
$LAST_VERSION_MAJOR = [int]$LAST_VERSION_COMPONENTS[0]
$LAST_VERSION_MINOR = [int]$LAST_VERSION_COMPONENTS[1]
$LAST_VERSION_PATCH = [int]$LAST_VERSION_COMPONENTS[2]
$LAST_VERSION_PRERELEASE = 0
if ($LAST_VERSION_COMPONENTS.Length -gt 3) {
    $LAST_VERSION_PRERELEASE = [int]$LAST_VERSION_COMPONENTS[3]
}

# Calculate version increment
$FIRST_COMMIT = (git rev-list HEAD)[-1]
$LAST_COMMIT = $github_sha
$COMMITS = "$FIRST_COMMIT...$LAST_COMMIT"

$VERSION_INCREMENT = Get-VersionType -Range $COMMITS

# Calculate new version
if ($IS_PRERELEASE) {
    if ($VERSION_INCREMENT -eq 'prerelease') {
        $NEW_PRERELEASE = $LAST_VERSION_PRERELEASE + 1
        $VERSION = "$LAST_VERSION_MAJOR.$LAST_VERSION_MINOR.$LAST_VERSION_PATCH-pre.$NEW_PRERELEASE"
    } elseif ($VERSION_INCREMENT -eq 'patch') {
        $VERSION = "$LAST_VERSION_MAJOR.$LAST_VERSION_MINOR.$LAST_VERSION_PATCH"
    }
} else {
    if ($VERSION_INCREMENT -eq 'prerelease') {
        $NEW_PATCH = $LAST_VERSION_PATCH + 1
        $VERSION = "$LAST_VERSION_MAJOR.$LAST_VERSION_MINOR.$NEW_PATCH-pre.1"
    } elseif ($VERSION_INCREMENT -eq 'patch') {
        $NEW_PATCH = $LAST_VERSION_PATCH + 1
        $VERSION = "$LAST_VERSION_MAJOR.$LAST_VERSION_MINOR.$NEW_PATCH"
    }
}

if ($VERSION_INCREMENT -eq 'minor') {
    $NEW_MINOR = $LAST_VERSION_MINOR + 1
    $VERSION = "$LAST_VERSION_MAJOR.$NEW_MINOR.0"
} elseif ($VERSION_INCREMENT -eq 'major') {
    $NEW_MAJOR = $LAST_VERSION_MAJOR + 1
    $VERSION = "$NEW_MAJOR.0.0"
}

# Output version information
Write-Host "LAST_VERSION: $LAST_VERSION"
Write-Host "LAST_VERSION_MAJOR: $LAST_VERSION_MAJOR"
Write-Host "LAST_VERSION_MINOR: $LAST_VERSION_MINOR"
Write-Host "LAST_VERSION_PATCH: $LAST_VERSION_PATCH"
Write-Host "LAST_VERSION_PRERELEASE: $LAST_VERSION_PRERELEASE"
Write-Host "IS_PRERELEASE: $IS_PRERELEASE"
Write-Host "FIRST_COMMIT: $FIRST_COMMIT"
Write-Host "LAST_COMMIT: $LAST_COMMIT"
Write-Host "VERSION_INCREMENT: $VERSION_INCREMENT"
Write-Host "VERSION: $VERSION"

# Set environment variables
Set-GithubEnv -Name "LAST_VERSION" -Value $LAST_VERSION
Set-GithubEnv -Name "LAST_VERSION_MAJOR" -Value $LAST_VERSION_MAJOR
Set-GithubEnv -Name "LAST_VERSION_MINOR" -Value $LAST_VERSION_MINOR
Set-GithubEnv -Name "LAST_VERSION_PATCH" -Value $LAST_VERSION_PATCH
Set-GithubEnv -Name "LAST_VERSION_PRERELEASE" -Value $LAST_VERSION_PRERELEASE
Set-GithubEnv -Name "IS_PRERELEASE" -Value $IS_PRERELEASE
Set-GithubEnv -Name "FIRST_COMMIT" -Value $FIRST_COMMIT
Set-GithubEnv -Name "LAST_COMMIT" -Value $LAST_COMMIT
Set-GithubEnv -Name "VERSION_INCREMENT" -Value $VERSION_INCREMENT
Set-GithubEnv -Name "VERSION" -Value $VERSION

# Write version file
Write-VersionFile -Version $VERSION

$global:LASTEXITCODE = 0
