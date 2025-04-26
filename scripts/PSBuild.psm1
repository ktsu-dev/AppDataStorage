# PSBuild Module for .NET CI/CD
# Version: 1.0.0
# Author: ktsu.dev
# License: MIT
#
# A comprehensive PowerShell module for automating the build, test, package,
# and release process for .NET applications using Git-based versioning.
#
# Usage:
#   Import-Module ./PSBuild.psm1
#   $result = Invoke-CIPipeline -GitRef "refs/heads/main" -GitSha "abc123" -WorkspacePath "." -ServerUrl "https://github.com" -Owner "myorg" -Repository "myrepo" -GithubToken $env:GITHUB_TOKEN

#region Module Variables
$script:DOTNET_VERSION = '9.0'
$script:LICENSE_TEMPLATE = Join-Path $PSScriptRoot "LICENSE.template"
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
#endregion

#region Environment and Configuration

function Initialize-BuildEnvironment {
    <#
    .SYNOPSIS
        Initializes the build environment with standard settings.
    .DESCRIPTION
        Sets up environment variables for .NET SDK and initializes other required build settings.
    #>
    [CmdletBinding()]
    param()

    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    $env:DOTNET_NOLOGO = 'true'

    Write-Output "Build environment initialized"
}

function Get-BuildConfiguration {
    <#
    .SYNOPSIS
        Gets the build configuration based on Git status and environment.
    .DESCRIPTION
        Determines if this is a release build, checks Git status, and sets up build paths.
    .PARAMETER GitRef
        The Git reference (branch/tag) being built.
    .PARAMETER GitSha
        The Git commit SHA being built.
    .PARAMETER WorkspacePath
        The path to the workspace/repository root.
    .PARAMETER GithubToken
        Optional GitHub token for API operations.
    .PARAMETER ExpectedOwner
        The expected owner/organization of the official repository.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$GitRef,
        [Parameter(Mandatory=$true)]
        [string]$GitSha,
        [Parameter(Mandatory=$true)]
        [string]$WorkspacePath,
        [string]$GithubToken,
        [string]$ExpectedOwner = "ktsu-dev"
    )

    # Determine if this is an official repo (verify owner and ensure it's not a fork)
    $IS_OFFICIAL = $false
    if ($GithubToken) {
        $env:GH_TOKEN = $GithubToken
        $repoInfo = gh repo view --json owner,nameWithOwner,isFork | ConvertFrom-Json
        Assert-LastExitCode "Failed to retrieve repository information"

        # Consider it official only if it's not a fork AND belongs to the expected owner
        $IS_OFFICIAL = (-not $repoInfo.isFork) -and ($repoInfo.owner.login -eq $ExpectedOwner)

        Write-Verbose "Repository: $($repoInfo.nameWithOwner), Is Fork: $($repoInfo.isFork), Owner: $($repoInfo.owner.login)"
        Write-Verbose "Is Official: $IS_OFFICIAL"
    }

    # Determine if this is main branch and not tagged
    $IS_MAIN = $GitRef -eq "refs/heads/main"
    $IS_TAGGED = (git show-ref --tags -d | Out-String).Contains($GitSha)
    $SHOULD_RELEASE = ($IS_MAIN -AND -NOT $IS_TAGGED -AND $IS_OFFICIAL)

    # Check for .csx files (dotnet-script)
    $csx = @(Get-ChildItem -Path $WorkspacePath -Recurse -Filter *.csx -ErrorAction SilentlyContinue)
    $USE_DOTNET_SCRIPT = $csx.Count -gt 0

    # Setup paths
    $OUTPUT_PATH = Join-Path $WorkspacePath 'output'
    $STAGING_PATH = Join-Path $WorkspacePath 'staging'

    # Setup artifact patterns
    $PACKAGE_PATTERN = Join-Path $STAGING_PATH "*.nupkg"
    $SYMBOLS_PATTERN = Join-Path $STAGING_PATH "*.snupkg"
    $APPLICATION_PATTERN = Join-Path $STAGING_PATH "*.zip"

    # Set build arguments
    $BUILD_ARGS = $USE_DOTNET_SCRIPT ? "-maxCpuCount:1" : ""

    # Create configuration object
    $config = [PSCustomObject]@{
        IsOfficial = $IS_OFFICIAL
        IsMain = $IS_MAIN
        IsTagged = $IS_TAGGED
        ShouldRelease = $SHOULD_RELEASE
        UseDotnetScript = $USE_DOTNET_SCRIPT
        OutputPath = $OUTPUT_PATH
        StagingPath = $STAGING_PATH
        PackagePattern = $PACKAGE_PATTERN
        SymbolsPattern = $SYMBOLS_PATTERN
        ApplicationPattern = $APPLICATION_PATTERN
        BuildArgs = $BUILD_ARGS
        WorkspacePath = $WorkspacePath
        DotnetVersion = $script:DOTNET_VERSION
    }

    # Display configuration details
    Write-Host "Build Configuration:" -ForegroundColor Cyan
    Write-Host "  Repository Status:" -ForegroundColor Yellow
    Write-Host "    Is Official Repo: $($config.IsOfficial)"
    Write-Host "    Is Main Branch:  $($config.IsMain)"
    Write-Host "    Is Tagged:       $($config.IsTagged)"
    Write-Host "    Should Release:  $($config.ShouldRelease)"
    Write-Host ""
    Write-Host "  Build Settings:" -ForegroundColor Yellow
    Write-Host "    .NET Version:    $($config.DotnetVersion)"
    Write-Host "    Uses Script:     $($config.UseDotnetScript)"
    Write-Host "    Build Args:      $($config.BuildArgs)"
    Write-Host ""
    Write-Host "  Paths:" -ForegroundColor Yellow
    Write-Host "    Workspace:       $($config.WorkspacePath)"
    Write-Host "    Output:          $($config.OutputPath)"
    Write-Host "    Staging:         $($config.StagingPath)"
    Write-Host ""
    Write-Host "  Artifact Patterns:" -ForegroundColor Yellow
    Write-Host "    Packages:        $($config.PackagePattern)"
    Write-Host "    Symbols:         $($config.SymbolsPattern)"
    Write-Host "    Applications:    $($config.ApplicationPattern)"
    Write-Host ""

    return $config
}

#endregion

#region Version Management

function Get-GitTags {
    <#
    .SYNOPSIS
        Gets all git tags sorted by version, with the most recent first.
    .DESCRIPTION
        Retrieves a sorted list of git tags, handling versioning suffixes correctly.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    # Configure git to properly sort version tags with suffixes
    git config versionsort.suffix "-alpha"
    git config versionsort.suffix "-beta"
    git config versionsort.suffix "-rc"
    git config versionsort.suffix "-pre"

    # Get tags and ensure we return an array
    $tags = @(git tag --list --sort=-v:refname)

    # Return default if no tags exist
    if ($null -eq $tags -or $tags.Count -eq 0) {
        return @('v1.0.0-pre.0')
    }

    return $tags
}

