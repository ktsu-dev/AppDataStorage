// Ignore Spelling: App Serializer

namespace ktsu.AppDataStorage;

using System.IO.Abstractions;
using System.Text.Json;
using System.Text.Json.Serialization;
using ktsu.CaseConverter;
using ktsu.Extensions;
using ktsu.StrongPaths;
using ktsu.ToStringJsonConverter;

/// <summary>
/// Provides static helper methods and properties for managing application data storage.
/// </summary>
public static class AppData
{
	/// <summary>
	/// Gets the path where persistent data is stored for this application.
	/// </summary>
	public static AbsoluteDirectoryPath Path => AppDataPath / AppDomain;

	/// <summary>
	/// Gets the application domain as a relative directory path.
	/// </summary>
	private static RelativeDirectoryPath AppDomain => System.AppDomain.CurrentDomain.FriendlyName.As<RelativeDirectoryPath>();

	/// <summary>
	/// Gets the application data path as an absolute directory path.
	/// </summary>
	private static AbsoluteDirectoryPath AppDataPath => Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData, Environment.SpecialFolderOption.Create).As<AbsoluteDirectoryPath>();

	/// <summary>
	/// Gets the JSON serializer options used for serializing and deserializing app data.
	/// </summary>
	internal static JsonSerializerOptions JsonSerializerOptions { get; } = new(JsonSerializerDefaults.General)
	{
		WriteIndented = true,
		IncludeFields = true,
		ReferenceHandler = ReferenceHandler.Preserve,
		Converters =
		{
			new JsonStringEnumConverter(),
			new ToStringJsonConverterFactory(),
		}
	};

	/// <summary>
	/// Gets or sets the file system abstraction used for file operations.
	/// </summary>
	internal static IFileSystem FileSystem { get; set; } = new FileSystem();

	/// <summary>
	/// Ensures that the directory for the specified file path exists.
	/// </summary>
	/// <param name="path">The file path for which to ensure the directory exists.</param>
	internal static void EnsureDirectoryExists(AbsoluteFilePath path)
	{
		var dirPath = path.DirectoryPath;
		EnsureDirectoryExists(dirPath);
	}

	/// <summary>
	/// Ensures that the specified directory path exists.
	/// </summary>
	/// <param name="path">The directory path to ensure exists.</param>
	internal static void EnsureDirectoryExists(AbsoluteDirectoryPath path)
	{
		if (!string.IsNullOrEmpty(path))
		{
			FileSystem.Directory.CreateDirectory(path);
		}
	}

	/// <summary>
	/// Creates a temporary file path by appending a ".tmp" suffix to the specified file path.
	/// </summary>
	/// <param name="filePath">The original file path.</param>
	/// <returns>The temporary file path.</returns>
	internal static AbsoluteFilePath MakeTempFilePath(AbsoluteFilePath filePath) => filePath.WithSuffix(".tmp");

	/// <summary>
	/// Creates a backup file path by appending a ".bk" suffix to the specified file path.
	/// </summary>
	/// <param name="filePath">The original file path.</param>
	/// <returns>The backup file path.</returns>
	internal static AbsoluteFilePath MakeBackupFilePath(AbsoluteFilePath filePath) => filePath.WithSuffix(".bk");

	/// <summary>
	/// Writes text to a file within this application's app data folder.
	/// </summary>
	/// <param name="fileName">The name of the file to write.</param>
	/// <param name="text">The text to write.</param>
	public static void WriteText(FileName fileName, string text)
	{
		var filePath = Path / fileName;
		EnsureDirectoryExists(filePath);
		var tempFilePath = MakeTempFilePath(filePath);
		var bkFilePath = MakeBackupFilePath(filePath);
		FileSystem.File.Delete(tempFilePath);
		FileSystem.File.Delete(bkFilePath);
		FileSystem.File.WriteAllText(tempFilePath, text);
		try
		{
			FileSystem.File.Move(filePath, bkFilePath);
		}
		catch (FileNotFoundException)
		{
			// Ignore
		}

		FileSystem.File.Move(tempFilePath, filePath);
		FileSystem.File.Delete(bkFilePath);
	}

	/// <summary>
	/// Reads text from a file within this application's app data folder.
	/// </summary>
	/// <param name="fileName">The name of the file to read.</param>
	/// <returns>A string containing the text in the file.</returns>
	public static string ReadText(FileName fileName)
	{
		var filePath = Path / fileName;
		EnsureDirectoryExists(filePath);
		try
		{
			return FileSystem.File.ReadAllText(filePath);
		}
		catch (FileNotFoundException)
		{
			var bkFilePath = MakeBackupFilePath(filePath);
			if (bkFilePath.Exists)
			{
				FileSystem.File.Move(bkFilePath, filePath);
				return ReadText(fileName);
			}
		}

		return string.Empty;
	}
}

