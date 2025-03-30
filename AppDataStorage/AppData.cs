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
	internal static RelativeDirectoryPath AppDomain => System.AppDomain.CurrentDomain.FriendlyName.As<RelativeDirectoryPath>();

	/// <summary>
	/// Gets the application data path as an absolute directory path.
	/// </summary>
	internal static AbsoluteDirectoryPath AppDataPath => Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData, Environment.SpecialFolderOption.Create).As<AbsoluteDirectoryPath>();

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
		if (path?.IsEmpty() ?? true)
		{
			return;
		}

		var dirPath = path.DirectoryPath;
		if (!string.IsNullOrEmpty(dirPath))
		{
			EnsureDirectoryExists(dirPath);
		}
	}

	/// <summary>
	/// Ensures that the specified directory path exists.
	/// </summary>
	/// <param name="path">The directory path to ensure exists.</param>
	internal static void EnsureDirectoryExists(AbsoluteDirectoryPath path)
	{
		if (path?.IsEmpty() ?? true)
		{
			return;
		}

		FileSystem.Directory.CreateDirectory(path);
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
	/// Writes the specified text to the app data file.
	/// </summary>
	/// <typeparam name="T">The type of the app data.</typeparam>
	/// <param name="appData">The app data instance.</param>
	/// <param name="text">The text to write to the file.</param>
	/// <exception cref="ArgumentNullException">Thrown when <paramref name="appData"/> or <paramref name="text"/> is null.</exception>
	public static void WriteText<T>(T appData, string text) where T : AppData<T>, new()
	{
		ArgumentNullException.ThrowIfNull(appData);
		ArgumentNullException.ThrowIfNull(text);

		lock (AppData<T>.Lock)
		{
			EnsureDirectoryExists(appData.FilePath);
			var tempFilePath = MakeTempFilePath(appData.FilePath);
			var bkFilePath = MakeBackupFilePath(appData.FilePath);
			FileSystem.File.WriteAllText(tempFilePath, text);
			try
			{
				FileSystem.File.Delete(bkFilePath);
				FileSystem.File.Copy(appData.FilePath, bkFilePath);
				FileSystem.File.Delete(appData.FilePath);
			}
			catch (FileNotFoundException)
			{
				// Ignore
			}

			FileSystem.File.Move(tempFilePath, appData.FilePath);
			FileSystem.File.Delete(bkFilePath);
		}
	}

	/// <summary>
	/// Reads the text content from the app data file.
	/// </summary>
	/// <typeparam name="T">The type of the app data.</typeparam>
	/// <param name="appData">The app data instance.</param>
	/// <returns>The text content of the app data file.</returns>
	/// <exception cref="ArgumentNullException">Thrown when <paramref name="appData"/> is null.</exception>
	public static string ReadText<T>(T appData) where T : AppData<T>, new()
	{
		ArgumentNullException.ThrowIfNull(appData);

		lock (AppData<T>.Lock)
		{
			EnsureDirectoryExists(appData.FilePath);
			try
			{
				return FileSystem.File.ReadAllText(appData.FilePath);
			}
			catch (FileNotFoundException)
			{
				var bkFilePath = MakeBackupFilePath(appData.FilePath);
				if (FileSystem.File.Exists(bkFilePath))
				{
					FileSystem.File.Copy(bkFilePath, appData.FilePath);
					FileSystem.File.Move(bkFilePath, bkFilePath.WithSuffix($".{DateTime.Now:yyyyMMdd_HHmmss}"));
					return ReadText(appData);
				}
			}

			return string.Empty;
		}
	}

	/// <summary>
	/// Queues a save operation for the current app data instance.
	/// </summary>
	/// <typeparam name="T">The type of the app data.</typeparam>
	/// <param name="appData">The app data instance.</param>
	/// <exception cref="ArgumentNullException">Thrown when <paramref name="appData"/> is null.</exception>
	public static void QueueSave<T>(this T appData) where T : AppData<T>, new()
	{
		ArgumentNullException.ThrowIfNull(appData);

		lock (AppData<T>.Lock)
		{
			appData.SaveQueuedTime = DateTime.UtcNow;
			appData.EnsureDisposeOnExit();
		}
	}

	/// <summary>
	/// Saves the app data if required based on the debounce time and the last save time.
	/// </summary>
	/// <typeparam name="T">The type of the app data.</typeparam>
	/// <param name="appData">The app data instance.</param>
	/// <exception cref="ArgumentNullException">Thrown when <paramref name="appData"/> is null.</exception>
	public static void SaveIfRequired<T>(this T appData) where T : AppData<T>, new()
	{
		ArgumentNullException.ThrowIfNull(appData);
		lock (AppData<T>.Lock)
		{
			//debounce the save requests and avoid saving multiple times per frame or multiple frames in a row
			if (appData.IsSaveQueued() && appData.IsDoubounceTimeElapsed())
			{
				appData.Save();
			}
		}
	}
}