function Get-VersionType {
    <#
    .SYNOPSIS
        Determines the type of version bump needed based on commit history
    .DESCRIPTION
        Analyzes commit messages and changes to determine whether the next version should be a major, minor, patch, or prerelease bump.
    .PARAMETER Range
        The git commit range to analyze (e.g., "v1.0.0...HEAD" or a specific commit range)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Range
    )

    Write-StepHeader "Analyzing Version Changes"
    Write-Host "Analyzing commits for version increment decision..."

    # Initialize to the most conservative version bump
    $versionType = "prerelease"
    $reason = "No significant changes detected"

    # Bot and PR patterns to exclude
    $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
    $EXCLUDE_PRS = '^.*(Merge pull request|Merge branch ''main''|Updated packages in|Update.*package version).*$'

    # Check for non-merge commits
    $allCommits = git log --date-order --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $Range
    if ($allCommits) {
        $versionType = "patch"
        $reason = "Found non-merge commits requiring at least a patch version"
        Write-Host "Found non-merge commits - minimum patch version required" -ForegroundColor Yellow
    }

    # Check for code changes (excluding documentation, config files, etc.)
    $EXCLUDE_PATTERNS = @(
        ":(icase,exclude)*/*.*md"
        ":(icase,exclude)*/*.txt"
        ":(icase,exclude)*/*.sln"
        ":(icase,exclude)*/*.*proj"
        ":(icase,exclude)*/*.url"
        ":(icase,exclude)*/Directory.Build.*"
        ":(icase,exclude).github/workflows/*"
        ":(icase,exclude)*/*.ps1"
    )
    $excludeString = $EXCLUDE_PATTERNS -join ' '
    $codeChanges = git log --topo-order --perl-regexp --regexp-ignore-case --format=format:%H --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" --grep="$EXCLUDE_PRS" --invert-grep $Range -- '*/*.*' $excludeString
    if ($codeChanges) {
        $versionType = "minor"
        $reason = "Found code changes requiring at least a minor version"
        Write-Host "Found code changes - minimum minor version required" -ForegroundColor Yellow
    }

    # Look for explicit version bump annotations in commit messages
    $messages = git log --format=format:%s $Range
    foreach ($message in $messages) {
        if ($message.Contains('[major]')) {
            Write-Host "Found [major] tag in commit: $message" -ForegroundColor Red
            return @{
                Type = 'major'
                Reason = "Explicit [major] tag found in commit message: $message"
            }
        }
        elseif ($message.Contains('[minor]') -and $versionType -ne 'major') {
            Write-Host "Found [minor] tag in commit: $message" -ForegroundColor Yellow
            $versionType = 'minor'
            $reason = "Explicit [minor] tag found in commit message: $message"
        }
        elseif ($message.Contains('[patch]') -and $versionType -notin @('major', 'minor')) {
            Write-Host "Found [patch] tag in commit: $message" -ForegroundColor Green
            $versionType = 'patch'
            $reason = "Explicit [patch] tag found in commit message: $message"
        }
        elseif ($message.Contains('[pre]') -and $versionType -notin @('major', 'minor', 'patch')) {
            Write-Host "Found [pre] tag in commit: $message" -ForegroundColor Blue
            $versionType = 'prerelease'
            $reason = "Explicit [pre] tag found in commit message: $message"
        }
    }

    return @{
        Type = $versionType
        Reason = $reason
    }
}

function Get-VersionInfoFromGit {
    <#
    .SYNOPSIS
        Gets comprehensive version information based on Git tags and commit analysis.
    .DESCRIPTION
        Finds the most recent version tag, analyzes commit history, and determines the next version
        following semantic versioning principles. Returns a rich object with all version components.
    .PARAMETER CommitHash
        The Git commit hash being built.
    .PARAMETER InitialVersion
        The version to use if no tags exist. Defaults to "1.0.0".
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$CommitHash,
        [string]$InitialVersion = "1.0.0"
    )

    Write-StepHeader "Analyzing Version Information"
    Write-Host "Analyzing repository for version information..."

    # Get tag information
    $allTags = Get-GitTags
    $noTagsExist = ($null -eq $allTags) -or
                   (($allTags -is [string]) -and $allTags -eq 'v1.0.0-pre.0') -or
                   (($allTags -is [array]) -and $allTags.Count -eq 1 -and $allTags[0] -eq 'v1.0.0-pre.0')

    if ($noTagsExist) {
        # Special case: This is the first version, no real tags exist yet
        Write-Host "No existing version tags found - using initial version: $InitialVersion" -ForegroundColor Yellow

        return [PSCustomObject]@{
            # New version information
            Version = $InitialVersion
            Major = [int]($InitialVersion -split '\.')[0]
            Minor = [int]($InitialVersion -split '\.')[1]
            Patch = [int]($InitialVersion -split '\.')[2]
            IsPrerelease = $false
            PrereleaseNumber = 0
            PrereleaseLabel = ""

            # Previous version information
            LastTag = ""
            LastVersion = ""
            LastVersionMajor = 0
            LastVersionMinor = 0
            LastVersionPatch = 0
            WasPrerelease = $false
            LastVersionPrereleaseNumber = 0

            # Git and version increment information
            VersionIncrement = "initial"
            IncrementReason = "First version"
            FirstCommit = $CommitHash
            LastCommit = $CommitHash
        }
    }

    $lastTag = $allTags[0]
    $lastVersion = $lastTag -replace 'v', ''
    Write-Host "Last version tag: $lastTag" -ForegroundColor Cyan

    # Parse previous version
    $wasPrerelease = $lastVersion.Contains('-')
    $cleanVersion = $lastVersion -replace '-alpha.*$', '' -replace '-beta.*$', '' -replace '-rc.*$', '' -replace '-pre.*$', ''

    $parts = $cleanVersion -split '\.'
    $lastMajor = [int]$parts[0]
    $lastMinor = [int]$parts[1]
    $lastPatch = [int]$parts[2]
    $lastPrereleaseNum = 0

    # Extract prerelease number if applicable
    if ($wasPrerelease -and $lastVersion -match '-(?:pre|alpha|beta|rc)\.(\d+)') {
        $lastPrereleaseNum = [int]$Matches[1]
    }

    # Determine version increment type
    $firstCommit = (git rev-list HEAD)[-1]
    $commitRange = "$firstCommit...$CommitHash"
    $incrementInfo = Get-VersionType -Range $commitRange
    $incrementType = $incrementInfo.Type
    $incrementReason = $incrementInfo.Reason

    # Initialize new version with current values
    $newMajor = $lastMajor
    $newMinor = $lastMinor
    $newPatch = $lastPatch
    $newPrereleaseNum = 0
    $isPrerelease = $false
    $prereleaseLabel = "pre"

    Write-Host "`nCalculating new version..." -ForegroundColor Cyan

    # Calculate new version based on increment type
    switch ($incrementType) {
        'major' {
            $newMajor = $lastMajor + 1
            $newMinor = 0
            $newPatch = 0
            Write-Host "Incrementing major version: $lastMajor.$lastMinor.$lastPatch -> $newMajor.0.0" -ForegroundColor Red
        }
        'minor' {
            $newMinor = $lastMinor + 1
            $newPatch = 0
            Write-Host "Incrementing minor version: $lastMajor.$lastMinor.$lastPatch -> $lastMajor.$newMinor.0" -ForegroundColor Yellow
        }
        'patch' {
            if (-not $wasPrerelease) {
                $newPatch = $lastPatch + 1
                Write-Host "Incrementing patch version: $lastMajor.$lastMinor.$lastPatch -> $lastMajor.$lastMinor.$newPatch" -ForegroundColor Green
            } else {
                Write-Host "Converting prerelease to stable version: $lastVersion -> $lastMajor.$lastMinor.$lastPatch" -ForegroundColor Green
            }
        }
        'prerelease' {
            if ($wasPrerelease) {
                # Bump prerelease number
                $newPrereleaseNum = $lastPrereleaseNum + 1
                $isPrerelease = $true
                Write-Host "Incrementing prerelease: $lastVersion -> $lastMajor.$lastMinor.$lastPatch-$prereleaseLabel.$newPrereleaseNum" -ForegroundColor Blue
            } else {
                # Start new prerelease series
                $newPatch = $lastPatch + 1
                $newPrereleaseNum = 1
                $isPrerelease = $true
                Write-Host "Starting new prerelease: $lastVersion -> $lastMajor.$lastMinor.$newPatch-$prereleaseLabel.1" -ForegroundColor Blue
            }
        }
    }

    # Build version string
    $newVersion = "$newMajor.$newMinor.$newPatch"
    if ($isPrerelease) {
        $newVersion += "-$prereleaseLabel.$newPrereleaseNum"
    }

    Write-Host "`nVersion decision:" -ForegroundColor Cyan
    Write-Host "Previous version: $lastVersion" -ForegroundColor Gray
    Write-Host "New version    : $newVersion" -ForegroundColor White
    Write-Host "Reason        : $incrementReason" -ForegroundColor Gray

    # Return comprehensive object
    return [PSCustomObject]@{
        # New version information
        Version = $newVersion
        Major = $newMajor
        Minor = $newMinor
        Patch = $newPatch
        IsPrerelease = $isPrerelease
        PrereleaseNumber = $newPrereleaseNum
        PrereleaseLabel = $prereleaseLabel

        # Previous version information
        LastTag = $lastTag
        LastVersion = $lastVersion
        LastVersionMajor = $lastMajor
        LastVersionMinor = $lastMinor
        LastVersionPatch = $lastPatch
        WasPrerelease = $wasPrerelease
        LastVersionPrereleaseNumber = $lastPrereleaseNum

        # Git and version increment information
        VersionIncrement = $incrementType
        IncrementReason = $incrementReason
        FirstCommit = $firstCommit
        LastCommit = $CommitHash
    }
}

