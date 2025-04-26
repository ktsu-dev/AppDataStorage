# Common constants and functions for version management scripts

# Git command patterns
$script:EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
$script:EXCLUDE_PRS = @'
^.*(Merge pull request|Merge branch 'main'|Updated packages in|Update.*package version).*$
'@

$script:EXCLUDE_PATTERNS = @{
    'Hidden' = ":(icase,exclude)*/.*"
    'Markdown' = ":(icase,exclude)*/*.md"
    'Text' = ":(icase,exclude)*/*.txt"
    'Solutions' = ":(icase,exclude)*/*.sln"
    'Projects' = ":(icase,exclude)*/*.*proj"
    'Url' = ":(icase,exclude)*/*.url"
    'Build' = ":(icase,exclude)*/Directory.Build.*"
    'CI' = ":(icase,exclude).github/workflows/*"
    'PowerShell' = ":(icase,exclude)*/*.ps1"
}

function Initialize-GitConfig {
    git config versionsort.suffix "-alpha"
    git config versionsort.suffix "-beta"
    git config versionsort.suffix "-rc"
    git config versionsort.suffix "-pre"
}

function Set-GitUserConfig {
    git config --global user.name "Github Actions"
    git config --global user.email "actions@users.noreply.github.com"
}

function Get-GitTags {
    $tags = git tag --list --sort=-v:refname
    if ($null -eq $tags) {
        return @('v1.0.0-pre.0')
    }
    return $tags
}

function Get-NonMergeCommits {
    param (
        [Parameter(Mandatory)]
        [string]$Range
    )

    $commits = git log --date-order --perl-regexp --regexp-ignore-case --grep="$script:EXCLUDE_PRS" --invert-grep --committer="$script:EXCLUDE_BOTS" --author="$script:EXCLUDE_BOTS" $Range
    return $commits
}

function Get-CodeChanges {
    param (
        [Parameter(Mandatory)]
        [string]$Range
    )

    $excludePatterns = $script:EXCLUDE_PATTERNS.Values -join ' '
    $changes = git log --topo-order --perl-regexp --regexp-ignore-case --format=format:%H --committer="$script:EXCLUDE_BOTS" --author="$script:EXCLUDE_BOTS" --grep="$script:EXCLUDE_PRS" --invert-grep $Range -- '*/*.*' $excludePatterns
    return $changes
}

function Get-CommitMessages {
    param (
        [Parameter(Mandatory)]
        [string]$Range
    )

    $messages = git log --format=format:%s $Range
    return $messages
}

function Get-VersionType {
    param (
        [Parameter(Mandatory)]
        [string]$Range
    )

    $versionType = "prerelease"

    $allCommits = Get-NonMergeCommits -Range $Range
    if ($allCommits) {
        $versionType = "patch"
    }

    $codeChanges = Get-CodeChanges -Range $Range
    if ($codeChanges) {
        $versionType = "minor"
    }

    $messages = Get-CommitMessages -Range $Range
    foreach ($message in $messages) {
        if ($message.Contains('[major]')) {
            return 'major'
        } elseif ($message.Contains('[minor]') -and $versionType -ne 'major') {
            $versionType = 'minor'
        } elseif ($message.Contains('[patch]') -and $versionType -notin @('major', 'minor')) {
            $versionType = 'patch'
        } elseif ($message.Contains('[pre]') -and $versionType -notin @('major', 'minor', 'patch')) {
            $versionType = 'prerelease'
        }
    }

    return $versionType
}

function Set-GithubEnv {
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value
    )

    "$Name=$Value" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
}

function Write-VersionFile {
    param (
        [Parameter(Mandatory)]
        [string]$Version
    )

    $Version | Out-File -FilePath VERSION.md -Encoding utf8
}

function Write-MetadataFiles {
    param (
        [Parameter(Mandatory)]
        [string]$Authors,
        [Parameter(Mandatory)]
        [string]$Copyright,
        [Parameter(Mandatory)]
        [string]$ProjectUrl,
        [Parameter(Mandatory)]
        [string]$AuthorsUrl,
        [Parameter(Mandatory)]
        [string]$License
    )

    $Authors | Out-File -FilePath AUTHORS.md -Encoding utf8
    $Copyright | Out-File -FilePath COPYRIGHT.md -Encoding utf8
    $ProjectUrl | Out-File -FilePath PROJECT_URL.url -Encoding utf8
    $AuthorsUrl | Out-File -FilePath AUTHORS.url -Encoding utf8
    $License | Out-File -FilePath LICENSE.md -Encoding utf8
}

function Write-ChangelogFile {
    param (
        [Parameter(Mandatory)]
        [string]$Changelog
    )

    $Changelog | Out-File -FilePath CHANGELOG.md -Encoding utf8
}

# Set error action preference
$ErrorActionPreference = 'Stop'

# Export functions
Export-ModuleMember -Function *
Export-ModuleMember -Variable EXCLUDE_*