/// <summary>
/// Base class for app data storage. The app data is saved to the file system in the application data folder of the current user in a subdirectory named after the application domain.
/// </summary>
/// <typeparam name="T">The type of the app data.</typeparam>
public abstract class AppData<T>() : IDisposable where T : AppData<T>, IDisposable, new()
{
	private bool disposedValue;

	/// <summary>
	/// Gets the file name for the app data file.
	/// </summary>
	internal FileName FileName => FileNameOverride ?? $"{typeof(T).Name.ToSnakeCase()}.json".As<FileName>();

	internal RelativeDirectoryPath? Subdirectory { get; set; }

	internal FileName? FileNameOverride { get; set; }

	/// <summary>
	/// Gets the file path for the app data file.
	/// </summary>
	internal AbsoluteFilePath FilePath => Subdirectory is null
		? AppData.Path / FileName
		: AppData.Path / Subdirectory / FileName;

	/// <summary>
	/// Gets the current instance of the app data.
	/// </summary>
	/// <returns>The current instance of the app data.</returns>
	public static T Get() => InternalState.Value;

	/// <summary>
	/// Gets the internal state of the app data.
	/// </summary>
	internal static Lazy<T> InternalState { get; } = new(LoadOrCreate);

	/// <summary>
	/// Gets or sets the last save time of the app data.
	/// </summary>
	internal DateTime LastSaveTime { get; set; } = DateTime.MinValue;

	/// <summary>
	/// Gets or sets the save queued time of the app data.
	/// </summary>
	internal DateTime SaveQueuedTime { get; set; } = DateTime.MinValue;

	/// <summary>
	/// Gets the debounce time for saving the app data.
	/// </summary>
	internal TimeSpan SaveDebounceTime { get; } = TimeSpan.FromSeconds(3);

	/// <summary>
	/// Gets a value indicating whether this instance has been registered for disposal when the process exits.
	/// </summary>
	internal bool IsDisposeRegistered { get; private set; }

	/// <summary>
	/// Gets the lock object used for synchronizing access to the app data.
	/// </summary>
#if NET8_0
	[JsonIgnore]
	public static object Lock { get; } = new();
#else
	[JsonIgnore]
	public static Lock Lock { get; } = new();
#endif

	internal bool IsSaveQueued()
	{
		lock (Lock)
		{
			return SaveQueuedTime > LastSaveTime;
		}
	}

	internal bool IsDoubounceTimeElapsed()
	{
		lock (Lock)
		{
			return (DateTime.UtcNow - SaveQueuedTime) > SaveDebounceTime;
		}
	}

	/// <summary>
	/// Saves the app data to the file system. If the file already exists, it is backed up first in case the save fails the original file is not lost.
	/// </summary>
	public void Save()
	{
		lock (Lock)
		{
			string jsonString = JsonSerializer.Serialize(this, typeof(T), AppData.JsonSerializerOptions);
			AppData.WriteText((T)this, jsonString);
			LastSaveTime = DateTime.UtcNow;
		}
	}

