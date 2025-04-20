# ktsu.AppDataStorage

> A .NET library for simple application data management with JSON serialization.

[![License](https://img.shields.io/github/license/ktsu-dev/AppDataStorage.svg?label=License&logo=nuget)](LICENSE.md)
[![NuGet Version](https://img.shields.io/nuget/v/ktsu.AppDataStorage?label=Stable&logo=nuget)](https://nuget.org/packages/ktsu.AppDataStorage)
[![NuGet Version](https://img.shields.io/nuget/vpre/ktsu.AppDataStorage?label=Latest&logo=nuget)](https://nuget.org/packages/ktsu.AppDataStorage)
[![NuGet Downloads](https://img.shields.io/nuget/dt/ktsu.AppDataStorage?label=Downloads&logo=nuget)](https://nuget.org/packages/ktsu.AppDataStorage)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/m/ktsu-dev/AppDataStorage?label=Commits&logo=github)](https://github.com/ktsu-dev/AppDataStorage/commits/main)
[![GitHub contributors](https://img.shields.io/github/contributors/ktsu-dev/AppDataStorage?label=Contributors&logo=github)](https://github.com/ktsu-dev/AppDataStorage/graphs/contributors)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/ktsu-dev/AppDataStorage/dotnet.yml?label=Build&logo=github)](https://github.com/ktsu-dev/AppDataStorage/actions)

## Introduction

`ktsu.AppDataStorage` is a .NET library designed to simplify the process of managing application data. It facilitates saving and loading configuration or state data to the application's data folder, leveraging JSON serialization. The library handles file operations with safety mechanisms like automatic backups and provides an intuitive API for developers.

## Features

- **Easy-to-use API**: Intuitive methods for saving and loading data.
- **Automatic Backup**: Backs up original files before overwriting to ensure data safety.
- **Custom Serialization Options**: Uses `System.Text.Json` with support for custom converters.
- **File System Abstraction**: Uses `System.IO.Abstractions` for easy unit testing and mocking.
- **Debounced Saves**: Prevents frequent file writes to improve performance.
- **Support for Multiple Applications**: Organizes data by application domain for isolation.
- **Static Instance Access**: Provides easy access to a singleton-like instance for centralized data management.

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

### Defining Your Application Data Class

Create a class that inherits from `AppData<T>`, where `T` is your custom data type.

```csharp
public class MyAppData : AppData<MyAppData>
{
    public string Setting1 { get; set; } = "hello";
    public int Setting2 { get; set; } = 12;
}
```

### Loading Data

Load existing data or create a new instance if no data file exists using `LoadOrCreate`.

```csharp
var data = MyAppData.LoadOrCreate();
Console.WriteLine(data.Setting1);
Console.WriteLine(data.Setting2);

// Output:
// hello
// 12
```

### Accessing the Static Instance

The `AppData<T>` class provides a static instance through the `Get` method, which ensures a single, easily accessible instance is available throughout your application:

```csharp
var data = MyAppData.Get();
Console.WriteLine(data.Setting1);
```

The static instance is initialized automatically and matches the instance returned by `LoadOrCreate`. Changes to the static instance are persistent once saved:

```csharp
var data = MyAppData.Get();
data.Setting1 = "new value";
data.Save();

var sameData = MyAppData.Get();
Console.WriteLine(sameData.Setting1);

// Output:
// new value
```

### Saving Data

Modify properties and save the data using the `Save` method.

```csharp
var data = MyAppData.Get();
data.Setting1 = "goodbye";
data.Setting2 = 42;
data.Save();

var reloadedData = MyAppData.Get();
Console.WriteLine(reloadedData.Setting1);
Console.WriteLine(reloadedData.Setting2);

// Output:
// goodbye
// 42
```

## Advanced Usage

### Queued and Debounced Saving

For scenarios with frequent updates, you can queue save operations using `QueueSave`, which automatically debounces writes to avoid frequent file system operations.

```csharp
MyAppData.QueueSave();  // Schedules a save
MyAppData.SaveIfRequired();  // Performs the save if the debounce threshold is exceeded
```

### Writing and Reading Arbitrary Text Files

Write and read arbitrary files in the application's data folder using the static `AppData` class.

#### Write Text

```csharp
AppData.WriteText("example.txt".As<FileName>(), "Hello, AppData!");
```

#### Read Text

```csharp
string content = AppData.ReadText("example.txt".As<FileName>());
Console.WriteLine(content);

// Output:
// Hello, AppData!
```

### Customizing Serialization

Serialization behavior can be customized using `JsonSerializerOptions`. By default, the library uses:

- Indented JSON for readability.
- `ReferenceHandler.Preserve` for circular references.
- Converters such as `JsonStringEnumConverter` and `ToStringJsonConverter`.

### Directory and File Paths

Data is stored in a directory unique to the current application domain:

```csharp
var appDataPath = AppData.Path;
Console.WriteLine($"App Data Path: {appDataPath}");
```

## API Reference

### `AppData` Static Class

The primary static class for working with application data storage.

#### Properties

| Name | Type | Description |
|------|------|-------------|
| `Path` | `AbsoluteDirectoryPath` | The path where persistent data is stored for this application |

#### Methods

| Name | Return Type | Description |
|------|-------------|-------------|
| `WriteText<T>(T appData, string text)` | `void` | Writes text to an app data file with backup safety |
| `ReadText<T>(T appData)` | `string` | Reads text from an app data file |
| `QueueSave<T>(this T appData)` | `void` | Queues a save operation for the app data |
| `SaveIfRequired<T>(this T appData)` | `void` | Saves the app data if required based on debounce settings |

### `AppData<T>` Generic Abstract Class

Base class for app data storage implementations.

#### Properties

| Name | Type | Description |
|------|------|-------------|
| `FilePath` | `AbsoluteFilePath` | The file path for the app data file |

#### Methods

| Name | Return Type | Description |
|------|-------------|-------------|
| `Get()` | `T` | Gets the current instance of the app data |
| `LoadOrCreate()` | `T` | Loads app data from file or creates a new instance |
| `Save()` | `void` | Saves the app data to the file system |
| `QueueSave()` | `void` | Queues a save operation for the current app data instance |
| `SaveIfRequired()` | `void` | Saves the app data if required based on debounce settings |

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the MIT License. See the [LICENSE.md](LICENSE.md) file for details.
