// Copyright (c) ktsu.dev
// All rights reserved.
// Licensed under the MIT license.

namespace ktsu.AppDataStorage;

using System.IO.Abstractions;
using System.Text.Json;
using System.Text.Json.Serialization;

using ktsu.CaseConverter;
using ktsu.RoundTripStringJsonConverter;
using ktsu.Semantics.Paths;

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
	internal static RelativeDirectoryPath AppDomain => RelativeDirectoryPath.Create(System.AppDomain.CurrentDomain.FriendlyName);

	/// <summary>
	/// Gets the application data path as an absolute directory path.
	/// </summary>
	internal static AbsoluteDirectoryPath AppDataPath => AbsoluteDirectoryPath.Create(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData, Environment.SpecialFolderOption.Create));

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
			new RoundTripStringJsonConverterFactory(),
		}
	};

	/// <summary>
	/// Thread-local factory for creating file system instances to ensure test isolation.
	/// </summary>
	private static readonly ThreadLocal<Func<IFileSystem>?> ThreadLocalFileSystemFactory = new();

	/// <summary>
	/// Thread-local storage for file system instances to ensure each test gets its own persistent instance.
	/// </summary>
	private static readonly ThreadLocal<IFileSystem?> ThreadLocalFileSystem = new();

	/// <summary>
	/// Gets the file system abstraction used for file operations.
	/// Uses thread-local instance if set, otherwise returns the default filesystem.
	/// </summary>
	internal static IFileSystem FileSystem
	{
		get
		{
			// If we have a thread-local instance, return it
			if (ThreadLocalFileSystem.Value is not null)
			{
				return ThreadLocalFileSystem.Value;
			}

			// If we have a factory but no instance yet, create one and cache it
			if (ThreadLocalFileSystemFactory.Value is not null)
			{
				ThreadLocalFileSystem.Value = ThreadLocalFileSystemFactory.Value();
				return ThreadLocalFileSystem.Value;
			}

			// Fall back to default filesystem
			return DefaultFileSystem;
		}
	}

	/// <summary>
	/// The default file system implementation used when no thread-local override is set.
	/// </summary>
	private static readonly IFileSystem DefaultFileSystem = new FileSystem();

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

		AbsoluteDirectoryPath dirPath = path.AbsoluteDirectoryPath;
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
#if !NET6_0_OR_GREATER
		ArgumentNullExceptionPolyfill.ThrowIfNull(appData);
		ArgumentNullExceptionPolyfill.ThrowIfNull(text);
#else
		ArgumentNullException.ThrowIfNull(appData);
		ArgumentNullException.ThrowIfNull(text);