function New-Version {
    <#
    .SYNOPSIS
        Creates a new version file and sets environment variables.
    .DESCRIPTION
        Generates a new version number based on git history, writes it to version files,
        and optionally sets GitHub environment variables for use in Actions.
    .PARAMETER CommitHash
        The Git commit hash being built.
    .PARAMETER OutputPath
        Optional path to write the version file to. Defaults to workspace root.
    .PARAMETER SetGitHubEnv
        Whether to set GitHub environment variables. Defaults to $true.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$CommitHash,
        [string]$OutputPath = "",
        [bool]$SetGitHubEnv = $true
    )

    # Get complete version information object
    $versionInfo = Get-VersionInfoFromGit -CommitHash $CommitHash

    # Write version file
    $filePath = if ($OutputPath) { Join-Path $OutputPath "VERSION.md" } else { "VERSION.md" }
    $versionInfo.Version | Out-File -FilePath $filePath -Encoding utf8 -NoNewline

    # Set GitHub environment variables if needed
    if ($SetGitHubEnv -and $env:GITHUB_ENV) {
        "VERSION=$($versionInfo.Version)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "LAST_VERSION=$($versionInfo.LastVersion)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "LAST_VERSION_MAJOR=$($versionInfo.LastVersionMajor)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "LAST_VERSION_MINOR=$($versionInfo.LastVersionMinor)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "LAST_VERSION_PATCH=$($versionInfo.LastVersionPatch)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "LAST_VERSION_PRERELEASE=$($versionInfo.LastVersionPrereleaseNumber)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "IS_PRERELEASE=$($versionInfo.IsPrerelease)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "VERSION_INCREMENT=$($versionInfo.VersionIncrement)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "FIRST_COMMIT=$($versionInfo.FirstCommit)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
        "LAST_COMMIT=$($versionInfo.LastCommit)" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }

    Write-Verbose "Previous version: $($versionInfo.LastVersion), New version: $($versionInfo.Version)"
    Write-Output "Version $($versionInfo.Version) generated"
    return $versionInfo.Version
}

#endregion

#region License Management

function New-License {
    <#
    .SYNOPSIS
        Creates a license file from template.
    .DESCRIPTION
        Generates a LICENSE.md file using the template and repository information.
    .PARAMETER ServerUrl
        The GitHub server URL.
    .PARAMETER Owner
        The repository owner/organization.
    .PARAMETER Repository
        The repository name.
    .PARAMETER OutputPath
        Optional path to write the license file to. Defaults to workspace root.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerUrl,
        [Parameter(Mandatory=$true)]
        [string]$Owner,
        [Parameter(Mandatory=$true)]
        [string]$Repository,
        [string]$OutputPath = ""
    )

    if (-not (Test-Path $script:LICENSE_TEMPLATE)) {
        throw "License template not found at: $script:LICENSE_TEMPLATE"
    }

    $year = (Get-Date).Year
    $content = Get-Content $script:LICENSE_TEMPLATE -Raw

    # Project URL
    $projectUrl = "$ServerUrl/$Owner/$Repository"
    $content = $content.Replace('{PROJECT_URL}', $projectUrl)

    # Copyright line
    $copyright = "Copyright (c) 2023-$year $Owner"
    $content = $content.Replace('{COPYRIGHT}', $copyright)

    $copyrightFilePath = if ($OutputPath) { Join-Path $OutputPath "COPYRIGHT.md" } else { "COPYRIGHT.md" }
    $copyright | Out-File -FilePath $copyrightFilePath -Encoding utf8

    $filePath = if ($OutputPath) { Join-Path $OutputPath "LICENSE.md" } else { "LICENSE.md" }
    $content | Out-File -FilePath $filePath -Encoding utf8

    Write-Output "License file generated"
}

#endregion

#region Changelog Management

function ConvertTo-FourComponentVersion {
    <#
    .SYNOPSIS
        Converts a version tag to a four-component version for comparison.
    .DESCRIPTION
        Standardizes version tags to a four-component version (major.minor.patch.prerelease) for easier comparison.
    .PARAMETER VersionTag
        The version tag to convert.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$VersionTag
    )

    $version = $VersionTag -replace 'v', ''
    $version = $version -replace '-alpha', '' -replace '-beta', '' -replace '-rc', '' -replace '-pre', ''
    $versionComponents = $version -split '\.'
    $versionMajor = [int]$versionComponents[0]
    $versionMinor = [int]$versionComponents[1]
    $versionPatch = [int]$versionComponents[2]
    $versionPrerelease = 0

    if ($versionComponents.Length -gt 3) {
        $versionPrerelease = [int]$versionComponents[3]
    }

    return "$versionMajor.$versionMinor.$versionPatch.$versionPrerelease"
}

