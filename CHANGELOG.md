## v1.5.0 (minor)

Changes since v1.4.0:

- Add changelog entry for changes since the specified tag in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))
- Add logging for note generation in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))
- Apply new editorconfig ([@matt-edmondson](https://github.com/matt-edmondson))
- Don't serialise the lock member ([@Damon3000s](https://github.com/Damon3000s))
- Enhance changelog formatting by adding additional line breaks for improved readability ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix typo in variable name and remove unnecessary logging in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix typo in variable name in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor version type checks in MakeNotesForRange function and add exclusion for PowerShell files in make-version.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.6 (patch)

Changes since v1.4.5:

- Fix typo in variable name in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.5 (patch)

Changes since v1.4.4:

- Fix typo in variable name and remove unnecessary logging in make-changelog.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.4 (patch)

Changes since v1.4.3:

- Enhance changelog formatting by adding additional line breaks for improved readability ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.3 (patch)

Changes since v1.4.2:

- Add logging for note generation in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.2 (patch)

Changes since v1.4.1:

- Add changelog entry for changes since the specified tag in MakeNotesForRange function ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.1 (patch)

Changes since v1.4.0:

- Refactor version type checks in MakeNotesForRange function and add exclusion for PowerShell files in make-version.ps1 ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.4.0 (minor)

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

## v1.3.16 (patch)

Changes since v1.3.15:

- Fix syntax error in make-license.ps1 command in dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Modularize PowerShell scripts in dotnet.yml ([@matt-edmondson](https://github.com/matt-edmondson))
- Update .mailmap for user and bot email consistency ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.15 (patch)

Changes since v1.3.14:

- Move IS_PRERELEASE assignment to where its actually gonna work ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.14 (patch)

Changes since v1.3.13-pre.1:

- Refactor bot commit exclusion patterns in dotnet workflow for improved clarity and case-insensitivity ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.5 (patch)

Changes since v1.3.4:

- Fix license ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.4 (patch)

Changes since v1.3.3:

- Replace LICENSE file with LICENSE.md ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.1 (patch)

Changes since v1.3.0:

- Update .NET workflow to trigger on main and develop branches ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.3.0 (minor)

Changes since v1.2.0:

- Refactor AppData to use Lazy<T> for internal state ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.2.0 (minor)

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

## v1.1.45 (patch)

Changes since v1.1.44:

- Add new tests and update namespace in AppDataTests.cs ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppData functionality and documentation ([@matt-edmondson](https://github.com/matt-edmondson))
- Enhance AppDataStorage docs and add new examples ([@matt-edmondson](https://github.com/matt-edmondson))
- Update README with Static Instance Access feature ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.43 (patch)

Changes since v1.1.42:

- Add GitHub Actions workflow to automate issue and PR management for ktsu.dev project ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.40 (patch)

Changes since v1.1.39:

- Update dependencies ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.34 (patch)

Changes since v1.1.33:

- Make test classes and records public; update NoWarn property ([@matt-edmondson](https://github.com/matt-edmondson))
- Refactor visibility and enhance type conversion ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.1.3 (minor)

Changes since v1.0.0:

- Add reading and writing to arbitrary files within the app directory ([@matt-edmondson](https://github.com/matt-edmondson))
- Fix a crash on first launch if you dont have the app data directory ([@matt-edmondson](https://github.com/matt-edmondson))
- Migrate ktsu.io to ktsu namespace ([@matt-edmondson](https://github.com/matt-edmondson))
- Take latest StrongPaths ([@matt-edmondson](https://github.com/matt-edmondson))
- Update VERSION ([@matt-edmondson](https://github.com/matt-edmondson))

## v1.0.0 (major)

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