/// <summary>
/// Base class for app data storage. The app data is saved to the file system in the application data folder of the current user in a subdirectory named after the application domain.
/// </summary>
/// <typeparam name="T">The type of the app data.</typeparam>
public abstract class AppData<T> where T : AppData<T>, new()
{
	/// <summary>
	/// Gets the file name for the app data file.
	/// </summary>
	private static FileName FileName => $"{typeof(T).Name.ToSnakeCase()}.json".As<FileName>();

	/// <summary>
	/// Gets the file path for the app data file.
	/// </summary>
	internal static AbsoluteFilePath FilePath => AppData.Path / FileName;

	/// <summary>
	/// Gets the current instance of the app data.
	/// </summary>
	/// <returns>The current instance of the app data.</returns>
	public static T Get() => InternalState;

	/// <summary>
	/// Gets the internal state of the app data.
	/// </summary>
	private static T InternalState { get; } = LoadOrCreate();

	/// <summary>
	/// Gets or sets the last save time of the app data.
	/// </summary>
	private static DateTime LastSaveTime { get; set; } = DateTime.MinValue;

	/// <summary>
	/// Gets or sets the save queued time of the app data.
	/// </summary>
	private static DateTime SaveQueuedTime { get; set; } = DateTime.MinValue;

	/// <summary>
	/// Gets the debounce time for saving the app data.
	/// </summary>
	private static TimeSpan SaveDebounceTime { get; } = TimeSpan.FromSeconds(3);

	/// <summary>
	/// Saves the internal state of the app data.
	/// </summary>
	private static void SaveInternal() => InternalState.Save();

	/// <summary>
	/// Queues a save operation for the app data.
	/// </summary>
	public static void QueueSave()
	{
		lock (InternalState)
		{
			SaveQueuedTime = DateTime.UtcNow;
		}
	}

	/// <summary>
	/// Saves the app data if required, based on the debounce time.
	/// </summary>
	public static void SaveIfRequired()
	{
		lock (InternalState)
		{
			//debounce the save requests and avoid saving multiple times per frame or multiple frames in a row
			if ((SaveQueuedTime > LastSaveTime)
			&& ((DateTime.UtcNow - SaveQueuedTime) > SaveDebounceTime))
			{
				SaveInternal();
				LastSaveTime = DateTime.UtcNow;
			}
		}
	}

	/// <summary>
	/// Saves the app data to the file system. If the file already exists, it is backed up first in case the save fails the original file is not lost.
	/// </summary>
	public void Save()
	{
		string jsonString = JsonSerializer.Serialize(this, typeof(T), AppData.JsonSerializerOptions);
		AppData.WriteText(FileName, jsonString);
	}

	/// <summary>
	/// Attempts to load the app data of the corresponding type T from the file system. If the file does not exist or is invalid, a new instance is created and saved.
	/// </summary>
	/// <returns>An instance of the app data of type T.</returns>
	public static T LoadOrCreate()
	{
		try
		{
			string jsonString = AppData.ReadText(FileName);
			return JsonSerializer.Deserialize<T>(jsonString, AppData.JsonSerializerOptions)!;
		}
		catch (JsonException)
		{
			// Ignore
		}

		T newAppData = new();
		newAppData.Save();
		return newAppData;
	}
}