function Get-VersionNotes {
    <#
    .SYNOPSIS
        Generates changelog notes for a specific version range.
    .DESCRIPTION
        Creates formatted changelog entries for commits between two version tags.
    .PARAMETER Tags
        All available tags in the repository.
    .PARAMETER FromTag
        The starting tag of the range.
    .PARAMETER ToTag
        The ending tag of the range.
    .PARAMETER ToSha
        Optional specific commit SHA to use as the range end.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [string[]]$Tags,
        [Parameter(Mandatory=$true)]
        [string]$FromTag,
        [Parameter(Mandatory=$true)]
        [string]$ToTag,
        [Parameter()]
        [string]$ToSha = ""
    )

    # Convert tags to comparable versions
    $toVersion = ConvertTo-FourComponentVersion -VersionTag $ToTag
    $fromVersion = ConvertTo-FourComponentVersion -VersionTag $FromTag

    # Parse components for comparison
    $toVersionComponents = $toVersion -split '\.'
    $toVersionMajor = [int]$toVersionComponents[0]
    $toVersionMinor = [int]$toVersionComponents[1]
    $toVersionPatch = [int]$toVersionComponents[2]
    $toVersionPrerelease = [int]$toVersionComponents[3]

    $fromVersionComponents = $fromVersion -split '\.'
    $fromVersionMajor = [int]$fromVersionComponents[0]
    $fromVersionMinor = [int]$fromVersionComponents[1]
    $fromVersionPatch = [int]$fromVersionComponents[2]
    $fromVersionPrerelease = [int]$fromVersionComponents[3]

    # Calculate previous version numbers for finding the correct tag
    $fromMajorVersionNumber = $toVersionMajor - 1
    $fromMinorVersionNumber = $toVersionMinor - 1
    $fromPatchVersionNumber = $toVersionPatch - 1
    $fromPrereleaseVersionNumber = $toVersionPrerelease - 1

    # Determine version type and search tag
    $searchTag = $FromTag
    $versionType = "unknown"

    if ($toVersionPrerelease -ne 0) {
        $versionType = "prerelease"
        $searchTag = "$toVersionMajor.$toVersionMinor.$toVersionPatch.$fromPrereleaseVersionNumber"
    }
    else {
        if ($toVersionPatch -gt $fromVersionPatch) {
            $versionType = "patch"
            $searchTag = "$toVersionMajor.$toVersionMinor.$fromPatchVersionNumber.0"
        }
        if ($toVersionMinor -gt $fromVersionMinor) {
            $versionType = "minor"
            $searchTag = "$toVersionMajor.$fromMinorVersionNumber.0.0"
        }
        if ($toVersionMajor -gt $fromVersionMajor) {
            $versionType = "major"
            $searchTag = "$fromMajorVersionNumber.0.0.0"
        }
    }

    # Handle case where version is same but prerelease was dropped
    if ($toVersionMajor -eq $fromVersionMajor -and
        $toVersionMinor -eq $fromVersionMinor -and
        $toVersionPatch -eq $fromVersionPatch -and
        $toVersionPrerelease -eq 0 -and
        $fromVersionPrerelease -ne 0) {
        $versionType = "patch"
        $searchTag = "$toVersionMajor.$toVersionMinor.$fromPatchVersionNumber.0"
    }

    # Clean up search tag if it has prerelease component
    if ($searchTag.Contains("-")) {
        $searchTag = $FromTag
    }

    # Convert search tag to comparable format
    $searchVersion = ConvertTo-FourComponentVersion -VersionTag $searchTag

    # Find matching tag in repository
    if ($FromTag -ne "v0.0.0") {
        $foundSearchTag = $false
        foreach ($tag in $Tags) {
            if (-not $foundSearchTag) {
                $otherVersion = ConvertTo-FourComponentVersion -VersionTag $tag
                if ($searchVersion -eq $otherVersion) {
                    $foundSearchTag = $true
                    $searchTag = $tag
                }
            }
        }

        if (-not $foundSearchTag) {
            $searchTag = $FromTag
        }
    }

    # Determine range for git log
    $rangeFrom = $searchTag
    if ($rangeFrom -eq "v0.0.0" -or $rangeFrom -eq "0.0.0.0" -or $rangeFrom -eq "1.0.0.0") {
        $rangeFrom = ""
    }

    $rangeTo = $ToSha
    if ([string]::IsNullOrEmpty($rangeTo)) {
        $rangeTo = $ToTag
    }

    $range = $rangeTo
    if ($rangeFrom -ne "") {
        $range = "$rangeFrom...$rangeTo"
    }

    # Determine actual version type based on commit content
    if ($versionType -ne "prerelease") {
        $versionType = Get-VersionType -Range $range
    }

    # Exclude patterns for commit authors and messages
    $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
    $EXCLUDE_PRS = '^.*(Merge pull request|Merge branch ''main''|Updated packages in|Update.*package version).*$'

    # Get commit messages with authors
    $commits = git log --pretty=format:"%s ([@%aN](https://github.com/%aN))" --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $range | Sort-Object | Get-Unique

    # Format changelog entry
    $versionChangelog = ""
    if ($versionType -ne "prerelease" -and $commits.Length -gt 0) {
        $versionChangelog = "## $ToTag ($versionType)`n`n"
        $versionChangelog += "Changes since ${searchTag}:`n`n"

        foreach ($commit in $commits) {
            # Filter out version updates and skip CI commits
            if (-not $commit.Contains("Update VERSION to") -and -not $commit.Contains("[skip ci]")) {
                $versionChangelog += "- $commit`n"
            }
        }
        $versionChangelog += "`n"
    }

    return $versionChangelog
}

function New-Changelog {
    <#
    .SYNOPSIS
        Creates a complete changelog file.
    .DESCRIPTION
        Generates a comprehensive CHANGELOG.md with entries for all versions.
    .PARAMETER Version
        The current version number being released.
    .PARAMETER CommitHash
        The Git commit hash being released.
    .PARAMETER OutputPath
        Optional path to write the changelog file to. Defaults to workspace root.
    .PARAMETER IncludeAllVersions
        Whether to include all previous versions in the changelog. Defaults to $true.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [string]$CommitHash,
        [string]$OutputPath = "",
        [bool]$IncludeAllVersions = $true
    )

    # Get all tags
    $tags = Get-GitTags
    $changelog = ""
    $tagIndex = 0

    # Add entry for current/new version
    $previousTag = if ($null -eq $tags -or
                      ($tags -is [string]) -or
                      (($tags -is [array]) -and $tags.Length -eq 0)) {
        'v0.0.0'
    } else {
        if ($tags -is [array]) {
            $tags[0]
        } else {
            $tags
        }
    }

    $currentTag = "v$Version"
    $changelog += Get-VersionNotes -Tags $tags -FromTag $previousTag -ToTag $currentTag -ToSha $CommitHash

    # Add entries for all previous versions if requested
    if ($IncludeAllVersions) {
        foreach ($tag in $tags) {
            if ($tag -like "v*") {
                $previousTag = "v0.0.0"
                if ($tagIndex -lt $tags.Length - 1) {
                    $previousTag = $tags[$tagIndex + 1]
                }

                if (-not ($previousTag -like "v*")) {
                    $previousTag = "v0.0.0"
                }

                $changelog += Get-VersionNotes -Tags $tags -FromTag $previousTag -ToTag $tag
            }
            $tagIndex++
        }
    }

    # Write changelog to file
    $filePath = if ($OutputPath) { Join-Path $OutputPath "CHANGELOG.md" } else { "CHANGELOG.md" }
    $changelog | Out-File -FilePath $filePath -Encoding utf8

    Write-Output "Changelog generated with entries for $($tags.Length + 1) versions"
    return $changelog
}

#endregion

#region Metadata Management

