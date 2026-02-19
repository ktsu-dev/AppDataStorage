# ktsu.AppDataStorage

> A .NET library for simple, persistent application data management with JSON serialization.

[![License](https://img.shields.io/github/license/ktsu-dev/AppDataStorage.svg?label=License&logo=nuget)](LICENSE.md)
[![NuGet Version](https://img.shields.io/nuget/v/ktsu.AppDataStorage?label=Stable&logo=nuget)](https://nuget.org/packages/ktsu.AppDataStorage)
[![NuGet Version](https://img.shields.io/nuget/vpre/ktsu.AppDataStorage?label=Latest&logo=nuget)](https://nuget.org/packages/ktsu.AppDataStorage)
[![NuGet Downloads](https://img.shields.io/nuget/dt/ktsu.AppDataStorage?label=Downloads&logo=nuget)](https://nuget.org/packages/ktsu.AppDataStorage)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/m/ktsu-dev/AppDataStorage?label=Commits&logo=github)](https://github.com/ktsu-dev/AppDataStorage/commits/main)
[![GitHub contributors](https://img.shields.io/github/contributors/ktsu-dev/AppDataStorage?label=Contributors&logo=github)](https://github.com/ktsu-dev/AppDataStorage/graphs/contributors)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/ktsu-dev/AppDataStorage/dotnet.yml?label=Build&logo=github)](https://github.com/ktsu-dev/AppDataStorage/actions)

## Introduction

`ktsu.AppDataStorage` is a .NET library designed to simplify the process of persisting application data. It stores configuration or state data as JSON files in the user's application data folder, with built-in safety mechanisms like automatic backups, debounced saves, and thread-safe operations. The library provides a singleton-like access pattern and supports custom subdirectories and file names for organizing data.

## Features

- **Easy-to-use API**: Inherit from `AppData<T>` and get automatic JSON persistence with `LoadOrCreate()`, `Save()`, and `Get()`.
- **Automatic Backup**: Creates backup files before overwriting to prevent data loss, with timestamped collision handling.
- **Safe Write Pattern**: Writes to a temporary file first, then atomically replaces the original to avoid corruption.
- **Debounced Saves**: `QueueSave()` and `SaveIfRequired()` prevent frequent file writes with a 3-second debounce window.
- **Thread-Safe Operations**: All file operations are synchronized with lock objects (uses `Lock` type on .NET 9+, `object` on earlier versions).
- **Singleton Access**: `Get()` provides lazy-initialized, singleton-like access to your app data instance.
- **Custom Storage Locations**: Support for custom subdirectories and file names via `LoadOrCreate()` overloads.
- **File System Abstraction**: Uses `System.IO.Abstractions` for easy unit testing with mock file systems.
- **Corrupt File Recovery**: Automatically falls back to backup files when the main data file is corrupt or missing.
- **Dispose-on-Exit**: Registers for process exit to ensure queued saves are flushed before the application terminates.

## Installation

### Package Manager Console

```powershell
Install-Package ktsu.AppDataStorage
```

### .NET CLI

```bash
dotnet add package ktsu.AppDataStorage
```

### Package Reference

```xml
<PackageReference Include="ktsu.AppDataStorage" Version="x.y.z" />
```

## Usage Examples

### Basic Example

Create a class that inherits from `AppData<T>`, where `T` is your custom data type.

```csharp
using ktsu.AppDataStorage;

public class MySettings : AppData<MySettings>
{
    public string Theme { get; set; } = "light";
    public int FontSize { get; set; } = 14;
    public bool AutoSave { get; set; } = true;
}

// Load existing data or create a new instance
var settings = MySettings.LoadOrCreate();
Console.WriteLine(settings.Theme);    // "light"
Console.WriteLine(settings.FontSize); // 14
```

### Accessing the Singleton Instance

The `Get()` method provides a lazy-initialized singleton instance, automatically calling `LoadOrCreate()` on first access.

```csharp
using ktsu.AppDataStorage;

// Access the singleton from anywhere in your application
var settings = MySettings.Get();
settings.Theme = "dark";
settings.Save();

// Same instance returned every time
var sameSettings = MySettings.Get();
Console.WriteLine(sameSettings.Theme); // "dark"
```

### Saving Data

Modify properties and call `Save()` to persist changes immediately.

```csharp
using ktsu.AppDataStorage;

var settings = MySettings.Get();
settings.Theme = "dark";
settings.FontSize = 16;
settings.Save();
```

### Custom Storage Location

Use overloads of `LoadOrCreate()` to store data in subdirectories or with custom file names.

```csharp
using ktsu.AppDataStorage;
using ktsu.Semantics.Paths;

// Store in a subdirectory
var profileData = MySettings.LoadOrCreate(RelativeDirectoryPath.Create("profiles"));

// Store with a custom file name
var customData = MySettings.LoadOrCreate(FileName.Create("user_preferences.json"));

// Both subdirectory and custom file name
var specificData = MySettings.LoadOrCreate(
    RelativeDirectoryPath.Create("profiles"),
    FileName.Create("admin_settings.json"));
```

## Advanced Usage

### Queued and Debounced Saving

For scenarios with frequent updates (e.g., UI-driven changes), use `QueueSave()` to schedule a save that is debounced with a 3-second threshold. Call `SaveIfRequired()` periodically (e.g., in a game loop or timer) to flush queued saves.

```csharp
using ktsu.AppDataStorage;

var settings = MySettings.Get();
settings.Theme = "dark";
settings.QueueSave();  // Schedules a save

// Later, in your update loop or timer:
settings.SaveIfRequired();  // Saves only if 3+ seconds have elapsed since QueueSave

// Or use the static convenience methods:
MySettings.QueueSave();
MySettings.SaveIfRequired();
```

Queued saves are also automatically flushed when the `AppData<T>` instance is disposed or when the process exits.

### Testing with Mock File Systems

The library supports `System.IO.Abstractions` for testability. Configure a mock file system in your tests:

```csharp
using System.IO.Abstractions.TestingHelpers;
using ktsu.AppDataStorage;

// In test setup - each thread gets its own isolated instance
AppData.ConfigureForTesting(() => new MockFileSystem());

// Run your tests...
var data = MySettings.LoadOrCreate();
data.Theme = "test";
data.Save();

// In test teardown
AppData.ResetFileSystem();
```

### Directory and File Paths

Data is stored in a directory unique to the current application domain under the user's `%APPDATA%` folder. File names are derived from the class name in snake_case.

```csharp
using ktsu.AppDataStorage;

// View the storage path
Console.WriteLine(AppData.Path);
// e.g., C:\Users\{user}\AppData\Roaming\{AppDomainName}

// File name is automatically generated from the class name
// MySettings -> my_settings.json
```

## API Reference

### `AppData` Static Class

Provides static helper methods and properties for managing application data storage.

#### Properties

| Name | Type | Description |
| --- | --- | --- |
| `Path` | `AbsoluteDirectoryPath` | The path where persistent data is stored for this application |

#### Methods

| Name | Return Type | Description |
| --- | --- | --- |
| `WriteText<T>(T appData, string text)` | `void` | Writes text to an app data file using a safe write pattern |
| `ReadText<T>(T appData)` | `string` | Reads text from an app data file, falling back to backup if missing |
| `QueueSave<T>(this T appData)` | `void` | Extension method that queues a debounced save operation |
| `SaveIfRequired<T>(this T appData)` | `void` | Extension method that saves if the debounce threshold has elapsed |
| `ConfigureForTesting(Func<IFileSystem>)` | `void` | Configures a mock file system factory for unit testing |
| `ResetFileSystem()` | `void` | Resets the file system to the default implementation after testing |

### `AppData<T>` Generic Abstract Class

Base class for app data storage. Inherit from this class to create persistable data types.

#### Type Constraints

`T : AppData<T>, IDisposable, new()`

#### Instance and Static Methods

| Name | Return Type | Description |
| --- | --- | --- |
| `Get()` | `T` | Gets the lazy-initialized singleton instance of the app data |
| `LoadOrCreate()` | `T` | Loads app data from file or creates a new instance if none exists |
| `LoadOrCreate(RelativeDirectoryPath?)` | `T` | Loads or creates with a custom subdirectory |
| `LoadOrCreate(FileName?)` | `T` | Loads or creates with a custom file name |
| `LoadOrCreate(RelativeDirectoryPath?, FileName?)` | `T` | Loads or creates with both custom subdirectory and file name |
| `Save()` | `void` | Serializes and saves the app data to its JSON file |
| `QueueSave()` | `void` | Queues a debounced save for the singleton instance |
| `SaveIfRequired()` | `void` | Saves the singleton instance if the debounce threshold has elapsed |
| `Dispose()` | `void` | Disposes the instance, flushing any queued saves |

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the MIT License. See the [LICENSE.md](LICENSE.md) file for details.
