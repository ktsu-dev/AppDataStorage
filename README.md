# ktsu.AppDataStorage

`ktsu.AppDataStorage` is a .NET library designed to simplify the process of managing application data. It facilitates saving and loading configuration or state data to the application's data folder, leveraging JSON serialization.

## Features

- **Easy-to-use API**: Intuitive methods for saving and loading data.
- **Automatic Backup**: Backs up original files before overwriting to ensure data safety.
- **Custom Serialization Options**: Uses `System.Text.Json` with support for custom converters.
- **File System Abstraction**: Uses `System.IO.Abstractions` for easy unit testing and mocking.
- **Debounced Saves**: Prevents frequent file writes to improve performance.
- **Support for Multiple Applications**: Organizes data by application domain for isolation.

## Installation

Install the package via NuGet:

```bash
dotnet add package ktsu.AppDataStorage
```

## Usage

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

### Saving Data

Modify properties and save the data using the `Save` method.

```csharp
var data = MyAppData.LoadOrCreate();
data.Setting1 = "goodbye";
data.Setting2 = 42;
data.Save();

var reloadedData = MyAppData.LoadOrCreate();
Console.WriteLine(reloadedData.Setting1);
Console.WriteLine(reloadedData.Setting2);

// Output:
// goodbye
// 42
```

### Queued and Debounced Saving

For scenarios with frequent updates, you can queue save operations using `QueueSave`, which automatically debounces writes to avoid frequent file system operations.

```csharp
MyAppData.QueueSave();  // Schedules a save
MyAppData.SaveIfRequired();  // Performs the save if the debounce threshold is exceeded
```

### Writing and Reading Arbitrary Text Files

Write and read arbitrary files in the application's data folder using the static `AppData` class.

#### Write Text:
```csharp
AppData.WriteText("example.txt".As<FileName>(), "Hello, AppData!");
```

#### Read Text:
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

## Advanced Features

### Backup and Temporary Files

Backup and temporary files are automatically managed during save operations to ensure data integrity:

- Backup file extension: `.bk`
- Temporary file extension: `.tmp`

### File System Abstraction

The library uses `System.IO.Abstractions`, allowing you to inject a custom file system implementation for testing.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the MIT License.