function Update-ProjectMetadata {
    <#
    .SYNOPSIS
        Updates and commits project metadata files.
    .DESCRIPTION
        Updates VERSION.md, LICENSE.md, AUTHORS.md, COPYRIGHT.md, CHANGELOG.md and other
        metadata files, commits them to git, and optionally pushes the changes.
        Note: Existing AUTHORS.md file will always be preserved if it exists.
    .PARAMETER Version
        The version number for the release.
    .PARAMETER CommitHash
        The Git commit hash being released.
    .PARAMETER GitHubOwner
        The GitHub repository owner/organization.
    .PARAMETER GitHubRepo
        The GitHub repository name.
    .PARAMETER Authors
        Optional list of authors. If not provided, will be pulled from git history.
    .PARAMETER CommitMessage
        Optional custom commit message for the metadata update.
    .PARAMETER Push
        Whether to push the changes to the remote repository.
    .PARAMETER SetGitHubEnv
        Whether to set GitHub environment variables for the release hash.
    .PARAMETER ServerUrl
        The GitHub server URL. Defaults to "https://github.com".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [string]$CommitHash,
        [Parameter(Mandatory=$true)]
        [string]$GitHubOwner,
        [Parameter(Mandatory=$true)]
        [string]$GitHubRepo,
        [string[]]$Authors,
        [string]$CommitMessage = "[bot][skip ci] Update Metadata",
        [bool]$Push = $true,
        [bool]$SetGitHubEnv = $true,
        [string]$ServerUrl = "https://github.com"
    )

    # Configure git user for GitHub Actions
    git config --global user.name "Github Actions"
    git config --global user.email "actions@users.noreply.github.com"

    # 1. Version file - always update
    $Version | Out-File -FilePath "VERSION.md" -Encoding utf8 -NoNewline
    Write-Host "Generated VERSION.md file"

    # 2. License file - always update
    New-License -ServerUrl $ServerUrl -Owner $GitHubOwner -Repository $GitHubRepo
    Write-Host "Generated LICENSE.md file"

    # 3. Generate AUTHORS.md only if it doesn't already exist
    if (-not (Test-Path "AUTHORS.md")) {
        if (-not $Authors -or $Authors.Count -eq 0) {
            $Authors = git log --format="%aN" | Sort-Object -Unique
        }
        $authorsList = $Authors -join "`n"
        $authorsList | Out-File -FilePath "AUTHORS.md" -Encoding utf8
        Write-Host "Generated AUTHORS.md file"
    } else {
        Write-Host "Preserving existing AUTHORS.md file"
    }

    # 4. URL files - always generate
    "$ServerUrl/$GitHubOwner/$GitHubRepo" | Out-File -FilePath "PROJECT_URL.url" -Encoding utf8
    Write-Host "Generated PROJECT_URL.url file"

    "$ServerUrl/$GitHubOwner" | Out-File -FilePath "AUTHORS.url" -Encoding utf8
    Write-Host "Generated AUTHORS.url file"

    # 5. Always generate CHANGELOG.md
    New-Changelog -Version $Version -CommitHash $CommitHash
    Write-Host "Generated CHANGELOG.md file"

    # Add all metadata files to git (will only add files that exist)
    $filesToAdd = @(
        "VERSION.md",
        "LICENSE.md",
        "AUTHORS.md",
        "CHANGELOG.md",
        "PROJECT_URL.url",
        "AUTHORS.url"
    ) | Where-Object { Test-Path $_ }

    if ($filesToAdd.Count -gt 0) {
        git add $filesToAdd
        git commit -m $CommitMessage
    } else {
        Write-Warning "No metadata files to commit"
    }

    # Push changes if requested
    if ($Push) {
        git push
    }

    # Get and set release hash
    $releaseHash = git rev-parse HEAD
    Write-Output "Metadata committed as $releaseHash"

    # Set GitHub environment variable if requested
    if ($SetGitHubEnv -and $env:GITHUB_ENV) {
        "RELEASE_HASH=$releaseHash" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }

    return $releaseHash
}

#endregion

#region Build Operations

function Invoke-DotNetRestore {
    <#
    .SYNOPSIS
        Restores NuGet packages.
    .DESCRIPTION
        Runs dotnet restore to get all dependencies.
    #>
    [CmdletBinding()]
    param()

    Write-StepHeader "Restoring Dependencies"

    $cmd = "dotnet restore --locked-mode /p:ConsoleLoggerParameters=""Verbosity=Normal"""
    Write-Host "Running: $cmd"

    # Execute command and stream output directly to console
    & dotnet restore --locked-mode /p:ConsoleLoggerParameters="Verbosity=Normal" | ForEach-Object {
        Write-Host $_
    }
    Assert-LastExitCode "Restore failed" -Command $cmd
}

function Invoke-DotNetBuild {
    <#
    .SYNOPSIS
        Builds the .NET solution.
    .DESCRIPTION
        Runs dotnet build with specified configuration.
    .PARAMETER Configuration
        The build configuration (Debug/Release).
    .PARAMETER BuildArgs
        Additional build arguments.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [string]$BuildArgs = ""
    )

    Write-StepHeader "Building Solution"

    # Add explicit logger parameters for better CI output
    $loggerParams = '-logger:console --consoleLoggerParameters:NoSummary=true;ForceNoAlign=true;ShowTimestamp=true;ShowCommandLine=true;Verbosity=normal --nologo'
    $cmd = "dotnet build --configuration $Configuration $loggerParams --no-incremental $BuildArgs --no-restore"
    Write-Host "Running: $cmd"

    try {
        # First attempt with normal verbosity - stream output directly
        & dotnet build --configuration $Configuration -logger:console --consoleLoggerParameters:NoSummary=true;ForceNoAlign=true;ShowTimestamp=true;ShowCommandLine=true;Verbosity=normal --nologo --no-incremental $BuildArgs --no-restore | ForEach-Object {
            Write-Host $_
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Build failed with exit code $LASTEXITCODE. Retrying with detailed verbosity..."

            # Retry with more detailed verbosity - stream output directly
            & dotnet build --configuration $Configuration -logger:console --consoleLoggerParameters:NoSummary=true;ForceNoAlign=true;ShowTimestamp=true;ShowCommandLine=true;Verbosity=detailed --nologo --no-incremental $BuildArgs --no-restore | ForEach-Object {
                Write-Host $_
            }

            # Still failed, show diagnostic info and throw error
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Checking for common build issues:" -ForegroundColor Yellow

                # Check for project files
                $projectFiles = @(Get-ChildItem -Recurse -Filter *.csproj)
                Write-Host "Found $($projectFiles.Count) project files" -ForegroundColor Cyan

                foreach ($proj in $projectFiles) {
                    Write-Host "  - $($proj.FullName)" -ForegroundColor Cyan
                }

                Assert-LastExitCode "Build failed" -Command $cmd
            }
        }
    }
    catch {
        Write-Error "Exception during build process: $_"
        throw
    }
}

function Invoke-DotNetTest {
    <#
    .SYNOPSIS
        Runs unit tests.
    .DESCRIPTION
        Runs dotnet test with code coverage collection.
    .PARAMETER Configuration
        The build configuration (Debug/Release).
    .PARAMETER CoverageOutputPath
        The path to output code coverage results.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [string]$CoverageOutputPath = "coverage"
    )

    Write-StepHeader "Running Tests"

    $cmd = "dotnet test -m:1 --configuration $Configuration -logger:console --consoleLoggerParameters:NoSummary=true;ForceNoAlign=true;ShowTimestamp=true;ShowCommandLine=true;Verbosity=normal --nologo --no-build --collect:""XPlat Code Coverage"" --results-directory $CoverageOutputPath"
    Write-Host "Running: $cmd"

    # Execute command and stream output directly to console
    & dotnet test -m:1 --configuration $Configuration -logger:console --consoleLoggerParameters:NoSummary=true;ForceNoAlign=true;ShowTimestamp=true;ShowCommandLine=true;Verbosity=normal --nologo --no-build --collect:"XPlat Code Coverage" --results-directory $CoverageOutputPath | ForEach-Object {
        Write-Host $_
    }
    Assert-LastExitCode "Tests failed" -Command $cmd
}

