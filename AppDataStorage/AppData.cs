namespace ktsu.io.AppDataStorage;

using System.Text.Json;
using System.Text.Json.Serialization;
using CaseConverter;
using StrongPaths;
using StringifyJsonConvertorFactory;

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
	private static JsonSerializerOptions JsonSerializerOptions { get; } = new(JsonSerializerDefaults.General)
	{
		WriteIndented = true,
		IncludeFields = true,
		Converters =
		{
			new JsonStringEnumConverter(),
			new StringifyJsonConvertorFactory(),
		}
	};

	private static void EnsureDirectoryExists(AnyFilePath path)
	{
		var dirPath = path.DirectoryPath;
		if (!string.IsNullOrEmpty(dirPath))
		{
			Directory.CreateDirectory(dirPath);
		}
	}

	/// <summary>
	/// Saves the app data to the file system. If the file already exists, it is backed up first incase the save fails the original file is not lost.
	/// </summary>
	public void Save()
	{
		EnsureDirectoryExists(FilePath);

		string jsonString = JsonSerializer.Serialize(this, typeof(T), JsonSerializerOptions);

		var tmpFilePath = (FilePath)$"{FilePath}.tmp";
		var bkFilePath = (FilePath)$"{FilePath}.bk";
		File.Delete(tmpFilePath);
		File.Delete(bkFilePath);
		File.WriteAllText(tmpFilePath, jsonString);
		try
		{
			File.Move(FilePath, bkFilePath);
		}
		catch (FileNotFoundException) { }

		File.Move(tmpFilePath, FilePath);
		File.Delete(bkFilePath);
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
				string jsonString = File.ReadAllText(FilePath);
				var appData = JsonSerializer.Deserialize<T>(jsonString, JsonSerializerOptions);
				if (appData != null)
				{
					return appData;
				}
			}
			catch (FileNotFoundException)
			{
			}
			catch (JsonException)
			{
			}
		}

		T newAppData = new();
		newAppData.Save();
		return newAppData;
	}
}
