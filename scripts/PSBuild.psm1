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
        Returns a configuration object containing all necessary build settings and paths.
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
        The GitHub token for API operations.
    .PARAMETER NuGetApiKey
        The NuGet API key for package publishing.
    .PARAMETER WorkspacePath
        The path to the workspace/repository root.
    .PARAMETER ExpectedOwner
        The expected owner/organization of the official repository.
    .PARAMETER ChangelogFile
        The path to the changelog file.
    .PARAMETER AssetPatterns
        Array of glob patterns for release assets.
    .OUTPUTS
        PSCustomObject containing build configuration data with Success, Error, and Data properties.
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
        [string]$ExpectedOwner,
        [Parameter(Mandatory=$true)]
        [string]$ChangelogFile,
        [Parameter(Mandatory=$true)]
        [string[]]$AssetPatterns
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
            ChangelogFile = $ChangelogFile
            AssetPatterns = $AssetPatterns
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
    Write-Host "  Changelog File:     $($config.Data.ChangelogFile)"
    Write-Host "  Asset Patterns:     $($config.Data.AssetPatterns -join ', ')"


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

    # Initialize to the most conservative version bump
    $versionType = "prerelease"
    $reason = "No significant changes detected"

    # Bot and PR patterns to exclude
    $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
    $EXCLUDE_PRS = '^.*(Merge pull request|Merge branch ''main''|Updated packages in|Update.*package version).*$'

    # Check for non-merge commits
    $allCommits = git log --date-order --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $Range 2>&1

    if ($allCommits) {
        $versionType = "patch"
        $reason = "Found non-merge commits requiring at least a patch version"
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

    $codeChanges = git log --topo-order --perl-regexp --regexp-ignore-case --format=format:%H --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" --grep="$EXCLUDE_PRS" --invert-grep $Range -- '*/*.*' $excludeString 2>&1

    if ($codeChanges) {
        $versionType = "minor"
        $reason = "Found code changes requiring at least a minor version"
    }


    $messages = git log --format=format:%s $Range 2>&1

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

    $lineEnding = Get-GitLineEnding

    Write-StepHeader "Analyzing Version Information"
    Write-Host "Analyzing repository for version information..."
    Write-Host "Commit hash: $CommitHash" -ForegroundColor Cyan

    # Get tag information
    Write-Host "$($lineEnding)Getting tag information..." -ForegroundColor Cyan
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
    Write-Host "$($lineEnding)Getting first commit..." -ForegroundColor Cyan
    Write-Host "Running: git rev-list HEAD"
    $output = git rev-list HEAD 2>&1
    Write-Host "git rev-list HEAD output:$lineEnding$output"
    $firstCommit = $output[-1]
    Write-Host "First commit: $firstCommit"

    $commitRange = "$firstCommit...$CommitHash"
    Write-Host "$($lineEnding)Analyzing commit range: $commitRange" -ForegroundColor Cyan
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

    Write-Host "$($lineEnding)Calculating new version..." -ForegroundColor Cyan

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

    Write-Host "$($lineEnding)Version decision:" -ForegroundColor Cyan
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
    $content = $content.ReplaceLineEndings($lineEnding)

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

    $lineEnding = Get-GitLineEnding

    # Define common patterns used for filtering commits
    $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
    $EXCLUDE_PRS = '^.*(Merge pull request|Merge branch ''main''|Updated packages in|Update.*package version).*$'

    # Check if this is a first release
    $isFirstRelease = $FromTag -eq "v0.0.0" -and
                    ($null -eq $Tags -or
                     ($Tags -is [array] -and $Tags.Count -eq 0) -or
                     ($Tags -is [string] -and $Tags.Trim() -eq ""))

    # Determine the appropriate range and version type
    $rangeFrom = ""
    $rangeTo = if ([string]::IsNullOrEmpty($ToSha)) { $ToTag } else { $ToSha }
    $versionType = "initial"
    $changeDescription = "Initial release including"
    $searchTag = "v0.0.0"

    # For regular releases (not first release), determine proper range and version type
    if (-not $isFirstRelease) {
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

        $range = $rangeTo
        if ($rangeFrom -ne "") {
            $range = "$rangeFrom...$rangeTo"
        }

        # Determine actual version type based on commit content
        if ($versionType -ne "prerelease") {
            $versionTypeInfo = Get-VersionType -Range $range
            $versionType = $versionTypeInfo.Type
        }
    }

    # Update change description based on searchTag
    if (-not $isFirstRelease) {
        $changeDescription = "Changes since " + $searchTag
    }

    # Set up the git log command range
    $range = $rangeTo
    if ($rangeFrom -ne "") {
        $range = "$rangeFrom...$rangeTo"
    }

    # Get commit messages with authors - common logic for all cases
    $commits = git log --pretty=format:"%s ([@%aN](https://github.com/%aN))" --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $range | Sort-Object | Get-Unique

    # Format changelog entry
    $versionChangelog = ""
    if (($versionType -ne "prerelease" -or $isFirstRelease) -and @($commits).Count -gt 0) {
        $versionChangelog = "## $ToTag ($versionType)$lineEnding$lineEnding"
        $versionChangelog += "$($changeDescription):$lineEnding$lineEnding"

        foreach ($commit in $commits) {
            # Filter out version updates and skip CI commits
            if (-not $commit.Contains("Update VERSION to") -and -not $commit.Contains("[skip ci]")) {
                $versionChangelog += "- $commit$lineEnding"
            }
        }
        $versionChangelog += $lineEnding
    }

    return ($versionChangelog.Trim() + $lineEnding)
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

    $lineEnding = Get-GitLineEnding

    # Get all tags
    $tags = Get-GitTags
    $changelog = ""

    # Check if we have any tags at all
    $hasTags = $null -ne $tags -and
              ($tags -is [array] -and $tags.Count -gt 0) -or
              ($tags -is [string] -and $tags.Trim() -ne "")

    # For first release, there's no previous tag to compare against
    $previousTag = 'v0.0.0'

    # If we have tags, find the most recent one to compare against
    if ($hasTags) {
        $previousTag = if ($tags -is [array]) {
            $tags[0]  # Most recent tag
        } else {
            $tags  # Single tag
        }
    }

    # Always add entry for current/new version (comparing current commit to previous tag or initial state)
    $currentTag = "v$Version"
    $versionNotes = Get-VersionNotes -Tags $tags -FromTag $previousTag -ToTag $currentTag -ToSha $CommitHash

    # If we have changes, add them to the changelog
    if (-not [string]::IsNullOrWhiteSpace($versionNotes)) {
        $changelog += $versionNotes
    } else {
        # Handle no changes detected case - add a minimal entry
        $changelog += "## $currentTag$lineEnding$lineEnding"
        $changelog += "Initial release or no significant changes since $previousTag.$lineEnding$lineEnding"
    }

    # Add entries for all previous versions if requested
    if ($IncludeAllVersions -and $hasTags) {
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
    $changelog = $changelog.ReplaceLineEndings($lineEnding)

    [System.IO.File]::WriteAllText($filePath, $changelog, [System.Text.UTF8Encoding]::new($false))

    $versionCount = if ($hasTags) { @($tags).Count + 1 } else { 1 }
    Write-Host "Changelog generated with entries for $versionCount versions"
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
        # Fixed: Now properly includes latest changes
        New-Changelog -Version $version -CommitHash $BuildConfiguration.ReleaseHash

        # Create AUTHORS.md if authors are provided
        if ($Authors.Count -gt 0) {
            Write-Host "Generating authors file..."
            $authorsContent = "# Project Authors$lineEnding$lineEnding"
            foreach ($author in $Authors) {
                $authorsContent += "* $author$lineEnding"
            }
            [System.IO.File]::WriteAllText("AUTHORS.md", $authorsContent, [System.Text.UTF8Encoding]::new($false))
        }

        # Create AUTHORS.url
        $authorsUrl = "[InternetShortcut]$($lineEnding)URL=$($BuildConfiguration.ServerUrl)/$($BuildConfiguration.GitHubOwner)"
        [System.IO.File]::WriteAllText("AUTHORS.url", $authorsUrl, [System.Text.UTF8Encoding]::new($false))

        # Create PROJECT_URL.url
        $projectUrl = "[InternetShortcut]$($lineEnding)URL=$($BuildConfiguration.ServerUrl)/$($BuildConfiguration.GitHubOwner)/$($BuildConfiguration.GitHubRepo)"
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
        Uses the build configuration to determine output paths and version information.
    .PARAMETER Configuration
        The build configuration (Debug/Release). Defaults to "Release".
    .PARAMETER BuildConfiguration
        The build configuration object containing output paths, version, and other settings.
        This object should be obtained from Get-BuildConfiguration.
    .OUTPUTS
        None. Creates published applications and zip archives in the specified output paths.
    #>
    [CmdletBinding()]
    param (
        [string]$Configuration = "Release",
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfiguration
    )

    Write-StepHeader "Publishing Applications"

    # Find all projects
    $projectFiles = @(Get-ChildItem -Recurse -Filter *.csproj -ErrorAction SilentlyContinue)
    if ($projectFiles.Count -eq 0) {
        Write-Host "No .NET application projects found to publish"
        return
    }

    # Clean output directory if it exists
    if (Test-Path $BuildConfiguration.OutputPath) {
        Remove-Item -Recurse -Force $BuildConfiguration.OutputPath
    }

    # Ensure staging directory exists
    New-Item -Path $BuildConfiguration.StagingPath -ItemType Directory -Force | Out-Null

    $publishedCount = 0
    foreach ($csproj in $projectFiles) {
        $projName = [System.IO.Path]::GetFileNameWithoutExtension($csproj)
        $outDir = Join-Path $BuildConfiguration.OutputPath $projName
        $stageFile = Join-Path $BuildConfiguration.StagingPath "$projName-$($BuildConfiguration.Version).zip"

        Write-Host "Publishing $projName..."

        # Create output directory
        New-Item -Path $outDir -ItemType Directory -Force | Out-Null

        # Publish application - stream output directly
        & dotnet publish $csproj --no-build --configuration $Configuration --framework net$($BuildConfiguration.DotnetVersion) --output $outDir  -logger:"Microsoft.Build.Logging.ConsoleLogger,Microsoft.Build;Summary;ForceNoAlign;ShowTimestamp;ShowCommandLine;Verbosity=quiet" | ForEach-Object {
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
        Publishes packages to GitHub Packages and NuGet.org.
        Uses the build configuration to determine package paths and authentication details.
    .PARAMETER BuildConfiguration
        The build configuration object containing package patterns, GitHub token, and NuGet API key.
        This object should be obtained from Get-BuildConfiguration.
    .OUTPUTS
        None. Publishes packages to the configured package repositories.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfiguration
    )

    # Check if there are any packages to publish
    $packages = @(Get-Item -Path $BuildConfiguration.PackagePattern -ErrorAction SilentlyContinue)
    if ($packages.Count -eq 0) {
        Write-Host "No packages found to publish"
        return
    }

    Write-Host "Found $($packages.Count) package(s) to publish"

    Write-StepHeader "Publishing to GitHub Packages"

    # Display the command being run (without revealing the token)
    Write-Host "Running: dotnet nuget push $($BuildConfiguration.PackagePattern) --source https://nuget.pkg.github.com/$($BuildConfiguration.GithubOwner)/index.json --skip-duplicate"

    # Execute the command and stream output
    & dotnet nuget push $BuildConfiguration.PackagePattern --api-key $BuildConfiguration.GithubToken --source "https://nuget.pkg.github.com/$($BuildConfiguration.GithubOwner)/index.json" --skip-duplicate | ForEach-Object {
        Write-Host $_
    }
    Assert-LastExitCode "GitHub package publish failed"

    Write-StepHeader "Publishing to NuGet.org"

    # Display the command being run (without revealing the API key)
    Write-Host "Running: dotnet nuget push $($BuildConfiguration.PackagePattern) --source https://api.nuget.org/v3/index.json --skip-duplicate"

    # Execute the command and stream output
    & dotnet nuget push $BuildConfiguration.PackagePattern --api-key $BuildConfiguration.NuGetApiKey --source "https://api.nuget.org/v3/index.json" --skip-duplicate | ForEach-Object {
        Write-Host $_
    }
    Assert-LastExitCode "NuGet.org package publish failed"
}

function New-GitHubRelease {
    <#
    .SYNOPSIS
        Creates a new GitHub release.
    .DESCRIPTION
        Creates a new GitHub release with the specified version, creates and pushes a git tag,
        and uploads release assets. Uses the GitHub CLI (gh) for release creation.
    .PARAMETER BuildConfiguration
        The build configuration object containing version, commit hash, GitHub token, and asset patterns.
        This object should be obtained from Get-BuildConfiguration.
    .OUTPUTS
        None. Creates a GitHub release and uploads specified assets.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BuildConfiguration
    )

    # Set GitHub token for CLI
    $env:GH_TOKEN = $BuildConfiguration.GithubToken

    # Configure git user
    Set-GitIdentity

    # Create and push the tag first
    Write-Host "Creating and pushing tag v$($BuildConfiguration.Version)..."
    & git tag -a "v$($BuildConfiguration.Version)" $BuildConfiguration.ReleaseHash -m "Release v$($BuildConfiguration.Version)"
    Assert-LastExitCode "Failed to create git tag"

    & git push origin "v$($BuildConfiguration.Version)"
    Assert-LastExitCode "Failed to push git tag"

    # Collect all assets
    $assets = @()
    foreach ($pattern in $BuildConfiguration.AssetPatterns) {
        $matched = Get-Item -Path $pattern -ErrorAction SilentlyContinue
        if ($matched) {
            $assets += $matched.FullName
        }
    }

    # Create release
    Write-StepHeader "Creating GitHub Release v$($BuildConfiguration.Version)"

    $releaseArgs = @(
        "release",
        "create",
        "v$($BuildConfiguration.Version)"
    )

    # Add target commit
    $releaseArgs += "--target"
    $releaseArgs += $BuildConfiguration.ReleaseHash.ToString()

    # Add notes generation
    $releaseArgs += "--generate-notes"

    # Handle changelog content if file exists
    if (Test-Path $BuildConfiguration.ChangelogFile) {
        Write-Host "Using changelog from $($BuildConfiguration.ChangelogFile)"
        $releaseArgs += "--notes-file"
        $releaseArgs += $BuildConfiguration.ChangelogFile
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

        $lineEnding = Get-GitLineEnding
        $fullMessage = "$Message$lineEnding$errorDetails"
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
    $lineEnding = Get-GitLineEnding
    Write-Host "$($lineEnding)=== $Message ===$($lineEnding)" -ForegroundColor Cyan
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
        Determines whether to use LF or CRLF based on the git core.autocrlf and core.eol settings.
        Falls back to system default line ending if no git settings are found.
    .OUTPUTS
        String. Returns either "`n" for LF or "`r`n" for CRLF line endings.
    .NOTES
        The function checks git settings in the following order:
        1. core.eol setting (if set to 'lf' or 'crlf')
        2. core.autocrlf setting ('true', 'input', or 'false')
        3. System default line ending
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
    [OutputType([PSCustomObject])]
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
    [OutputType([PSCustomObject])]
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
            Invoke-DotNetPublish -Configuration $Configuration -BuildConfiguration $BuildConfiguration

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
        if ($packages.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($BuildConfiguration.NuGetApiKey)) {
            Write-StepHeader "Publishing NuGet Packages"
            try {
                Invoke-NuGetPublish -BuildConfiguration $BuildConfiguration
            }
            catch {
                Write-Host "NuGet package publishing failed: $_"
                Write-Host "Continuing with release process."
            }
        }

        # Create GitHub release
        Write-StepHeader "Creating GitHub Release"
        Write-Host "Creating release for version $($BuildConfiguration.Version)..."
        New-GitHubRelease -BuildConfiguration $BuildConfiguration

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
    [OutputType([PSCustomObject])]
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

        $BuildConfiguration.Version = $metadata.Data.Version
        $BuildConfiguration.ReleaseHash = $metadata.Data.ReleaseHash

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
            Version = $metadata.Data.Version
            ReleaseHash = $metadata.Data.ReleaseHash
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