function Invoke-DotNetPack {
    <#
    .SYNOPSIS
        Creates NuGet packages.
    .DESCRIPTION
        Runs dotnet pack to create NuGet packages.
    .PARAMETER Configuration
        The build configuration (Debug/Release).
    .PARAMETER OutputPath
        The path to output packages to.
    .PARAMETER Verbosity
        The verbosity level for dotnet commands. Defaults to "normal".
    .PARAMETER Project
        Optional specific project to package. If not provided, all projects are packaged.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [string]$Verbosity = "normal",
        [string]$Project = ""
    )

    Write-StepHeader "Packaging Libraries"

    # Ensure output directory exists
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

    # Check if any projects exist
    $projectFiles = @(Get-ChildItem -Recurse -Filter *.csproj -ErrorAction SilentlyContinue)
    if ($projectFiles.Count -eq 0) {
        Write-Host "No .NET library projects found to package"
        return
    }

    try {
        # Build either a specific project or all projects
        if ([string]::IsNullOrWhiteSpace($Project)) {
            Write-Host "Packaging all projects in solution..."
            & dotnet pack --configuration $Configuration /p:ConsoleLoggerParameters="NoSummary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=$Verbosity" --nologo --no-build --output $OutputPath | ForEach-Object {
                Write-Host $_
            }
        } else {
            Write-Host "Packaging project: $Project"
            & dotnet pack $Project --configuration $Configuration /p:ConsoleLoggerParameters="NoSummary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=$Verbosity" --nologo --no-build --output $OutputPath | ForEach-Object {
                Write-Host $_
            }
        }

        if ($LASTEXITCODE -ne 0) {
            # Get more details about what might have failed
            Write-Error "Packaging failed with exit code $LASTEXITCODE, trying again with detailed verbosity..."
            & dotnet pack --configuration $Configuration /p:ConsoleLoggerParameters="NoSummary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=detailed" --nologo --no-build --output $OutputPath | ForEach-Object {
                Write-Host $_
            }
            throw "Library packaging failed with exit code $LASTEXITCODE"
        }

        # Report on created packages
        $packages = @(Get-ChildItem -Path $OutputPath -Filter *.nupkg -ErrorAction SilentlyContinue)
        if ($packages.Count -gt 0) {
            Write-Host "Created $($packages.Count) packages in $OutputPath"
            foreach ($package in $packages) {
                Write-Host "  - $($package.Name)"
            }
        } else {
            Write-Host "No packages were created (projects may not be configured for packaging)"
        }
    }
    catch {
        $originalException = $_.Exception
        Write-Error "Package creation failed: $originalException"
        throw "Library packaging failed: $originalException"
    }
}

function Invoke-DotNetPublish {
    <#
    .SYNOPSIS
        Publishes .NET applications.
    .DESCRIPTION
        Runs dotnet publish and creates zip archives for applications.
    .PARAMETER Configuration
        The build configuration (Debug/Release).
    .PARAMETER OutputPath
        The path to output applications to.
    .PARAMETER StagingPath
        The path to stage zip files in.
    .PARAMETER Version
        The version number for the zip files.
    .PARAMETER DotnetVersion
        The .NET version to target.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [Parameter(Mandatory=$true)]
        [string]$StagingPath,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$DotnetVersion = ""
    )

    if (-not $DotnetVersion) {
        $DotnetVersion = $script:DOTNET_VERSION
    }

    Write-StepHeader "Publishing Applications"

    # Find all projects
    $projectFiles = @(Get-ChildItem -Recurse -Filter *.csproj -ErrorAction SilentlyContinue)
    if ($projectFiles.Count -eq 0) {
        Write-Host "No .NET application projects found to publish"
        return
    }

    # Clean output directory if it exists
    if (Test-Path $OutputPath) {
        Remove-Item -Recurse -Force $OutputPath
    }

    # Ensure staging directory exists
    New-Item -Path $StagingPath -ItemType Directory -Force | Out-Null

    $publishedCount = 0
    foreach ($csproj in $projectFiles) {
        $projName = [System.IO.Path]::GetFileNameWithoutExtension($csproj)
        $outDir = Join-Path $OutputPath $projName
        $stageFile = Join-Path $StagingPath "$projName-$Version.zip"

        Write-Host "Publishing $projName..."

        # Create output directory
        New-Item -Path $outDir -ItemType Directory -Force | Out-Null

        # Publish application - stream output directly
        & dotnet publish $csproj --no-build --configuration $Configuration --framework net$DotnetVersion --output $outDir /p:ConsoleLoggerParameters="NoSummary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=normal" --nologo | ForEach-Object {
            Write-Host $_
        }

        if ($LASTEXITCODE -eq 0) {
            # Create zip archive
            Compress-Archive -Path "$outDir/*" -DestinationPath $stageFile -Force
            $publishedCount++
            Write-Host "Successfully published and archived $projName"
        } else {
            Write-Host "Skipping $projName (not configured as an executable project)"
            continue
        }
    }

    if ($publishedCount -gt 0) {
        Write-Host "Published $publishedCount application(s)"
    } else {
        Write-Host "No applications were published (projects may not be configured as executables)"
    }
}

#endregion

#region Publishing and Release

function Invoke-NuGetPublish {
    <#
    .SYNOPSIS
        Publishes NuGet packages.
    .DESCRIPTION
        Publishes packages to GitHub Packages and/or NuGet.org.
    .PARAMETER PackagePattern
        The glob pattern to find packages.
    .PARAMETER GithubToken
        The GitHub token for authentication.
    .PARAMETER GithubOwner
        The GitHub owner/organization.
    .PARAMETER NuGetApiKey
        Optional NuGet.org API key.
    .PARAMETER SkipGithub
        Skip publishing to GitHub Packages.
    .PARAMETER SkipNuGet
        Skip publishing to NuGet.org.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$PackagePattern,
        [Parameter(Mandatory=$true)]
        [string]$GithubToken,
        [Parameter(Mandatory=$true)]
        [string]$GithubOwner,
        [string]$NuGetApiKey,
        [switch]$SkipGithub,
        [switch]$SkipNuGet
    )

    # Check if there are any packages to publish
    $packages = @(Get-Item -Path $PackagePattern -ErrorAction SilentlyContinue)
    if ($packages.Count -eq 0) {
        Write-Host "No packages found to publish"
        return
    }

    Write-Host "Found $($packages.Count) package(s) to publish"

    # Publish to GitHub Packages if enabled
    if (-not $SkipGithub) {
        Write-StepHeader "Publishing to GitHub Packages"

        # Display the command being run (without revealing the token)
        Write-Host "Running: dotnet nuget push $PackagePattern --source https://nuget.pkg.github.com/$GithubOwner/index.json --skip-duplicate"

        # Execute the command and stream output
        & dotnet nuget push $PackagePattern --api-key $GithubToken --source "https://nuget.pkg.github.com/$GithubOwner/index.json" --skip-duplicate | ForEach-Object {
            Write-Host $_
        }
        Assert-LastExitCode "GitHub package publish failed"
    }

    # Publish to NuGet.org if enabled and key provided
    if (-not $SkipNuGet -and $NuGetApiKey) {
        Write-StepHeader "Publishing to NuGet.org"

        # Display the command being run (without revealing the API key)
        Write-Host "Running: dotnet nuget push $PackagePattern --source https://api.nuget.org/v3/index.json --skip-duplicate"

        # Execute the command and stream output
        & dotnet nuget push $PackagePattern --api-key $NuGetApiKey --source "https://api.nuget.org/v3/index.json" --skip-duplicate | ForEach-Object {
            Write-Host $_
        }
        Assert-LastExitCode "NuGet.org package publish failed"
    }
}

