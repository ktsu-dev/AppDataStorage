// Ignore Spelling: App Serializer

namespace ktsu.io.AppDataStorage;

using System.IO.Abstractions;
using System.Text.Json;
using System.Text.Json.Serialization;
using ktsu.io.CaseConverter;
using ktsu.io.StringifyJsonConvertorFactory;
using ktsu.io.StrongPaths;

internal static class AppDataShared
{
	internal static JsonSerializerOptions JsonSerializerOptions { get; } = new(JsonSerializerDefaults.General)
	{
		WriteIndented = true,
		IncludeFields = true,
		ReferenceHandler = ReferenceHandler.Preserve,
		Converters =
		{
			new JsonStringEnumConverter(),
			new StringifyJsonConvertorFactory(),
		}
	};

	internal static IFileSystem FileSystem { get; set; } = new FileSystem();
}

/// <summary>
/// Base class for app data storage. The app data is saved to the file system in the application data folder of the current user in a subdirectory named after the application domain.
/// </summary>
public abstract class AppData<T> where T : AppData<T>, new()
{
	private static DirectoryPath AppDomain => (DirectoryPath)System.AppDomain.CurrentDomain.FriendlyName;
	private static DirectoryPath AppDataPath => (DirectoryPath)Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
	private static DirectoryPath AppDataDomainPath => (DirectoryPath)Path.Combine(AppDataPath, AppDomain);
	private static FileName FileName => (FileName)$"{typeof(T).Name.ToSnakeCase()}.json";
	internal static FilePath FilePath => (FilePath)Path.Join(AppDataDomainPath, FileName);


	internal static void EnsureDirectoryExists(AnyFilePath path)
	{
		var dirPath = path.DirectoryPath;
		if (!string.IsNullOrEmpty(dirPath))
		{
			AppDataShared.FileSystem.Directory.CreateDirectory(dirPath);
		}
	}

	/// <summary>
	/// Saves the app data to the file system. If the file already exists, it is backed up first in case the save fails the original file is not lost.
	/// </summary>
	public void Save()
	{
		EnsureDirectoryExists(FilePath);

		string jsonString = JsonSerializer.Serialize(this, typeof(T), AppDataShared.JsonSerializerOptions);

		var tempFilePath = (FilePath)$"{FilePath}.tmp";
		var bkFilePath = (FilePath)$"{FilePath}.bk";
		AppDataShared.FileSystem.File.Delete(tempFilePath);
		AppDataShared.FileSystem.File.Delete(bkFilePath);
		AppDataShared.FileSystem.File.WriteAllText(tempFilePath, jsonString);
		try
		{
			AppDataShared.FileSystem.File.Move(FilePath, bkFilePath);
		}
		catch (FileNotFoundException)
		{
			// Ignore
		}

		AppDataShared.FileSystem.File.Move(tempFilePath, FilePath);
		AppDataShared.FileSystem.File.Delete(bkFilePath);
	}

	/// <summary>
	/// Attempts to load the app data of the corresponding type T from the file system. If the file does not exist or is invalid, a new instance is created and saved.
	/// </summary>
	/// <returns>An instance of the app data of type T.</returns>
	public static T LoadOrCreate()
	{
		EnsureDirectoryExists(FilePath);

		if (!string.IsNullOrEmpty(FilePath))
		{
			try
			{
				string jsonString = AppDataShared.FileSystem.File.ReadAllText(FilePath);
				return JsonSerializer.Deserialize<T>(jsonString, AppDataShared.JsonSerializerOptions)!;
			}
			catch (FileNotFoundException)
			{
				// Ignore
			}
			catch (JsonException)
			{
				// Ignore
			}
		}

		T newAppData = new();
		newAppData.Save();
		return newAppData;
	}
}
