# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```powershell
# Restore, build, and test (standard workflow)
dotnet restore
dotnet build
dotnet test

# Run a single test
dotnet test --filter "FullyQualifiedName~TestMethodName"

# Build specific configuration
dotnet build -c Release
```

## Project Structure

This is a .NET library (`ktsu.AppDataStorage`) for persistent application data storage with JSON serialization. The solution uses:

- **ktsu.Sdk** - Custom SDK providing shared build configuration
- **MSTest.Sdk** - Test project SDK with Microsoft Testing Platform
- Multi-targeting: net10.0, net9.0, net8.0, net7.0, netstandard2.0, netstandard2.1

### Key Files

- `AppDataStorage/AppData.cs` - Single source file containing all library code:
  - `AppData` static class - Helper methods for file operations, JSON serialization config
  - `AppData<T>` generic abstract class - Base class for app data types with save/load functionality

### Dependencies

- `System.IO.Abstractions` - File system abstraction for testability
- `ktsu.Semantics.Paths` - Strongly-typed path classes (`AbsoluteFilePath`, `RelativeDirectoryPath`, `FileName`)
- `ktsu.CaseConverter` - Snake_case conversion for file naming
- `ktsu.RoundTripStringJsonConverter` - JSON serialization support
- `Polyfill` - Provides `Ensure` class for argument validation (e.g., `Ensure.NotNull()`)

## Architecture

### Usage Pattern

Users create a class inheriting from `AppData<T>` to store application settings:

```csharp
public class MyAppData : AppData<MyAppData>
{
    public string Setting { get; set; } = "default";
}

// Load or create, then use static accessor
var data = MyAppData.LoadOrCreate();
var same = MyAppData.Get(); // Singleton-like access
data.Save();
```

### Key Implementation Details

- Files stored in `%APPDATA%/{AppDomain.FriendlyName}/` as `{class_name_snake_case}.json`
- Thread-safe with lock objects (uses `Lock` type on .NET 9+, `object` on earlier versions)
- Debounced saves via `QueueSave()` / `SaveIfRequired()` (3-second debounce)
- Automatic backup files (`.bk` suffix) with timestamped collision handling
- Safe write pattern: write to `.tmp`, backup existing, move `.tmp` to final

### Testing

Tests use `MockFileSystem` from `System.IO.Abstractions.TestingHelpers`:

```csharp
AppData.ConfigureForTesting(() => new MockFileSystem());
// ... run tests ...
AppData.ResetFileSystem(); // Cleanup
```

## CI/CD

Uses `scripts/PSBuild.psm1` PowerShell module for CI pipeline. Version increments are controlled by commit message tags: `[major]`, `[minor]`, `[patch]`, `[pre]`.

## Code Quality

Do not add global suppressions for warnings. Use explicit suppression attributes with justifications when needed, with preprocessor defines only as fallback. Make the smallest, most targeted suppressions possible.
