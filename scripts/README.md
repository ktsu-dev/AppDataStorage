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
$result = Invoke-CIPipeline `
    -GitRef "refs/heads/main" `
    -GitSha "abc123" `
    -WorkspacePath "." `
    -ServerUrl "https://github.com" `
    -Owner "myorg" `
    -Repository "myrepo" `
    -GithubToken $env:GITHUB_TOKEN `
    -NuGetApiKey $env:NUGET_API_KEY `
    -Configuration "Release"

if ($result.Success) {
    Write-Host "Pipeline completed successfully!"
    if ($result.Data.ShouldRelease) {
        Write-Host "Released version: $($result.Data.Version)"
    }
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

## Environment Variables

When running in GitHub Actions, the following environment variables are set:

| Variable | Description |
|----------|-------------|
| VERSION | The current version number |
| LAST_VERSION | The previous version number |
| LAST_VERSION_MAJOR | Previous major version number |
| LAST_VERSION_MINOR | Previous minor version number |
| LAST_VERSION_PATCH | Previous patch version number |
| LAST_VERSION_PRERELEASE | Previous pre-release number |
| IS_PRERELEASE | Whether current version is pre-release |
| VERSION_INCREMENT | Type of version increment performed |
| FIRST_COMMIT | First commit in analyzed range |
| LAST_COMMIT | Last commit in analyzed range |
| RELEASE_HASH | Hash of the metadata commit |

## Advanced Usage

While `Invoke-CIPipeline` handles most use cases, these individual functions are available for advanced scenarios:

### Main Functions
- `Update-ProjectMetadata`: Updates and commits metadata files
- `Invoke-BuildWorkflow`: Runs the build and test process
- `Invoke-ReleaseWorkflow`: Handles package creation and publishing

### Utility Functions
- `Assert-LastExitCode`: Verifies command execution success
- `Write-StepHeader`: Creates formatted step headers in logs
- `Test-AnyFiles`: Tests for existence of files matching a pattern
- `Get-GitLineEnding`: Determines correct line endings based on git config

## Line Ending Handling

The module respects git's line ending settings when generating files:

- Uses git's `core.eol` setting if defined
- Falls back to `core.autocrlf` setting
- Defaults to OS-specific line endings if no git settings are found

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes with appropriate version tags
4. Create a pull request

## License

MIT License - See LICENSE.md for details
