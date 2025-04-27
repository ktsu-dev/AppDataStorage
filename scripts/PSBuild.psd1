@{
    # Module information
    RootModule = 'PSBuild.psm1'
    ModuleVersion = '1.0.0'
    GUID = '0b0a2f0e-3b3a-4c0b-8d0a-9b0b0b0b0b0b'  # Generate a unique GUID for your module
    Author = 'ktsu.dev'
    CompanyName = 'ktsu.dev'
    Copyright = '(c) ktsu.dev All rights reserved.'
    Description = 'A comprehensive build module for .NET projects'

    # PowerShell version required
    PowerShellVersion = '5.1'

    # Functions to export
    FunctionsToExport = @(
        'Initialize-BuildEnvironment',
        'Get-BuildConfiguration',
        'Get-GitTags',
        'Get-VersionType',
        'Get-VersionInfoFromGit',
        'New-Version',
        'ConvertTo-FourComponentVersion',
        'Get-VersionNotes',
        'New-Changelog',
        'Update-ProjectMetadata',
        'New-License',
        'Invoke-DotNetRestore',
        'Invoke-DotNetBuild',
        'Invoke-DotNetTest',
        'Invoke-DotNetPack',
        'Invoke-DotNetPublish',
        'Invoke-NuGetPublish',
        'New-GitHubRelease',
        'Assert-LastExitCode',
        'Write-StepHeader',
        'Test-AnyFiles',
        'Get-GitLineEnding',
        'Set-GitIdentity',
        'Invoke-BuildWorkflow',
        'Invoke-ReleaseWorkflow',
        'Invoke-CIPipeline'
    )

    # Variables to export
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport = @()

    # Tags for PowerShell Gallery
    PrivateData = @{
        PSData = @{
            Tags = @('build', 'dotnet', 'ci', 'cd', 'nuget', 'github')
            LicenseUri = 'https://github.com/ktsu-dev/PSBuild/blob/main/LICENSE.md'
            ProjectUri = 'https://github.com/ktsu-dev/PSBuild'
            ReleaseNotes = 'Initial release'
        }
    }
}
