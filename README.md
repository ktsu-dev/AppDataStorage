# ktsu.AppDataStorage

`ktsu.AppDataStorage` is a .NET library designed to simplify the process of storing application data. This library enables you to save and load configuration or state data in the application data folder of the current user, using JSON serialization.

## Features

- **Easy-to-use**: Simple interface for saving and loading application data.
- **Automatic Backup**: Ensures that the original data is backed up before saving.
- **Customizable Serialization**: Uses `System.Text.Json` with support for custom converters.
- **File System Abstraction**: Uses `System.IO.Abstractions` for easy testing.

## Installation

Install the package via NuGet:

```bash
dotnet add package ktsu.AppDataStorage
```

## Usage

### Define Your App Data Class

Create a class that inherits from `AppData<T>` where `T` is your class type.

```csharp
public class MyAppData : AppData<MyAppData>
{
    public string Setting1 { get; set; } = "hello";
    public int Setting2 { get; set; } = 12;
}
```

### Load Data

To load data, call the `LoadOrCreate` method. If the data file doesn't exist or is invalid, a new instance will be created and saved.

```csharp
var data = MyAppData.LoadOrCreate();
Console.WriteLine(data.Setting1);
Console.WriteLine(data.Setting2);

// Output:
// hello
// 12
```

### Save Data

To save data, call `Save` on the instance of your app data class, after modifying its properties.

```csharp
var data = MyAppData.LoadOrCreate();
data.Setting1 = "goodbye";
data.Setting2 = 42;
data.Save();

var data2 = MyAppData.LoadOrCreate();
Console.WriteLine(data2.Setting1);
Console.WriteLine(data2.Setting2);

// Output:
// goodbye
// 42
```



## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the MIT License.
