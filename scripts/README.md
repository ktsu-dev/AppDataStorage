# PSBuild PowerShell Module

A comprehensive PowerShell module for building, testing, packaging, and releasing .NET applications.

## Features

- Environment setup and configuration
- Semantic versioning with Git history analysis
- License and changelog generation
- Automated metadata management
- Build, test, and package .NET applications
- NuGet package publishing
- GitHub release creation
- Complete CI/CD pipeline

## Usage

### Basic Usage

```powershell
# Import the module
Import-Module ./PSBuild.psm1

# Initialize the build environment
Initialize-BuildEnvironment

# Get the build configuration
$config = Get-BuildConfiguration -GitRef "refs/heads/main" -GitSha "abc123" -WorkspacePath "C:/projects/myapp" -GithubToken $env:GITHUB_TOKEN

# Run the build workflow
Invoke-BuildWorkflow -BuildConfig $config
```

### Version Management

```powershell
# Get comprehensive version information from Git history
$versionInfo = Get-VersionInfoFromGit -CommitHash "abc123"

# Access version information
Write-Host "New version: $($versionInfo.Version)"
Write-Host "Previous version: $($versionInfo.LastVersion)"
Write-Host "Version increment type: $($versionInfo.VersionIncrement)"

# Generate version file and set environment variables
$version = New-Version -CommitHash "abc123"
```

### Metadata Management

```powershell
# Update and commit all metadata files (comprehensive approach)
$releaseHash = Update-ProjectMetadata `
  -Version "1.2.3" `
  -CommitHash "abc123" `
  -GitHubOwner "myorg" `
  -GitHubRepo "myrepo" `
  -ServerUrl "https://github.com"

# Individual metadata operations
# Create just a license file
New-License -ServerUrl "https://github.com" -Owner "myorg" -Repository "myrepo"

# Create just a changelog
New-Changelog -Version "1.2.3" -CommitHash "abc123"
```

### Complete CI/CD Pipeline

```powershell
# Run the entire CI/CD pipeline
$result = Invoke-CIPipeline `
  -GitRef "refs/heads/main" `
  -GitSha "abc123" `
  -WorkspacePath "C:/projects/myapp" `
  -ServerUrl "https://github.com" `
  -Owner "myorg" `
  -Repository "myrepo" `
  -GithubToken $env:GITHUB_TOKEN `
  -NuGetApiKey $env:NUGET_API_KEY

# Check the result
if ($result.BuildSuccess) {
    Write-Host "Build successful!"
    if ($result.ReleaseSuccess) {
        Write-Host "Release successful! Version: $($result.Version)"
    }
}
```

### Key Functions

The module provides many individual functions that can be used separately:

- **Version Management**
  - `Get-VersionInfoFromGit` - Gets comprehensive version information based on Git history
  - `Get-VersionType` - Determines the type of version increment based on commit history
  - `New-Version` - Generates a version file and sets environment variables

- **Metadata Management**
  - `Update-ProjectMetadata` - Updates and commits all metadata files
  - `New-License` - Creates a license file
  - `New-Changelog` - Generates a changelog from Git commits

- **.NET Operations**
  - `Invoke-DotNetRestore` - Restores NuGet packages
  - `Invoke-DotNetBuild` - Builds the .NET solution
  - `Invoke-DotNetTest` - Runs unit tests with coverage
  - `Invoke-DotNetPack` - Creates NuGet packages
  - `Invoke-DotNetPublish` - Publishes applications and creates zip archives

- **Publishing and Release**
  - `Invoke-NuGetPublish` - Publishes packages to NuGet feeds
  - `New-GitHubRelease` - Creates a GitHub release

## Workflow Integration

This module can be used in any CI/CD system, including GitHub Actions, by importing it in your PowerShell scripts.

For GitHub Actions, you can use it like this:

```yaml
- name: Run Build
  shell: pwsh
  run: |
    Import-Module ./scripts/PSBuild.psm1

    # Get build configuration
    $config = Get-BuildConfiguration -GitRef "${{ github.ref }}" -GitSha "${{ github.sha }}" -WorkspacePath "${{ github.workspace }}" -GithubToken "${{ github.token }}"

    # Run build workflow
    $buildResult = Invoke-BuildWorkflow -BuildConfig $config

    # Generate version and metadata if releasing
    if ($config.ShouldRelease) {
        $versionInfo = Get-VersionInfoFromGit -CommitHash "${{ github.sha }}"
        $releaseHash = Update-ProjectMetadata -Version $versionInfo.Version -CommitHash "${{ github.sha }}" -GitHubOwner "${{ github.repository_owner }}" -GitHubRepo "${{ github.repository }}"
    }
```

## Requirements

- PowerShell 5.1 or higher
- .NET SDK
- Git
- GitHub CLI (for release creation)