#endif

		lock (AppData<T>.Lock)
		{
			EnsureDirectoryExists(appData.FilePath);
			AbsoluteFilePath tempFilePath = MakeTempFilePath(appData.FilePath);
			AbsoluteFilePath bkFilePath = MakeBackupFilePath(appData.FilePath);
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
#if !NET6_0_OR_GREATER
		ArgumentNullExceptionPolyfill.ThrowIfNull(appData);
#else
		ArgumentNullException.ThrowIfNull(appData);
#endif

		lock (AppData<T>.Lock)
		{
			EnsureDirectoryExists(appData.FilePath);
			try
			{
				return FileSystem.File.ReadAllText(appData.FilePath);
			}
			catch (FileNotFoundException)
			{
				AbsoluteFilePath bkFilePath = MakeBackupFilePath(appData.FilePath);
				if (FileSystem.File.Exists(bkFilePath))
				{
					FileSystem.File.Copy(bkFilePath, appData.FilePath);

					// Create a unique timestamped backup filename
					string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
					AbsoluteFilePath timestampedBackup = bkFilePath.WithSuffix($".{timestamp}");
					int counter = 0;
					while (FileSystem.File.Exists(timestampedBackup))
					{
						counter++;
						timestampedBackup = bkFilePath.WithSuffix($".{timestamp}_{counter}");
					}

					FileSystem.File.Move(bkFilePath, timestampedBackup);
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
#if !NET6_0_OR_GREATER
		ArgumentNullExceptionPolyfill.ThrowIfNull(appData);
#else
		ArgumentNullException.ThrowIfNull(appData);
#endif

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
#if !NET6_0_OR_GREATER
		ArgumentNullExceptionPolyfill.ThrowIfNull(appData);
#else
		ArgumentNullException.ThrowIfNull(appData);
#endif

		lock (AppData<T>.Lock)
		{
			//debounce the save requests and avoid saving multiple times per frame or multiple frames in a row
			if (appData.IsSaveQueued() && appData.IsDoubounceTimeElapsed())
			{
				appData.Save();
			}
		}
	}

	/// <summary>
	/// Configures the file system for testing using a factory function.
	/// This ensures each test gets an isolated filesystem instance for thread-safe testing.
	/// </summary>
	/// <param name="fileSystemFactory">Factory function that creates a new mock file system instance.</param>
	/// <exception cref="ArgumentNullException">Thrown when fileSystemFactory is null.</exception>
	/// <exception cref="InvalidOperationException">Thrown when factory doesn't produce mock/test file systems.</exception>
	/// <example>
	/// <code>
	/// // Each access gets a fresh instance:
	/// AppData.ConfigureForTesting(() => new MockFileSystem());
	///
	/// // Or with pre-configured data:
	/// AppData.ConfigureForTesting(() => new MockFileSystem(new Dictionary&lt;string, MockFileData&gt;
	/// {
	///     { "/test.txt", new MockFileData("content") }
	/// }));
	/// </code>
	/// </example>
	public static void ConfigureForTesting(Func<IFileSystem> fileSystemFactory)
	{
#if !NET6_0_OR_GREATER
		ArgumentNullExceptionPolyfill.ThrowIfNull(fileSystemFactory);
#else
		ArgumentNullException.ThrowIfNull(fileSystemFactory);
#endif

		// Validate that the factory produces mock/test file systems by testing it once
		IFileSystem testInstance = fileSystemFactory();
		if (!IsTestFileSystem(testInstance))
		{
			throw new InvalidOperationException("ConfigureForTesting factory can only create mock or test file systems. Use dependency injection for production scenarios.");
		}

		ThreadLocalFileSystemFactory.Value = fileSystemFactory;
	}

	/// <summary>
	/// Determines whether the specified file system is a test/mock implementation.
	/// Uses robust type-based validation instead of fragile string matching.
	/// </summary>
	/// <param name="fileSystem">The file system instance to validate.</param>
	/// <returns>True if the file system is a test/mock implementation; otherwise, false.</returns>
	private static bool IsTestFileSystem(IFileSystem fileSystem)
	{
#if !NET6_0_OR_GREATER
		ArgumentNullExceptionPolyfill.ThrowIfNull(fileSystem);
#else
		ArgumentNullException.ThrowIfNull(fileSystem);
#endif

		Type fileSystemType = fileSystem.GetType();

		// Check if it's the standard TestableIO MockFileSystem
		if (fileSystemType.FullName == "System.IO.Abstractions.TestingHelpers.MockFileSystem")
		{
			return true;
		}

		// Check if it's in a testing/mock namespace
		string? namespaceName = fileSystemType.Namespace;
		if (!string.IsNullOrEmpty(namespaceName) &&
			(namespaceName.Contains("TestingHelpers") ||
			namespaceName.Contains("Testing") ||
			namespaceName.Contains("Mock") ||
			namespaceName.Contains("Fake") ||
			namespaceName.Contains("Stub")))
		{
			return true;
		}

		// Check if it's not the production FileSystem implementation
		if (fileSystemType.FullName == "System.IO.Abstractions.FileSystem")
		{
			return false;
		}

		// For other implementations, check the type name as fallback
		// but only accept common test naming patterns
		string typeName = fileSystemType.Name;
		return typeName.EndsWith("MockFileSystem", StringComparison.OrdinalIgnoreCase) ||
			   typeName.EndsWith("TestFileSystem", StringComparison.OrdinalIgnoreCase) ||
			   typeName.EndsWith("FakeFileSystem", StringComparison.OrdinalIgnoreCase) ||
			   typeName.EndsWith("StubFileSystem", StringComparison.OrdinalIgnoreCase);
	}

	/// <summary>
	/// Clears the cached filesystem instance for the current thread, forcing the factory to create a new instance on next access.
	/// This is useful for test isolation while keeping the same factory.
	/// </summary>
	internal static void ClearCachedFileSystem() => ThreadLocalFileSystem.Value = null;

	/// <summary>
	/// Resets the filesystem to use the default system filesystem for the current thread.
	/// This should be called after tests to restore normal file system behavior.
	/// </summary>
	/// <example>
	/// <code>
	/// // In your test teardown
	/// AppData.ResetFileSystem();
	/// </code>
	/// </example>
	public static void ResetFileSystem()
	{
		ThreadLocalFileSystemFactory.Value = null;
		ThreadLocalFileSystem.Value = null;
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
	internal FileName FileName => FileNameOverride ?? FileName.Create($"{typeof(T).Name.ToSnakeCase()}.json");

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
#if NET9_0_OR_GREATER
	[JsonIgnore]
	public static Lock Lock { get; } = new();
#else
	[JsonIgnore]
	public static object Lock { get; } = new();
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