function New-GitHubRelease {
    <#
    .SYNOPSIS
        Creates a GitHub release.
    .DESCRIPTION
        Creates a GitHub release with assets and notes.
    .PARAMETER Version
        The version number for the release.
    .PARAMETER CommitHash
        The Git commit hash to tag.
    .PARAMETER GithubToken
        The GitHub token for authentication.
    .PARAMETER ChangelogFile
        The path to the changelog file.
    .PARAMETER AssetPatterns
        Array of glob patterns for assets to include.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CommitHash,
        [Parameter(Mandatory=$true)]
        [string]$GithubToken,
        [string]$ChangelogFile = "CHANGELOG.md",
        [string[]]$AssetPatterns = @()
    )

    # Set GitHub token for CLI
    $env:GH_TOKEN = $GithubToken

    # Collect all assets
    $assets = @()
    foreach ($pattern in $AssetPatterns) {
        $matched = Get-Item -Path $pattern -ErrorAction SilentlyContinue
        if ($matched) {
            $assets += $matched.FullName
        }
    }

    # Build asset arguments
    $assetArgs = @()
    foreach ($asset in $assets) {
        $assetArgs += "--assets"
        $assetArgs += $asset
    }

    # Create release
    Write-StepHeader "Creating GitHub Release v$Version"

    $releaseArgs = @(
        "release",
        "create",
        "v$Version",
        "--target", $CommitHash.ToString(),
        "--generate-notes"
    )

    # Handle changelog content if file exists
    if (Test-Path $ChangelogFile) {
        Write-Host "Using changelog from $ChangelogFile"
        $releaseArgs += "--notes-file"
        $releaseArgs += $ChangelogFile
    }

    $releaseArgs += $assetArgs

    Write-Host "Running: gh $($releaseArgs -join ' ')"
    & gh @releaseArgs
    Assert-LastExitCode "Failed to create GitHub release"
}

#endregion

#region Git Operations

# Note: The Save-Metadata function has been removed as its functionality
# is now handled by the more comprehensive Update-ProjectMetadata function

#endregion

#region Utility Functions

function Assert-LastExitCode {
    <#
    .SYNOPSIS
        Verifies that the last command executed successfully.
    .DESCRIPTION
        Throws an exception if the last command execution resulted in a non-zero exit code.
        This function is used internally to ensure each step completes successfully.
    .PARAMETER Message
        The error message to display if the exit code check fails.
    .PARAMETER Command
        Optional. The command that was executed, for better error reporting.
    .EXAMPLE
        dotnet build
        Assert-LastExitCode "The build process failed" -Command "dotnet build"
    .NOTES
        Author: ktsu.dev
    #>
    [CmdletBinding()]
    param (
        [string]$Message = "Command failed",
        [string]$Command = ""
    )

    if ($LASTEXITCODE -ne 0) {
        $errorDetails = "Exit code: $LASTEXITCODE"
        if (-not [string]::IsNullOrWhiteSpace($Command)) {
            $errorDetails += " | Command: $Command"
        }

        $fullMessage = "$Message`n$errorDetails"
        Write-Error $fullMessage
        throw $fullMessage
    }
}

function Write-StepHeader {
    <#
    .SYNOPSIS
        Writes a formatted step header to the console.
    .DESCRIPTION
        Creates a visually distinct header for build steps in the console output.
        Used to improve readability of the build process logs.
    .PARAMETER Message
        The header message to display.
    .EXAMPLE
        Write-StepHeader "Restoring Packages"
    .NOTES
        Author: ktsu.dev
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Host "`n=== $Message ===`n" -ForegroundColor Cyan
}

function Test-AnyFiles {
    <#
    .SYNOPSIS
        Tests if any files match the specified pattern.
    .DESCRIPTION
        Tests if any files exist that match the given glob pattern. This is useful for
        determining if certain file types (like packages) exist before attempting operations
        on them.
    .PARAMETER Pattern
        The glob pattern to check for matching files.
    .EXAMPLE
        if (Test-AnyFiles -Pattern "*.nupkg") {
            Write-Host "NuGet packages found!"
        }
    .NOTES
        Author: ktsu.dev
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )

    # Use array subexpression to ensure consistent collection handling
    $matchingFiles = @(Get-Item -Path $Pattern -ErrorAction SilentlyContinue)
    return $matchingFiles.Count -gt 0
}

#endregion

#region High-Level Workflows

function Invoke-BuildWorkflow {
    <#
    .SYNOPSIS
        Executes the main build workflow.
    .DESCRIPTION
        Runs the complete build, test, and package process.
    .PARAMETER Configuration
        The build configuration (Debug/Release).
    .PARAMETER BuildArgs
        Additional build arguments.
    .PARAMETER BuildConfig
        The build configuration object from Get-BuildConfiguration.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [string]$BuildArgs = "",
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfig
    )

    try {
        # Setup
        Initialize-BuildEnvironment

        # Install dotnet-script if needed
        if ($BuildConfig.UseDotnetScript) {
            Write-StepHeader "Installing dotnet-script"
            dotnet tool install -g dotnet-script
            Assert-LastExitCode "Failed to install dotnet-script"
        }

        # Build and Test
        Invoke-DotNetRestore
        Invoke-DotNetBuild -Configuration $Configuration -BuildArgs $BuildArgs
        Invoke-DotNetTest -Configuration $Configuration -CoverageOutputPath "coverage"

        return $true
    }
    catch {
        Write-Error "Build workflow failed: $_"
        return $false
    }
}

function Invoke-ReleaseWorkflow {
    <#
    .SYNOPSIS
        Executes the release workflow.
    .DESCRIPTION
        Generates metadata, packages, and creates a release.
    .PARAMETER GitSha
        The Git commit SHA being released.
    .PARAMETER ServerUrl
        The GitHub server URL.
    .PARAMETER Owner
        The repository owner/organization.
    .PARAMETER Repository
        The repository name.
    .PARAMETER Configuration
        The build configuration (Debug/Release).
    .PARAMETER BuildConfig
        The build configuration object from Get-BuildConfiguration.
    .PARAMETER GithubToken
        The GitHub token for authentication.
    .PARAMETER NuGetApiKey
        Optional NuGet.org API key.
    .PARAMETER SkipPackages
        If set to true, skips NuGet package generation and publishing. Default is false.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$GitSha,
        [Parameter(Mandatory=$true)]
        [string]$ServerUrl,
        [Parameter(Mandatory=$true)]
        [string]$Owner,
        [Parameter(Mandatory=$true)]
        [string]$Repository,
        [string]$Configuration = "Release",
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfig,
        [Parameter(Mandatory=$true)]
        [string]$GithubToken,
        [string]$NuGetApiKey,
        [switch]$SkipPackages = $false
    )

    try {
        Write-StepHeader "Starting Release Process"

        # Generate Metadata
        Write-StepHeader "Generating Version Information"
        $versionInfo = Get-VersionInfoFromGit -CommitHash $GitSha.ToString()

        # Update and commit all metadata files
        Write-StepHeader "Updating Metadata Files"
        $releaseHash = Update-ProjectMetadata -Version $versionInfo.Version -CommitHash $GitSha.ToString() -GitHubOwner $Owner -GitHubRepo $Repository

        # Check if we have any project files before attempting to package
        $hasProjects = (Get-ChildItem -Path "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0

        if (-not $hasProjects) {
            Write-Warning "No .NET projects found in repository. Skipping packaging steps."
            $SkipPackages = $true
        }

        # Package and publish if not skipped
        $packagePaths = @()
        if (-not $SkipPackages) {
            # Create NuGet packages
            try {
                Write-StepHeader "Packaging Libraries"
                Invoke-DotNetPack -Configuration $Configuration -OutputPath $BuildConfig.StagingPath -Verbosity "detailed"

                # Add package paths if they exist
                if (Test-Path $BuildConfig.PackagePattern) {
                    $packagePaths += $BuildConfig.PackagePattern
                }
                if (Test-Path $BuildConfig.SymbolsPattern) {
                    $packagePaths += $BuildConfig.SymbolsPattern
                }
            }
            catch {
                Write-Warning "Library packaging failed: $_"
                Write-Warning "Continuing with release process without NuGet packages."
            }

            # Create application packages
            try {
                Write-StepHeader "Publishing Applications"
                Invoke-DotNetPublish -Configuration $Configuration -OutputPath $BuildConfig.OutputPath -StagingPath $BuildConfig.StagingPath -Version $versionInfo.Version -DotnetVersion $BuildConfig.DotnetVersion

                # Add application paths if they exist
                if (Test-Path $BuildConfig.ApplicationPattern) {
                    $packagePaths += $BuildConfig.ApplicationPattern
                }
            }
            catch {
                Write-Warning "Application publishing failed: $_"
                Write-Warning "Continuing with release process without application packages."
            }

            # Publish packages if we have any and NuGet key is provided
            $packages = @(Get-Item -Path $BuildConfig.PackagePattern -ErrorAction SilentlyContinue)
            if ($packages.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($NuGetApiKey)) {
                Write-StepHeader "Publishing NuGet Packages"
                try {
                    Invoke-NuGetPublish -PackagePattern $BuildConfig.PackagePattern -GithubToken $GithubToken -GithubOwner $Owner -NuGetApiKey $NuGetApiKey
                }
                catch {
                    Write-Warning "NuGet package publishing failed: $_"
                    Write-Warning "Continuing with release process."
                }
            }
        }

        # Create GitHub release
        Write-StepHeader "Creating GitHub Release"
        Write-Host "Creating release for version $($versionInfo.Version)..."
        New-GitHubRelease -Version $versionInfo.Version -CommitHash $releaseHash.ToString() -GithubToken $GithubToken -AssetPatterns $packagePaths

        Write-StepHeader "Release Process Completed"
        Write-Host "Release process completed successfully!" -ForegroundColor Green
        return @{
            Version = $versionInfo.Version
            ReleaseHash = $releaseHash
            Success = $true
        }
    }
    catch {
        Write-Error "Release workflow failed: $_"
        return @{
            Success = $false
            Error = $_.ToString()
            StackTrace = $_.ScriptStackTrace
        }
    }
}

