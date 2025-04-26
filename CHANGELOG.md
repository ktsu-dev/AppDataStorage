## v1.8.0 (System.Collections.Hashtable)

Changes since v1.7.0:

- Add global.json for SDK configuration and update project files to use ktsu SDKs ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance changelog and versioning logic in PowerShell scripts. Added checks for non-merge commits, code changes, and commit message tags to determine version type (major, minor, patch, prerelease) for changelog generation. Updated `make-version.ps1` to streamline version increment logic based on commit presence and tags. ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance Dependabot workflow by adding a timeout and improving logging for PR processing. Updated the step names for clarity and ensured proper handling of PR URLs during auto-merge operations. ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance Get-BuildConfiguration function in PSBuild module by adding detailed logging of build configuration parameters. This update improves visibility of repository status, build settings, paths, and artifact patterns, aiding in CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance Invoke-DotNetBuild function with improved logging and error handling. Added explicit logger parameters for CI output, implemented a retry mechanism with detailed verbosity on build failures, and included checks for project files to assist in diagnosing build issues. This update aims to streamline the build process and provide clearer feedback during CI/CD operations. ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance Invoke-DotNetPack and Invoke-ReleaseWorkflow functions to support project-specific packaging and improved error handling. Added parameters for verbosity and project selection, along with checks for project existence before packaging. Updated release workflow to conditionally skip packaging and improved logging for package creation and publishing steps. ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance PSBuild module with improved version analysis and logging. Updated Get-VersionType function to provide detailed reasoning for version increments based on commit analysis. Enhanced output for version information retrieval and streamlined command execution in various functions for better visibility during CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Improved handling of .csx file detection and enhanced tag retrieval logic to ensure proper array handling. Updated changelog generation to accommodate various tag scenarios, ensuring robust versioning checks. ([@matt-edmondson](https://github.com/matt-edmondson))
- Readd icon ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor .NET CI workflow and introduce PSBuild module for enhanced build automation. Updated GitHub Actions to streamline build, test, and release processes, including improved job naming, permissions, and environment variable management. Removed outdated PowerShell scripts for metadata handling and version management, replacing them with a comprehensive PSBuild module that supports semantic versioning, license generation, and CI/CD integration. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor .NET CI workflow to enhance build and release processes. Updated job names for clarity, improved error handling in PowerShell scripts, and added caching for NuGet packages. Introduced a new release job that packages and publishes libraries, applications, and generates release notes. Adjusted permissions and environment variables for better security and functionality. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor Assert-LastExitCode calls in Invoke-DotNetRestore, Invoke-DotNetBuild, and Invoke-DotNetTest functions of PSBuild module to remove unnecessary command parameter. This change simplifies the error handling logic while maintaining clarity in logging. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor console logger parameters in Invoke-DotNetBuild, Invoke-DotNetTest, and Invoke-DotNetPack functions of PSBuild module to use a standardized format. This change enhances clarity and consistency in CI output by utilizing the Microsoft.Build.Logging.ConsoleLogger for improved logging detail. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor Invoke-ReleaseWorkflow and Invoke-CIPipeline functions to ensure GitSha and WorkspacePath parameters are validated for null or empty values. Updated version information retrieval to convert GitSha to string for consistency in metadata updates. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor New-Changelog function in PSBuild module to improve tag handling by using array count for better clarity. Updated console output message to reflect the change, enhancing consistency in versioning processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor PowerShell scripts for version management and metadata handling. Introduced a common module for shared functions, streamlined git configuration, and improved commit metadata processing. Updated `make-changelog.ps1` and `make-version.ps1` to utilize new functions for determining version types and managing environment variables. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor project file detection in Invoke-ReleaseWorkflow function to improve accuracy. Updated the check for .csproj files to count existing projects instead of relying on Test-Path, enhancing the robustness of the packaging process. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor PSBuild functions to execute .NET commands with output directed to the console for better logging in GitHub Actions. Updated Invoke-DotNetRestore, Invoke-DotNetBuild, Invoke-DotNetTest, Invoke-DotNetPack, Invoke-DotNetPublish, and Invoke-NuGetPublish functions to use the call operator for command execution, enhancing visibility of command outputs and error handling. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor PSBuild module to standardize dotnet command logging. Updated logger parameters for restore, build, test, pack, and publish functions to improve output consistency and clarity in CI/CD environments. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor Update-ProjectMetadata function in PSBuild module to replace Version and CommitHash parameters with GitSha and ServerUrl. Update metadata generation process to return a hashtable containing version and release hash, enhancing clarity and consistency in CI/CD workflows. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refine console logger parameters in Invoke-DotNetRestore function of PSBuild module by removing 'Summary' from verbosity settings. This change improves output clarity and maintains consistency with previous logging updates in CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Refine console logger parameters in Invoke-DotNetRestore function of PSBuild module. Updated parameters to enhance output clarity by removing unnecessary options and standardizing verbosity settings for improved consistency in CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Remove Directory.Build.props and Directory.Build.targets files to streamline project configuration and eliminate unused properties. ([@matt-edmondson](https://github.com/matt-edmondson))
- Remove icon to fix lfs ([@matt-edmondson](https://github.com/matt-edmondson))
- Remove metadata update step from the release workflow in PSBuild module to streamline the process. ([@matt-edmondson](https://github.com/matt-edmondson))
- Remove unnecessary --no-logo option from dotnet restore command in PSBuild module for cleaner output. This change maintains consistency with previous updates to console logger parameters. ([@matt-edmondson](https://github.com/matt-edmondson))
- Replace Write-Output with Write-Host in PSBuild module for improved console logging consistency. This change enhances the clarity of output messages during build and versioning processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Standardize console logger parameters in Invoke-DotNetBuild and Invoke-DotNetTest functions of PSBuild module to use quotes for improved clarity and consistency in CI output. ([@matt-edmondson](https://github.com/matt-edmondson))
- Standardize console logger parameters in PSBuild module for build, test, and pack functions. Updated verbosity settings to use 'Summary' for improved output clarity and consistency across CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Standardize console logger parameters in PSBuild module for dotnet commands. Updated restore, pack, and publish functions to use the /p:ConsoleLoggerParameters syntax for improved clarity and consistency in output across CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Standardize console logger parameters in PSBuild module for dotnet commands. Updated restore, test, pack, and publish functions to include ForceNoAlign and ShowTimestamp options, enhancing output clarity and consistency in CI/CD environments. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update .editorconfig to include additional file types and formatting rules ([@matt-edmondson](https://github.com/matt-edmondson))
- Update AUTHORS.md handling in PSBuild module to preserve existing file and improve metadata generation logic. The script now ensures that the AUTHORS.md file is only generated if it does not already exist, while also enhancing documentation for metadata updates. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update console logger parameters in Invoke-DotNetRestore function of PSBuild module to use 'Summary' instead of 'ShowTimestamp'. This change enhances output clarity and maintains consistency with previous updates to logging settings in CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update console logger parameters in Invoke-DotNetRestore function of PSBuild module to use a standardized format. This change improves logging detail and consistency in CI output by utilizing the Microsoft.Build.Logging.ConsoleLogger. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update GitHub Actions workflow to enhance project automation. Added permissions for managing repository contents and pull requests, introduced a timeout for the add-to-project job, and improved step naming for clarity. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update GitHub release function in PSBuild module to use GitSha instead of metadata.ReleaseHash for improved accuracy in release tracking. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update packages ([@matt-edmondson](https://github.com/matt-edmondson))
- Update PSBuild module to enhance logging verbosity for dotnet commands. Added console logger parameters for improved output during restore, build, test, pack, and publish operations, ensuring better visibility in CI/CD processes. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update PSBuild module with enhanced documentation, improved error handling, and refined function exports. Added detailed usage instructions and author information, updated command execution for better error reporting, and improved parameter descriptions for clarity. This refactor aims to streamline the CI/CD pipeline process for .NET applications. ([@matt-edmondson](https://github.com/matt-edmondson))
- Update README with improved documentation and API reference ([@matt-edmondson](https://github.com/matt-edmondson))
- Update version component checks in PSBuild module to use array count for improved clarity and consistency. This change enhances the handling of versioning and changelog generation processes. ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.7.2 (System.Collections.Hashtable)

Changes since v1.7.1:

- Update .editorconfig to include additional file types and formatting rules ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.7.1 (System.Collections.Hashtable)

Changes since v1.7.0:

- Update packages ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.7.0 (System.Collections.Hashtable)

Changes since v1.6.0:

- Refactor AppData locking mechanism and improve README ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.6.0 (System.Collections.Hashtable)

Changes since v1.5.0:

- Add LICENSE template ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.5.0 (System.Collections.Hashtable)

Changes since v1.4.0:

- Add changelog entry for changes since the specified tag in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))
- Add logging for note generation in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))
- Apply new editorconfig ([@matt-edmondson](https://github.com/matt-edmondson))
- Don't serialise the lock member ([@Damon3000s](https://github.com/Damon3000s))
- Enhance changelog formatting by adding additional line breaks for improved readability ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix typo in variable name and remove unnecessary logging in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix typo in variable name in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor version type checks in MakeNotesForRange function and add exclusion for PowerShell files in make-version.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.6 (System.Collections.Hashtable)

Changes since v1.4.5:

- Fix typo in variable name in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.5 (System.Collections.Hashtable)

Changes since v1.4.4:

- Fix typo in variable name and remove unnecessary logging in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.4 (System.Collections.Hashtable)

Changes since v1.4.3:

- Enhance changelog formatting by adding additional line breaks for improved readability ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.3 (System.Collections.Hashtable)

Changes since v1.4.2:

- Add logging for note generation in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.2 (System.Collections.Hashtable)

Changes since v1.4.1:

- Add changelog entry for changes since the specified tag in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.1 (System.Collections.Hashtable)

Changes since v1.4.0:

- Refactor version type checks in MakeNotesForRange function and add exclusion for PowerShell files in make-version.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.0 (System.Collections.Hashtable)

Changes since v1.3.0:

- Add VERSION_TYPE variable to MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix license ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix range check in MakeNotesForRange function to handle additional version format ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix regex for bot commit exclusion patterns in dotnet workflow ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix syntax error in make-license.ps1 command in dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Modularize PowerShell scripts in dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Move IS_PRERELEASE assignment to where its actually gonna work ([@matt-edmondson](https://github.com/matt-edmondson))
- Move shared workflow into local workflow ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor bot commit exclusion patterns in dotnet workflow for case-insensitivity ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor bot commit exclusion patterns in dotnet workflow for improved clarity and case-insensitivity ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor exclusion patterns in dotnet workflow for improved clarity and consistency ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor exclusion patterns in dotnet workflow to simplify bot commit filtering ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor scripts and update workflow parameters ([@matt-edmondson](https://github.com/matt-edmondson))
- Remove URL escaping from workflow and adjust environment variable output ([@matt-edmondson](https://github.com/matt-edmondson))
- Renamed metadata files ([@matt-edmondson](https://github.com/matt-edmondson))
- Replace LICENSE file with LICENSE.md ([@matt-edmondson](https://github.com/matt-edmondson))
- Sort git tags when retrieving the last released version in dotnet workflow ([@matt-edmondson](https://github.com/matt-edmondson))
- Update .mailmap for user and bot email consistency ([@matt-edmondson](https://github.com/matt-edmondson))
- Update .NET workflow to trigger on main and develop branches ([@matt-edmondson](https://github.com/matt-edmondson))
- Update exclusion pattern for hidden files in dotnet workflow ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.16 (System.Collections.Hashtable)

Changes since v1.3.15:

- Fix syntax error in make-license.ps1 command in dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Modularize PowerShell scripts in dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Update .mailmap for user and bot email consistency ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.15 (System.Collections.Hashtable)

Changes since v1.3.14:

- Move IS_PRERELEASE assignment to where its actually gonna work ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.14 (System.Collections.Hashtable)

Changes since v1.3.13-pre.1:

- Refactor bot commit exclusion patterns in dotnet workflow for improved clarity and case-insensitivity ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.5 (System.Collections.Hashtable)

Changes since v1.3.4:

- Fix license ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.4 (System.Collections.Hashtable)

Changes since v1.3.3:

- Replace LICENSE file with LICENSE.md ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.1 (System.Collections.Hashtable)

Changes since v1.3.0:

- Update .NET workflow to trigger on main and develop branches ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.0 (System.Collections.Hashtable)

Changes since v1.2.0:

- Refactor AppData to use Lazy<T> for internal state ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.2.0 (System.Collections.Hashtable)

Changes since 1.1.0:

- Add compatibility suppressions and update build properties ([@matt-edmondson](https://github.com/matt-edmondson))
- Add comprehensive tests for AppData methods ([@matt-edmondson](https://github.com/matt-edmondson))
- Add GitHub Actions workflow to automate issue and PR management for ktsu.dev project ([@matt-edmondson](https://github.com/matt-edmondson))
- Add new tests and update namespace in AppDataTests.cs ([@matt-edmondson](https://github.com/matt-edmondson))
- Add new tests for StrongName and Storage classes ([@matt-edmondson](https://github.com/matt-edmondson))
- dotnet-pipeline.yml renamed to dotnet-workflow.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppData functionality and documentation ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppDataStorage docs and add new examples ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppDataTests with new tests and improvements ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix a crash on first launch if you dont have the app data directory ([@matt-edmondson](https://github.com/matt-edmondson))
- Make test classes and records public; update NoWarn property ([@matt-edmondson](https://github.com/matt-edmondson))
- Migrate ktsu.io to ktsu namespace ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor AppData class for robustness and flexibility ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor tests and add null checks for deserialized data ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor TestStrongStrings for proper resource disposal ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor visibility and enhance type conversion ([@matt-edmondson](https://github.com/matt-edmondson))
- Take latest StrongPaths ([@matt-edmondson](https://github.com/matt-edmondson))
- Update dependencies ([@matt-edmondson](https://github.com/matt-edmondson))
- Update GitHub Action version in add-to-project job ([@matt-edmondson](https://github.com/matt-edmondson))
- Update MSTest.TestFramework to version 3.7.0 ([@matt-edmondson](https://github.com/matt-edmondson))
- Update project to target both .NET 8.0 and .NET 9.0 ([@matt-edmondson](https://github.com/matt-edmondson))
- Update README with Static Instance Access feature ([@matt-edmondson](https://github.com/matt-edmondson))
- Update VERSION ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.45 (System.Collections.Hashtable)

Changes since v1.1.44:

- Add new tests and update namespace in AppDataTests.cs ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppData functionality and documentation ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppDataStorage docs and add new examples ([@matt-edmondson](https://github.com/matt-edmondson))
- Update README with Static Instance Access feature ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.43 (System.Collections.Hashtable)

Changes since v1.1.42:

- Add GitHub Actions workflow to automate issue and PR management for ktsu.dev project ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.40 (System.Collections.Hashtable)

Changes since v1.1.39:

- Update dependencies ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.34 (System.Collections.Hashtable)

Changes since v1.1.33:

- Make test classes and records public; update NoWarn property ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor visibility and enhance type conversion ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.3 (System.Collections.Hashtable)

Changes since v1.0.0:

- Add reading and writing to arbitrary files within the app directory ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix a crash on first launch if you dont have the app data directory ([@matt-edmondson](https://github.com/matt-edmondson))
- Migrate ktsu.io to ktsu namespace ([@matt-edmondson](https://github.com/matt-edmondson))
- Take latest StrongPaths ([@matt-edmondson](https://github.com/matt-edmondson))
- Update VERSION ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.0.0 (System.Collections.Hashtable)

Changes since 0.0.0.0:

- Add github package support ([@matt-edmondson](https://github.com/matt-edmondson))
- Add stringify convertor and update strong strings ([@matt-edmondson](https://github.com/matt-edmondson))
- Add tests ([@matt-edmondson](https://github.com/matt-edmondson))
- Added readme content ([@matt-edmondson](https://github.com/matt-edmondson))
- Alpha 1 ([@matt-edmondson](https://github.com/matt-edmondson))
- Assign dependabot PRs to matt ([@matt-edmondson](https://github.com/matt-edmondson))
- Avoid double upload of symbols package ([@matt-edmondson](https://github.com/matt-edmondson))
- Bump to version 1.0.0-alpha.10 ([@matt-edmondson](https://github.com/matt-edmondson))
- Bump version to 1.0.0-alpha.2 and add a package description ([@matt-edmondson](https://github.com/matt-edmondson))
- Bump version to 1.0.0-alpha.9 ([@matt-edmondson](https://github.com/matt-edmondson))
- Create dependabot-merge.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Create VERSION ([@matt-edmondson](https://github.com/matt-edmondson))
- Disable SourceLink in project settings ([@matt-edmondson](https://github.com/matt-edmondson))
- Dont try to push packages when building pull requests ([@matt-edmondson](https://github.com/matt-edmondson))
- dotnet 8 ([@matt-edmondson](https://github.com/matt-edmondson))
- Enable dependabot and sourcelink ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhanced testing with mock file systems ([@matt-edmondson](https://github.com/matt-edmondson))
- Ensure appdata path exists before tests run ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix a bug where the serializer would never serialize anything, because it was missing the derived typeinfo ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix an issue where the application domain was being truncated if it was inside a namespace. Add a package description. Attempt to include source and symbols in the nuget to help with debugging. ([@matt-edmondson](https://github.com/matt-edmondson))
- Initial commit - non working ([@matt-edmondson](https://github.com/matt-edmondson))
- Migrate from .project.props to Directory.Build.props ([@matt-edmondson](https://github.com/matt-edmondson))
- Read from AUTHORS file during build ([@matt-edmondson](https://github.com/matt-edmondson))
- Read from VERSION when building ([@matt-edmondson](https://github.com/matt-edmondson))
- Read PackageDescription from DESCRIPTION file ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor AppData<T> deserialization ([@matt-edmondson](https://github.com/matt-edmondson))
- Take latest StringifyJsonConvertorFactory ([@matt-edmondson](https://github.com/matt-edmondson))
- Take latest StrongPaths ([@matt-edmondson](https://github.com/matt-edmondson))
- Take latest StrongPaths to get a bugfix ([@matt-edmondson](https://github.com/matt-edmondson))
- Update build config ([@matt-edmondson](https://github.com/matt-edmondson))
- Update Directory.Build.props ([@matt-edmondson](https://github.com/matt-edmondson))
- Update Directory.Build.targets ([@matt-edmondson](https://github.com/matt-edmondson))
- Update docs and stabilize library version ([@matt-edmondson](https://github.com/matt-edmondson))
- Update dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Update JSON conversion strategy in AppData ([@matt-edmondson](https://github.com/matt-edmondson))
- Update LICENSE ([@matt-edmondson](https://github.com/matt-edmondson))
- Update nuget.config ([@matt-edmondson](https://github.com/matt-edmondson))
- Update ToStringJsonConverter to 1.0.0 ([@matt-edmondson](https://github.com/matt-edmondson))


