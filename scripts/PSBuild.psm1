# PSBuild Module for .NET CI/CD
# Version: 1.0.0
# Author: ktsu.dev
# License: MIT
#
# A comprehensive PowerShell module for automating the build, test, package,
# and release process for .NET applications using Git-based versioning.
# See README.md for detailed documentation and usage examples.

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

    Write-Host "Build environment initialized"
}

function Get-BuildConfiguration {
    <#
    .SYNOPSIS
        Gets the build configuration based on Git status and environment.
    .DESCRIPTION
        Determines if this is a release build, checks Git status, and sets up build paths.
    .PARAMETER ServerUrl
        The server URL to use for the build.
    .PARAMETER GitRef
        The Git reference (branch/tag) being built.
    .PARAMETER GitSha
        The Git commit SHA being built.
    .PARAMETER GitHubOwner
        The GitHub owner of the repository.
    .PARAMETER GitHubRepo
        The GitHub repository name.
    .PARAMETER GithubToken
        Optional GitHub token for API operations.
    .PARAMETER NuGetApiKey
        Optional NuGet API key for package publishing.
    .PARAMETER WorkspacePath
        The path to the workspace/repository root.
    .PARAMETER ExpectedOwner
        The expected owner/organization of the official repository.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerUrl,
        [Parameter(Mandatory=$true)]
        [string]$GitRef,
        [Parameter(Mandatory=$true)]
        [string]$GitSha,
        [Parameter(Mandatory=$true)]
        [string]$GitHubOwner,
        [Parameter(Mandatory=$true)]
        [string]$GitHubRepo,
        [Parameter(Mandatory=$true)]
        [string]$GithubToken,
        [Parameter(Mandatory=$true)]
        [string]$NuGetApiKey,
        [Parameter(Mandatory=$true)]
        [string]$WorkspacePath,
        [Parameter(Mandatory=$true)]
        [string]$ExpectedOwner
    )

    # Determine if this is an official repo (verify owner and ensure it's not a fork)
    $IS_OFFICIAL = $false
    if ($GithubToken) {
        try {
            $env:GH_TOKEN = $GithubToken
            $repoInfo = gh repo view --json owner,nameWithOwner,isFork 2>$null | ConvertFrom-Json
            if ($repoInfo) {
                # Consider it official only if it's not a fork AND belongs to the expected owner
                $IS_OFFICIAL = (-not $repoInfo.isFork) -and ($repoInfo.owner.login -eq $ExpectedOwner)
                Write-Verbose "Repository: $($repoInfo.nameWithOwner), Is Fork: $($repoInfo.isFork), Owner: $($repoInfo.owner.login)"
            } else {
                Write-Host "Could not retrieve repository information. Assuming unofficial build."
            }
        }
        catch {
            Write-Host "Failed to check repository status: $_. Assuming unofficial build."
        }
    }
    Write-Verbose "Is Official: $IS_OFFICIAL"

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

    # Create configuration object with standard format
    $config = [PSCustomObject]@{
        Success = $true
        Error = ""
        Data = @{
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
            ServerUrl = $ServerUrl
            GitRef = $GitRef
            GitSha = $GitSha
            GitHubOwner = $GitHubOwner
            GitHubRepo = $GitHubRepo
            GithubToken = $GithubToken
            NuGetApiKey = $NuGetApiKey
            ExpectedOwner = $ExpectedOwner
            Version = "1.0.0-pre.0"
            ReleaseHash = $GitSha
        }
    }

    # Display configuration details
    Write-Host "Build Configuration:" -ForegroundColor Cyan
    Write-Host "  Repository Status:" -ForegroundColor Yellow
    Write-Host "    Server URL:      $($config.Data.ServerUrl)"
    Write-Host "    Git Ref:         $($config.Data.GitRef)"
    Write-Host "    Git Sha:         $($config.Data.GitSha)"
    Write-Host "    GitHub Owner:    $($config.Data.GitHubOwner)"
    Write-Host "    GitHub Repo:     $($config.Data.GitHubRepo)"
    Write-Host "    Github Token:    $($config.Data.GithubToken)"
    Write-Host "    NuGet Api Key:   $($config.Data.NuGetApiKey)"
    Write-Host "    Workspace Path:  $($config.Data.WorkspacePath)"
    Write-Host "    Expected Owner:  $($config.Data.ExpectedOwner)"
    Write-Host "    Is Official Repo: $($config.Data.IsOfficial)"
    Write-Host "    Is Main Branch:  $($config.Data.IsMain)"
    Write-Host "    Is Tagged:       $($config.Data.IsTagged)"
    Write-Host "    Should Release:  $($config.Data.ShouldRelease)"
    Write-Host ""
    Write-Host "  Build Settings:" -ForegroundColor Yellow
    Write-Host "    .NET Version:    $($config.Data.DotnetVersion)"
    Write-Host "    Uses Script:     $($config.Data.UseDotnetScript)"
    Write-Host "    Build Args:      $($config.Data.BuildArgs)"
    Write-Host ""
    Write-Host "  Paths:" -ForegroundColor Yellow
    Write-Host "    Workspace:       $($config.Data.WorkspacePath)"
    Write-Host "    Output:          $($config.Data.OutputPath)"
    Write-Host "    Staging:         $($config.Data.StagingPath)"
    Write-Host ""
    Write-Host "  Artifact Patterns:" -ForegroundColor Yellow
    Write-Host "    Packages:        $($config.Data.PackagePattern)"
    Write-Host "    Symbols:         $($config.Data.SymbolsPattern)"
    Write-Host "    Applications:    $($config.Data.ApplicationPattern)"
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

    Write-Host "Configuring git version sort settings..." -ForegroundColor Cyan

    # Configure git to properly sort version tags with suffixes
    $output = git config versionsort.suffix "-alpha" 2>&1
    Write-Host "git config versionsort.suffix -alpha: $output"

    $output = git config versionsort.suffix "-beta" 2>&1
    Write-Host "git config versionsort.suffix -beta: $output"

    $output = git config versionsort.suffix "-rc" 2>&1
    Write-Host "git config versionsort.suffix -rc: $output"

    $output = git config versionsort.suffix "-pre" 2>&1
    Write-Host "git config versionsort.suffix -pre: $output"

    Write-Host "Getting sorted tags..." -ForegroundColor Cyan
    # Get tags and ensure we return an array
    $output = git tag --list --sort=-v:refname 2>&1
    Write-Host "git tag --list --sort=-v:refname output: $output"

    $tags = @($output)

    # Return default if no tags exist
    if ($null -eq $tags -or $tags.Count -eq 0) {
        Write-Host "No tags found, returning default v1.0.0-pre.0" -ForegroundColor Yellow
        return @('v1.0.0-pre.0')
    }

    Write-Host "Found $($tags.Count) tags" -ForegroundColor Green
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

    # Write-StepHeader "Analyzing Version Changes"
    # Write-Host "Analyzing commits for version increment decision..."
    # Write-Host "Commit range: $Range" -ForegroundColor Cyan

    # Initialize to the most conservative version bump
    $versionType = "prerelease"
    $reason = "No significant changes detected"

    # Bot and PR patterns to exclude
    $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
    $EXCLUDE_PRS = '^.*(Merge pull request|Merge branch ''main''|Updated packages in|Update.*package version).*$'

    # Write-Host "`nChecking for non-merge commits..." -ForegroundColor Cyan
    # Write-Host "Running: git log --date-order --perl-regexp --regexp-ignore-case --grep=""$EXCLUDE_PRS"" --invert-grep --committer=""$EXCLUDE_BOTS"" --author=""$EXCLUDE_BOTS"" $Range"

    # Check for non-merge commits
    $allCommits = git log --date-order --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $Range 2>&1
    # Write-Host "Non-merge commits found:`n$allCommits"

    if ($allCommits) {
        $versionType = "patch"
        $reason = "Found non-merge commits requiring at least a patch version"
        # Write-Host "Found non-merge commits - minimum patch version required" -ForegroundColor Yellow
    }

    # Check for code changes (excluding documentation, config files, etc.)
    # Write-Host "`nChecking for code changes..." -ForegroundColor Cyan
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
    # Write-Host "Running: git log --topo-order --perl-regexp --regexp-ignore-case --format=format:%H --committer=""$EXCLUDE_BOTS"" --author=""$EXCLUDE_BOTS"" --grep=""$EXCLUDE_PRS"" --invert-grep $Range -- '*/*.*' $excludeString"

    $codeChanges = git log --topo-order --perl-regexp --regexp-ignore-case --format=format:%H --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" --grep="$EXCLUDE_PRS" --invert-grep $Range -- '*/*.*' $excludeString 2>&1
    # Write-Host "Code changes found:`n$codeChanges"

    if ($codeChanges) {
        $versionType = "minor"
        $reason = "Found code changes requiring at least a minor version"
        # Write-Host "Found code changes - minimum minor version required" -ForegroundColor Yellow
    }

    # Look for explicit version bump annotations in commit messages
    # Write-Host "`nChecking for version bump annotations in commit messages..." -ForegroundColor Cyan
    # Write-Host "Running: git log --format=format:%s $Range"

    $messages = git log --format=format:%s $Range 2>&1
    # Write-Host "Commit messages found:`n$messages"

    foreach ($message in $messages) {
        if ($message.Contains('[major]')) {
            # Write-Host "Found [major] tag in commit: $message" -ForegroundColor Red
            return @{
                Type = 'major'
                Reason = "Explicit [major] tag found in commit message: $message"
            }
        }
        elseif ($message.Contains('[minor]') -and $versionType -ne 'major') {
            # Write-Host "Found [minor] tag in commit: $message" -ForegroundColor Yellow
            $versionType = 'minor'
            $reason = "Explicit [minor] tag found in commit message: $message"
        }
        elseif ($message.Contains('[patch]') -and $versionType -notin @('major', 'minor')) {
            # Write-Host "Found [patch] tag in commit: $message" -ForegroundColor Green
            $versionType = 'patch'
            $reason = "Explicit [patch] tag found in commit message: $message"
        }
        elseif ($message.Contains('[pre]') -and $versionType -notin @('major', 'minor', 'patch')) {
            # Write-Host "Found [pre] tag in commit: $message" -ForegroundColor Blue
            $versionType = 'prerelease'
            $reason = "Explicit [pre] tag found in commit message: $message"
        }
    }

    # Write-Host "`nVersion type decision: $versionType" -ForegroundColor Cyan
    # Write-Host "Reason: $reason" -ForegroundColor Cyan

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
    Write-Host "Commit hash: $CommitHash" -ForegroundColor Cyan

    # Get tag information
    Write-Host "`nGetting tag information..." -ForegroundColor Cyan
    $allTags = Get-GitTags
    $noTagsExist = ($null -eq $allTags) -or
                   (($allTags -is [string]) -and $allTags -eq 'v1.0.0-pre.0') -or
                   (($allTags -is [array]) -and $allTags.Count -eq 1 -and $allTags[0] -eq 'v1.0.0-pre.0')

    if ($noTagsExist) {
        # Special case: This is the first version, no real tags exist yet
        Write-Host "No existing version tags found - using initial version: $InitialVersion" -ForegroundColor Yellow

        return [PSCustomObject]@{
            Success = $true
            Error = ""
            Data = @{
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
    Write-Host "`nGetting first commit..." -ForegroundColor Cyan
    Write-Host "Running: git rev-list HEAD"
    $output = git rev-list HEAD 2>&1
    Write-Host "git rev-list HEAD output:`n$output"
    $firstCommit = $output[-1]
    Write-Host "First commit: $firstCommit"

    $commitRange = "$firstCommit...$CommitHash"
    Write-Host "`nAnalyzing commit range: $commitRange" -ForegroundColor Cyan
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

    try {
        # Return comprehensive object with standard format
        return [PSCustomObject]@{
            Success = $true
            Error = ""
            Data = @{
                Version = $newVersion
                Major = $newMajor
                Minor = $newMinor
                Patch = $newPatch
                IsPrerelease = $isPrerelease
                PrereleaseNumber = $newPrereleaseNum
                PrereleaseLabel = $prereleaseLabel
                LastTag = $lastTag
                LastVersion = $lastVersion
                LastVersionMajor = $lastMajor
                LastVersionMinor = $lastMinor
                LastVersionPatch = $lastPatch
                WasPrerelease = $wasPrerelease
                LastVersionPrereleaseNumber = $lastPrereleaseNum
                VersionIncrement = $incrementType
                IncrementReason = $incrementReason
                FirstCommit = $firstCommit
                LastCommit = $CommitHash
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Error = $_.ToString()
            Data = @{}
        }
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
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$CommitHash,
        [string]$OutputPath = ""
    )

    # Get complete version information object
    $versionInfo = Get-VersionInfoFromGit -CommitHash $CommitHash

    # Get the correct line ending
    $lineEnding = Get-GitLineEnding

    # Write version file with correct line ending
    $filePath = if ($OutputPath) { Join-Path $OutputPath "VERSION.md" } else { "VERSION.md" }
    $version = $versionInfo.Data.Version.Trim()
    [System.IO.File]::WriteAllText($filePath, $version + $lineEnding, [System.Text.UTF8Encoding]::new($false))

    Write-Verbose "Previous version: $($versionInfo.Data.LastVersion), New version: $($versionInfo.Data.Version)"
    return $versionInfo.Data.Version
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
    $lineEnding = Get-GitLineEnding

    # Project URL
    $projectUrl = "$ServerUrl/$Owner/$Repository"
    $content = $content.Replace('{PROJECT_URL}', $projectUrl)

    # Copyright line
    $copyright = "Copyright (c) 2023-$year $Owner"
    $content = $content.Replace('{COPYRIGHT}', $copyright)

    # Normalize line endings
    $content = $content.Replace("`r`n", "`n").Replace("`r", "`n")
    $content = $content.Replace("`n", $lineEnding)

    $copyrightFilePath = if ($OutputPath) { Join-Path $OutputPath "COPYRIGHT.md" } else { "COPYRIGHT.md" }
    [System.IO.File]::WriteAllText($copyrightFilePath, $copyright + $lineEnding, [System.Text.UTF8Encoding]::new($false))

    $filePath = if ($OutputPath) { Join-Path $OutputPath "LICENSE.md" } else { "LICENSE.md" }
    [System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($false))
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

    if (@($versionComponents).Count -gt 3) {
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
        $matchingTag = $null

        # First try to find exact match
        foreach ($tag in $Tags) {
            $otherVersion = ConvertTo-FourComponentVersion -VersionTag $tag
            if ($searchVersion -eq $otherVersion) {
                $matchingTag = $tag
                $foundSearchTag = $true
                break
            }
        }

        # If no exact match, find closest lower version
        if (-not $foundSearchTag) {
            $closestVersion = "0.0.0.0"
            foreach ($tag in $Tags) {
                $otherVersion = ConvertTo-FourComponentVersion -VersionTag $tag
                if (([Version]$otherVersion) -lt ([Version]$searchVersion) -and
                    ([Version]$otherVersion) -gt ([Version]$closestVersion)) {
                    $closestVersion = $otherVersion
                    $matchingTag = $tag
                    $foundSearchTag = $true
                }
            }
        }

        if ($foundSearchTag) {
            $searchTag = $matchingTag
        } else {
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
        $versionTypeInfo = Get-VersionType -Range $range
        $versionType = $versionTypeInfo.Type
    }

    # Exclude patterns for commit authors and messages
    $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
    $EXCLUDE_PRS = '^.*(Merge pull request|Merge branch ''main''|Updated packages in|Update.*package version).*$'

    # Get commit messages with authors
    $commits = git log --pretty=format:"%s ([@%aN](https://github.com/%aN))" --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $range | Sort-Object | Get-Unique

    # Format changelog entry
    $versionChangelog = ""
    if ($versionType -ne "prerelease" -and @($commits).Count -gt 0) {
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

    # Add entry for current/new version
    $previousTag = if ($null -eq $tags -or
                      ($tags -is [string]) -or
                      ((@($tags).Count -eq 0))) {
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
    if ($IncludeAllVersions -and $tags -is [array] -and $tags.Count -gt 0) {
        $processedTags = @{}

        for ($i = 0; $i -lt $tags.Count; $i++) {
            $tag = $tags[$i]

            # Skip if we've already processed this tag or it's not a version tag
            if ($processedTags.ContainsKey($tag) -or -not ($tag -like "v*")) {
                continue
            }

            $previousTag = "v0.0.0"
            if ($i -lt $tags.Count - 1) {
                $previousTag = $tags[$i + 1]
                if (-not ($previousTag -like "v*")) {
                    $previousTag = "v0.0.0"
                }
            }

            $changelog += Get-VersionNotes -Tags $tags -FromTag $previousTag -ToTag $tag
            $processedTags[$tag] = $true
        }
    }

    # Get the correct line ending
    $lineEnding = Get-GitLineEnding

    # Write changelog to file
    $filePath = if ($OutputPath) { Join-Path $OutputPath "CHANGELOG.md" } else { "CHANGELOG.md" }

    # Normalize line endings in changelog content
    $changelog = $changelog.Replace("`r`n", "`n").Replace("`r", "`n")
    $changelog = $changelog.Replace("`n", $lineEnding)

    [System.IO.File]::WriteAllText($filePath, $changelog, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Changelog generated with entries for $(@($tags).Count + 1) versions"
}

#endregion

#region Metadata Management

function Update-ProjectMetadata {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$BuildConfiguration,
        [Parameter(Mandatory = $false)]
        [string[]]$Authors = @(),
        [Parameter(Mandatory = $false)]
        [string]$CommitMessage = "[bot][skip ci] Update Metadata"
    )

    try {
        Write-Host "Generating version information..."
        $version = New-Version -CommitHash $BuildConfiguration.ReleaseHash
        Write-Host "Version: $version"

        Write-Host "Generating license..."
        New-License -ServerUrl $BuildConfiguration.ServerUrl -Owner $BuildConfiguration.GitHubOwner -Repository $BuildConfiguration.GitHubRepo

        Write-Host "Generating changelog..."
        New-Changelog -Version $version -CommitHash $BuildConfiguration.ReleaseHash

        # Create AUTHORS.md if authors are provided
        if ($Authors.Count -gt 0) {
            Write-Host "Generating authors file..."
            $authorsContent = "# Project Authors`n`n"
            foreach ($author in $Authors) {
                $authorsContent += "* $author`n"
            }
            [System.IO.File]::WriteAllText("AUTHORS.md", $authorsContent, [System.Text.UTF8Encoding]::new($false))
        }

        # Create AUTHORS.url
        $authorsUrl = "[InternetShortcut]`nURL=$($BuildConfiguration.ServerUrl)/$($BuildConfiguration.GitHubOwner)"
        [System.IO.File]::WriteAllText("AUTHORS.url", $authorsUrl, [System.Text.UTF8Encoding]::new($false))

        # Create PROJECT_URL.url
        $projectUrl = "[InternetShortcut]`nURL=$($BuildConfiguration.ServerUrl)/$($BuildConfiguration.GitHubOwner)/$($BuildConfiguration.GitHubRepo)"
        [System.IO.File]::WriteAllText("PROJECT_URL.url", $projectUrl, [System.Text.UTF8Encoding]::new($false))

        Write-Host "Checking git status before adding files..."
        $preStatus = git status --porcelain
        Write-Host "Current status:"
        Write-Host $preStatus
        Write-Host ""

        Write-Host "Adding files to git..."
        $filesToAdd = @(
            "VERSION.md",
            "LICENSE.md",
            "AUTHORS.md",
            "CHANGELOG.md",
            "COPYRIGHT.md",
            "PROJECT_URL.url",
            "AUTHORS.url"
        )
        Write-Host "Files to add: $($filesToAdd -join ", ")"
        $addOutput = git add $filesToAdd 2>&1
        Write-Host "git add output: "
        Write-Host $addOutput
        Write-Host ""

        Write-Host "Checking for changes to commit..."
        $postStatus = git status --porcelain
        Write-Host "Status after add:"
        Write-Host $postStatus
        Write-Host ""

        # Get the current commit hash regardless of whether we make changes
        $currentHash = git rev-parse HEAD
        Write-Host "Current commit hash: $currentHash"

        if ($postStatus) {
            # Configure git user before committing
            Set-GitIdentity

            Write-Host "Committing changes..."
            Write-Host "Running: git commit -m `"$CommitMessage`""
            $commitOutput = git commit -m $CommitMessage 2>&1
            Write-Host "Commit output: $commitOutput"
            Write-Host ""

            Write-Host "Pushing changes..."
            $pushOutput = git push 2>&1
            Write-Host "Push output: $pushOutput"
            Write-Host ""

            Write-Host "Getting release hash..."
            $releaseHash = git rev-parse HEAD
            Write-Host "Metadata committed as $releaseHash"
            Write-Host ""

            Write-Host "Metadata update completed successfully with changes"
            Write-Host "Version: $version"
            Write-Host "Release Hash: $releaseHash"

            return [PSCustomObject]@{
                Success = $true
                Error = ""
                Data = @{
                    Version = $version
                    ReleaseHash = $releaseHash
                    HasChanges = $true
                }
            }
        }
        else {
            Write-Host "No changes to commit"
            Write-Host "Version: $version"
            Write-Host "Using current commit hash: $currentHash"

            return [PSCustomObject]@{
                Success = $true
                Error = ""
                Data = @{
                    Version = $version
                    ReleaseHash = $currentHash
                    HasChanges = $false
                }
            }
        }
    }
    catch {
        $errorMessage = $_.ToString()
        Write-Host "Failed to update metadata: $errorMessage"
        return [PSCustomObject]@{
            Success = $false
            Error = $errorMessage
            Data = @{
                Version = $null
                ReleaseHash = $null
                HasChanges = $false
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
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

    # Execute command and stream output directly to console
    & dotnet restore --locked-mode -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" | ForEach-Object {
        Write-Host $_
    }
    Assert-LastExitCode "Restore failed"
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

    try {
        # First attempt with quiet verbosity - stream output directly
        & dotnet build --configuration $Configuration -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" --no-incremental $BuildArgs --no-restore | ForEach-Object {
            Write-Host $_
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed with exit code $LASTEXITCODE. Retrying with detailed verbosity..."

            # Retry with more detailed verbosity - stream output directly
            & dotnet build --configuration $Configuration -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" --no-incremental $BuildArgs --no-restore | ForEach-Object {
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

                Assert-LastExitCode "Build failed"
            }
        }
    }
    catch {
        Write-Host "Exception during build process: $_"
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

    # Execute command and stream output directly to console
    & dotnet test -m:1 --configuration $Configuration -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" --no-build --collect:"XPlat Code Coverage" --results-directory $CoverageOutputPath | ForEach-Object {
        Write-Host $_
    }
    Assert-LastExitCode "Tests failed"
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
    .PARAMETER Project
        Optional specific project to package. If not provided, all projects are packaged.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
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
            & dotnet pack --configuration $Configuration -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" --no-build --output $OutputPath | ForEach-Object {
                Write-Host $_
            }
        } else {
            Write-Host "Packaging project: $Project"
            & dotnet pack $Project --configuration $Configuration -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" --no-build --output $OutputPath | ForEach-Object {
                Write-Host $_
            }
        }

        if ($LASTEXITCODE -ne 0) {
            # Get more details about what might have failed
            Write-Host "Packaging failed with exit code $LASTEXITCODE, trying again with detailed verbosity..."
            & dotnet pack --configuration $Configuration -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=detailed" --no-build --output $OutputPath | ForEach-Object {
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
        Write-Host "Package creation failed: $originalException"
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
        & dotnet publish $csproj --no-build --configuration $Configuration --framework net$DotnetVersion --output $outDir /p:ConsoleLoggerParameters="NoSummary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" | ForEach-Object {
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

    # Configure git user
    Set-GitIdentity

    # Ensure version is trimmed
    $Version = $Version.Trim()

    # Create and push the tag first
    Write-Host "Creating and pushing tag v$Version..."
    & git tag -a "v$Version" $CommitHash -m "Release v$Version"
    Assert-LastExitCode "Failed to create git tag"

    & git push origin "v$Version"
    Assert-LastExitCode "Failed to push git tag"

    # Collect all assets
    $assets = @()
    foreach ($pattern in $AssetPatterns) {
        $matched = Get-Item -Path $pattern -ErrorAction SilentlyContinue
        if ($matched) {
            $assets += $matched.FullName
        }
    }

    # Create release
    Write-StepHeader "Creating GitHub Release v$Version"

    $releaseArgs = @(
        "release",
        "create",
        "v$Version"
    )

    # Add target commit
    $releaseArgs += "--target"
    $releaseArgs += $CommitHash.ToString()

    # Add notes generation
    $releaseArgs += "--generate-notes"

    # Handle changelog content if file exists
    if (Test-Path $ChangelogFile) {
        Write-Host "Using changelog from $ChangelogFile"
        $releaseArgs += "--notes-file"
        $releaseArgs += $ChangelogFile
    }

    # Add assets as positional arguments
    $releaseArgs += $assets

    Write-Host "Running: gh $($releaseArgs -join ' ')"
    & gh @releaseArgs
    Assert-LastExitCode "Failed to create GitHub release"
}

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
        Write-Host $fullMessage
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

# Add this helper function in the Utility Functions region
function Get-GitLineEnding {
    <#
    .SYNOPSIS
        Gets the correct line ending based on git config.
    .DESCRIPTION
        Determines whether to use LF or CRLF based on the git core.autocrlf setting
        and the current operating system.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $autocrlf = git config --get core.autocrlf 2>&1
    $eol = git config --get core.eol 2>&1

    # If core.eol is set, use that
    if ($LASTEXITCODE -eq 0 -and $eol -in @('lf', 'crlf')) {
        return if ($eol -eq 'lf') { "`n" } else { "`r`n" }
    }

    # Otherwise use autocrlf setting
    if ($LASTEXITCODE -eq 0) {
        switch ($autocrlf.ToLower()) {
            'true' { return "`n" }  # Git will convert to CRLF on checkout
            'input' { return "`n" } # Always use LF
            'false' {
                # Use OS default
                return [System.Environment]::NewLine
            }
            default {
                # Default to OS line ending if setting is not recognized
                return [System.Environment]::NewLine
            }
        }
    }

    # If git config fails or no setting found, use OS default
    return [System.Environment]::NewLine
}

function Set-GitIdentity {
    <#
    .SYNOPSIS
        Configures git user identity for automated operations.
    .DESCRIPTION
        Sets up git user name and email globally for GitHub Actions or other automated processes.
    #>
    [CmdletBinding()]
    param()

    Write-Host "Configuring git user for GitHub Actions..."
    & git config --global user.name "Github Actions"
    Assert-LastExitCode "Failed to configure git user name"
    & git config --global user.email "actions@users.noreply.github.com"
    Assert-LastExitCode "Failed to configure git user email"
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
    .PARAMETER BuildConfiguration
        The build configuration object from Get-BuildConfiguration.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [string]$BuildArgs = "",
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfiguration
    )

    try {
        # Setup
        Initialize-BuildEnvironment

        # Install dotnet-script if needed
        if ($BuildConfiguration.UseDotnetScript) {
            Write-StepHeader "Installing dotnet-script"
            dotnet tool install -g dotnet-script
            Assert-LastExitCode "Failed to install dotnet-script"
        }

        # Build and Test
        Invoke-DotNetRestore
        Invoke-DotNetBuild -Configuration $Configuration -BuildArgs $BuildArgs
        Invoke-DotNetTest -Configuration $Configuration -CoverageOutputPath "coverage"

        return [PSCustomObject]@{
            Success = $true
            Error = ""
            Data = @{
                Configuration = $Configuration
                BuildArgs = $BuildArgs
            }
        }
    }
    catch {
        Write-Host "Build workflow failed: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.ToString()
            Data = @{}
        }
    }
}

function Invoke-ReleaseWorkflow {
    <#
    .SYNOPSIS
        Executes the release workflow.
    .DESCRIPTION
        Generates metadata, packages, and creates a release.
    .PARAMETER BuildConfiguration
        The build configuration object from Get-BuildConfiguration.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfiguration
    )

    try {
        Write-StepHeader "Starting Release Process"

        # Package and publish if not skipped
        $packagePaths = @()

        # Create NuGet packages
        try {
                Write-StepHeader "Packaging Libraries"
                Invoke-DotNetPack -Configuration $Configuration -OutputPath $BuildConfiguration.StagingPath

            # Add package paths if they exist
            if (Test-Path $BuildConfiguration.PackagePattern) {
                $packagePaths += $BuildConfiguration.PackagePattern
            }
            if (Test-Path $BuildConfiguration.SymbolsPattern) {
                $packagePaths += $BuildConfiguration.SymbolsPattern
            }
        }
        catch {
            Write-Host "Library packaging failed: $_"
            Write-Host "Continuing with release process without NuGet packages."
        }

        # Create application packages
        try {
            Write-StepHeader "Publishing Applications"
            Invoke-DotNetPublish -Configuration $Configuration -OutputPath $BuildConfiguration.OutputPath -StagingPath $BuildConfiguration.StagingPath -Version $Version -DotnetVersion $BuildConfiguration.DotnetVersion

            # Add application paths if they exist
            if (Test-Path $BuildConfiguration.ApplicationPattern) {
                $packagePaths += $BuildConfiguration.ApplicationPattern
            }
        }
        catch {
            Write-Host "Application publishing failed: $_"
            Write-Host "Continuing with release process without application packages."
        }

        # Publish packages if we have any and NuGet key is provided
        $packages = @(Get-Item -Path $BuildConfiguration.PackagePattern -ErrorAction SilentlyContinue)
        if ($packages.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($NuGetApiKey)) {
            Write-StepHeader "Publishing NuGet Packages"
            try {
                Invoke-NuGetPublish -PackagePattern $BuildConfiguration.PackagePattern -GithubToken $BuildConfiguration.GithubToken -GithubOwner $BuildConfiguration.GitHubOwner -NuGetApiKey $NuGetApiKey
            }
            catch {
                Write-Host "NuGet package publishing failed: $_"
                Write-Host "Continuing with release process."
            }
        }

        # Create GitHub release
        Write-StepHeader "Creating GitHub Release"
        Write-Host "Creating release for version $($BuildConfiguration.Version)..."
        New-GitHubRelease -Version $BuildConfiguration.Version -CommitHash $BuildConfiguration.ReleaseHash -GithubToken $BuildConfiguration.GithubToken -AssetPatterns $packagePaths

        Write-StepHeader "Release Process Completed"
        Write-Host "Release process completed successfully!" -ForegroundColor Green
        return [PSCustomObject]@{
            Success = $true
            Error = ""
            Data = @{
                Version = $BuildConfiguration.Version
                ReleaseHash = $BuildConfiguration.ReleaseHash
                PackagePaths = $packagePaths
            }
        }
    }
    catch {
        Write-Host "Release workflow failed: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.ToString()
            Data = @{}
        }
    }
}

function Invoke-CIPipeline {
    <#
    .SYNOPSIS
        Executes the CI/CD pipeline.
    .DESCRIPTION
        Executes the CI/CD pipeline, including metadata updates and build workflow.
    .PARAMETER BuildConfiguration
        The build configuration to use.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfiguration
    )

    Write-Host "BuildConfiguration: $($BuildConfiguration | ConvertTo-Json -Depth 10)"

    try {
        Write-Host "Updating metadata..." -ForegroundColor Cyan
        $metadata = Update-ProjectMetadata `
            -BuildConfiguration $BuildConfiguration

        if ($null -eq $metadata) {
            Write-Host "Metadata update returned null"
            return [PSCustomObject]@{
                Success = $false
                Error = "Metadata update returned null"
            }
        }

        Write-Host "Metadata: $($metadata | ConvertTo-Json -Depth 10)"

        $BuildConfiguration.Version = $metadata.Version
        $BuildConfiguration.ReleaseHash = $metadata.ReleaseHash

        if (-not $metadata.Success) {
            Write-Host "Failed to update metadata: $($metadata.Error)"
            return [PSCustomObject]@{
                Success = $false
                Error = "Failed to update metadata: $($metadata.Error)"
            }
        }

        Write-Host "Running build workflow..." -ForegroundColor Cyan
        $result = Invoke-BuildWorkflow -BuildConfiguration $BuildConfiguration
        if (-not $result.Success) {
            Write-Host "Build workflow failed: $($result.Error)"
            return [PSCustomObject]@{
                Success = $false
                Error = "Build workflow failed: $($result.Error)"
            }
        }

        Write-Host "Running release workflow..." -ForegroundColor Cyan
        $result = Invoke-ReleaseWorkflow -BuildConfiguration $BuildConfiguration
        if (-not $result.Success) {
            Write-Host "Release workflow failed: $($result.Error)"
            return [PSCustomObject]@{
                Success = $false
                Error = "Release workflow failed: $($result.Error)"
            }
        }

        Write-Host "CI/CD pipeline completed successfully" -ForegroundColor Green
        return [PSCustomObject]@{
            Success = $true
            Version = $metadata.Version
            ReleaseHash = $metadata.ReleaseHash
        }
    }
    catch {
        Write-Host "CI/CD pipeline failed: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = "CI/CD pipeline failed: $_"
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