function Invoke-CIPipeline {
    <#
    .SYNOPSIS
        Executes the complete CI/CD pipeline.
    .DESCRIPTION
        Runs the entire build, test, package, and release process as a single pipeline.
        This is the main entry point for CI systems like GitHub Actions.
    .PARAMETER GitRef
        The Git reference (branch/tag) being built (e.g., "refs/heads/main").
    .PARAMETER GitSha
        The Git commit SHA being built.
    .PARAMETER WorkspacePath
        The path to the workspace/repository root.
    .PARAMETER ServerUrl
        The GitHub server URL (e.g., "https://github.com").
    .PARAMETER Owner
        The repository owner/organization name.
    .PARAMETER Repository
        The repository name.
    .PARAMETER GithubToken
        The GitHub token for authentication and API operations.
    .PARAMETER NuGetApiKey
        Optional NuGet.org API key for publishing packages.
    .PARAMETER Configuration
        The build configuration (Debug/Release). Defaults to "Release".
    .PARAMETER ExpectedOwner
        The expected owner for official builds. Defaults to "ktsu-dev".
    .EXAMPLE
        $result = Invoke-CIPipeline -GitRef "refs/heads/main" -GitSha "abc123" -WorkspacePath "." -ServerUrl "https://github.com" -Owner "myorg" -Repository "myrepo" -GithubToken $env:GITHUB_TOKEN
    .NOTES
        Author: ktsu.dev
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Git reference (branch/tag) being built")]
        [string]$GitRef,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Git commit SHA being built")]
        [ValidateNotNullOrEmpty()]
        [string]$GitSha,

        [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Path to workspace/repository root")]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspacePath,

        [Parameter(Mandatory = $true, Position = 3, HelpMessage = "GitHub server URL")]
        [string]$ServerUrl,

        [Parameter(Mandatory = $true, Position = 4, HelpMessage = "Repository owner/organization")]
        [string]$Owner,

        [Parameter(Mandatory = $true, Position = 5, HelpMessage = "Repository name")]
        [string]$Repository,

        [Parameter(Mandatory = $true, Position = 6, HelpMessage = "GitHub token for authentication")]
        [string]$GithubToken,

        [Parameter(Position = 7, HelpMessage = "NuGet.org API key for publishing packages")]
        [string]$NuGetApiKey,

        [Parameter(Position = 8, HelpMessage = "Build configuration (Debug/Release)")]
        [ValidateSet("Debug", "Release")]
        [string]$Configuration = "Release",

        [Parameter(HelpMessage = "Expected owner for official builds")]
        [string]$ExpectedOwner = "ktsu-dev"
    )

    Write-StepHeader "Starting CI/CD Pipeline"
    Write-Host "Repository: $Owner/$Repository"
    Write-Host "Git Reference: $GitRef"
    Write-Host "Git SHA: $GitSha"
    Write-Host "Configuration: $Configuration"

    try {
        # Get build configuration
        Write-StepHeader "Configuring Build"
        $buildConfig = Get-BuildConfiguration -GitRef $GitRef -GitSha $GitSha -WorkspacePath $WorkspacePath -GithubToken $GithubToken -ExpectedOwner $ExpectedOwner

        # Run build workflow
        Write-StepHeader "Running Build Workflow"
        $buildResult = Invoke-BuildWorkflow -Configuration $Configuration -BuildArgs $buildConfig.BuildArgs -BuildConfig $buildConfig

        if (-not $buildResult) {
            Write-Error "Build workflow failed"
            return @{
                BuildSuccess = $false
                ReleaseSuccess = $false
                ShouldRelease = $false
                Error = "Build workflow failed"
            }
        }

        # If build succeeded and we should release, run release workflow
        if ($buildConfig.ShouldRelease) {
            Write-StepHeader "Starting Release Workflow"
            $releaseResult = Invoke-ReleaseWorkflow -GitSha $GitSha -ServerUrl $ServerUrl -Owner $Owner -Repository $Repository `
                             -Configuration $Configuration -BuildConfig $buildConfig -GithubToken $GithubToken -NuGetApiKey $NuGetApiKey

            return @{
                BuildSuccess = $true
                ReleaseSuccess = $releaseResult.Success
                Version = $releaseResult.Version
                ReleaseHash = $releaseResult.ReleaseHash
                ShouldRelease = $true
            }
        }
        else {
            Write-StepHeader "Build Completed"
            Write-Host "Build successful! Release not required for this build."
            return @{
                BuildSuccess = $true
                ReleaseSuccess = $false
                ShouldRelease = $false
            }
        }
    }
    catch {
        Write-Error "CI/CD pipeline failed: $_"
        return @{
            BuildSuccess = $false
            ReleaseSuccess = $false
            ShouldRelease = $false
            Error = $_.ToString()
            StackTrace = $_.ScriptStackTrace
        }
    }
}

#endregion

# Export public functions
# Core build and environment functions
Export-ModuleMember -Function Initialize-BuildEnvironment,
                             Get-BuildConfiguration

# Version management functions
Export-ModuleMember -Function Get-GitTags,
                             Get-VersionType,
                             Get-VersionInfoFromGit,
                             New-Version

# Version comparison and conversion functions
Export-ModuleMember -Function ConvertTo-FourComponentVersion,
                             Get-VersionNotes

# Metadata and documentation functions
Export-ModuleMember -Function New-Changelog,
                             Update-ProjectMetadata,
                             New-License

# .NET SDK operations
Export-ModuleMember -Function Invoke-DotNetRestore,
                             Invoke-DotNetBuild,
                             Invoke-DotNetTest,
                             Invoke-DotNetPack,
                             Invoke-DotNetPublish

# Release and publishing functions
Export-ModuleMember -Function Invoke-NuGetPublish,
                             New-GitHubRelease

# Utility functions
Export-ModuleMember -Function Assert-LastExitCode,
                             Write-StepHeader,
                             Test-AnyFiles

# High-level workflow functions
Export-ModuleMember -Function Invoke-BuildWorkflow,
                             Invoke-ReleaseWorkflow,
                             Invoke-CIPipeline
