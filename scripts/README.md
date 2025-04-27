# PSBuild Module

A comprehensive PowerShell module for automating the build, test, package, and release process for .NET applications using Git-based versioning.

## Features

- Semantic versioning based on git history and commit messages
- Automatic version calculation from commit analysis
- Metadata file generation and management
- Comprehensive build, test, and package pipeline
- NuGet package creation and publishing
- GitHub release creation with assets
- Proper line ending handling based on git config
- Robust version string handling with automatic whitespace trimming

## Installation

1. Copy the `PSBuild.psm1` file to your project's `scripts` directory
2. Import the module in your PowerShell session:
   ```powershell
   Import-Module ./scripts/PSBuild.psm1
   ```

## Usage

The main entry point is `Invoke-CIPipeline`, which handles the complete build, test, package, and release process:

```powershell
# First, get the build configuration
$buildConfig = Get-BuildConfiguration `
    -ServerUrl "https://github.com" `
    -GitRef "refs/heads/main" `
    -GitSha "abc123" `
    -GitHubOwner "myorg" `
    -GitHubRepo "myrepo" `
    -GithubToken $env:GITHUB_TOKEN `
    -NuGetApiKey $env:NUGET_API_KEY `
    -WorkspacePath "." `
    -ExpectedOwner "myorg" `
    -ChangelogFile "CHANGELOG.md" `
    -AssetPatterns @("staging/*.nupkg", "staging/*.zip")

# Then run the pipeline
$result = Invoke-CIPipeline -BuildConfiguration $buildConfig

if ($result.Success) {
    Write-Host "Pipeline completed successfully!"
    Write-Host "Version: $($result.Version)"
    Write-Host "Release Hash: $($result.ReleaseHash)"
}
```

## Managed Files

The module manages several metadata files in your repository:

| File | Description |
|------|-------------|
| VERSION.md | Contains the current semantic version |
| LICENSE.md | MIT license with project URL and copyright |
| COPYRIGHT.md | Copyright notice with year range and owner |
| AUTHORS.md | List of contributors from git history |
| CHANGELOG.md | Auto-generated changelog from git history |
| PROJECT_URL.url | Link to project repository |
| AUTHORS.url | Link to organization/owner |

## Version Control

### Version Tags

Commits can include the following tags to control version increments:

| Tag | Description | Example |
|-----|-------------|---------|
| [major] | Triggers a major version increment | 2.0.0 |
| [minor] | Triggers a minor version increment | 1.2.0 |
| [patch] | Triggers a patch version increment | 1.1.2 |
| [pre] | Creates/increments pre-release version | 1.1.2-pre.1 |

### Automatic Version Calculation

The module analyzes commit history to determine appropriate version increments:

1. Checks for explicit version tags in commit messages
2. Analyzes code changes vs. documentation changes
3. Considers the scope and impact of changes
4. Maintains semantic versioning principles

## Build Configuration

The `Get-BuildConfiguration` function returns a configuration object with the following key properties:

| Property | Description |
|----------|-------------|
| IsOfficial | Whether this is an official repository build |
| IsMain | Whether building from main branch |
| IsTagged | Whether the current commit is tagged |
| ShouldRelease | Whether a release should be created |
| UseDotnetScript | Whether .NET script files are present |
| OutputPath | Path for build outputs |
| StagingPath | Path for staging artifacts |
| PackagePattern | Pattern for NuGet packages |
| SymbolsPattern | Pattern for symbol packages |
| ApplicationPattern | Pattern for application archives |
| Version | Current version number |
| ReleaseHash | Hash of the release commit |

## Advanced Usage

The module provides several functions for advanced scenarios:

### Build and Release Functions
- `Initialize-BuildEnvironment`: Sets up the build environment
- `Get-BuildConfiguration`: Creates the build configuration object
- `Invoke-BuildWorkflow`: Runs the build and test process
- `Invoke-ReleaseWorkflow`: Handles package creation and publishing

### Version Management Functions
- `Get-GitTags`: Gets sorted list of version tags
- `Get-VersionType`: Determines version increment type
- `Get-VersionInfoFromGit`: Gets comprehensive version information
- `New-Version`: Creates a new version file

### Package and Release Functions
- `Invoke-DotNetRestore`: Restores NuGet packages
- `Invoke-DotNetBuild`: Builds the solution
- `Invoke-DotNetTest`: Runs unit tests with coverage
- `Invoke-DotNetPack`: Creates NuGet packages
- `Invoke-DotNetPublish`: Publishes applications
- `Invoke-NuGetPublish`: Publishes packages to repositories
- `New-GitHubRelease`: Creates GitHub release with assets

### Utility Functions
- `Assert-LastExitCode`: Verifies command execution success
- `Write-StepHeader`: Creates formatted step headers in logs
- `Test-AnyFiles`: Tests for existence of files matching a pattern
- `Get-GitLineEnding`: Determines correct line endings based on git config
- `Set-GitIdentity`: Configures git user identity for automated operations

## Line Ending Handling

The module respects git's line ending settings when generating files:

1. Uses git's `core.eol` setting if defined
2. Falls back to `core.autocrlf` setting
3. Defaults to OS-specific line endings if no git settings are found

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes with appropriate version tags
4. Create a pull request

## License

MIT License - See LICENSE.md for details