	/// <summary>
	/// Ensures that the app data instance is disposed when the application exits.
	/// Dispose will save the app data if an outstanding save is queued.
	/// </summary>
	internal void EnsureDisposeOnExit()
	{
		lock (Lock)
		{
			if (!IsDisposeRegistered)
			{
				IsDisposeRegistered = true;
				AppDomain.CurrentDomain.ProcessExit += (sender, e) => Dispose();
			}
		}
	}

	/// <summary>
	/// Disposes the app data instance, saving it if required.
	/// </summary>
	/// <param name="disposing">A boolean value indicating whether the method is being called from the Dispose method (true) or from a finalizer (false).</param>
	protected virtual void Dispose(bool disposing)
	{
		lock (Lock)
		{
			if (!disposedValue)
			{
				if (disposing && IsSaveQueued())
				{
					Save();
				}

				disposedValue = true;
			}
		}
	}

	/// <summary>
	/// Disposes the app data instance, saving it if required.
	/// </summary>
	public void Dispose()
	{
		// Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
		Dispose(disposing: true);
		GC.SuppressFinalize(this);
	}

	/// <summary>
	/// Loads the app data from the file system or creates a new instance if the file does not exist.
	/// </summary>
	/// <param name="subdirectory">The subdirectory where the app data file is located, or null to use the default location.</param>
	/// <param name="fileName">The name of the app data file, or null to use the default file name.</param>
	/// <returns>The loaded or newly created app data instance.</returns>
	public static T LoadOrCreate(RelativeDirectoryPath? subdirectory, FileName? fileName)
	{
		lock (Lock)
		{
			T newAppData = new()
			{
				Subdirectory = subdirectory,
				FileNameOverride = fileName,
			};

			string jsonString = AppData.ReadText(newAppData);

			if (string.IsNullOrEmpty(jsonString))
			{
				newAppData.Save();
				return newAppData;
			}

			try
			{
				newAppData = JsonSerializer.Deserialize<T>(jsonString, AppData.JsonSerializerOptions)!;
				newAppData.Subdirectory = subdirectory;
				newAppData.FileNameOverride = fileName;
				return newAppData;
			}
			catch (JsonException)
			{
				// file was corrupt or could not be deserialized
				// delete and try load a backup
				AppData.FileSystem.File.Delete(newAppData.FilePath);
				return LoadOrCreate(subdirectory, fileName);
			}
		}
	}

	/// <summary>
	/// Loads the app data from the file system or creates a new instance if the file does not exist.
	/// </summary>
	/// <returns>The loaded or newly created app data instance.</returns>
	public static T LoadOrCreate() => LoadOrCreate(subdirectory: null, fileName: null);

	/// <summary>
	/// Loads the app data from the file system or creates a new instance if the file does not exist.
	/// </summary>
	/// <param name="subdirectory">The subdirectory where the app data file is located, or null to use the default location.</param>
	/// <returns>The loaded or newly created app data instance.</returns>
	public static T LoadOrCreate(RelativeDirectoryPath? subdirectory) => LoadOrCreate(subdirectory, fileName: null);

	/// <summary>
	/// Loads the app data from the file system or creates a new instance if the file does not exist.
	/// </summary>
	/// <param name="fileName">The name of the app data file, or null to use the default file name.</param>
	/// <returns>The loaded or newly created app data instance.</returns>
	public static T LoadOrCreate(FileName? fileName) => LoadOrCreate(subdirectory: null, fileName);

	/// <summary>
	/// Queues a save operation for the current app data instance.
	/// </summary>
	public static void QueueSave() => Get().QueueSave();

	/// <summary>
	/// Saves the app data if required based on the debounce time and the last save time.
	/// </summary>
	public static void SaveIfRequired() => Get().SaveIfRequired();
}
