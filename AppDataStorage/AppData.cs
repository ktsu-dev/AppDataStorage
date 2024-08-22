// Ignore Spelling: App Serializer

namespace ktsu.io.AppDataStorage;

using System.IO.Abstractions;
using System.Text.Json;
using System.Text.Json.Serialization;
using ktsu.io.CaseConverter;
using ktsu.io.StrongPaths;
using ktsu.io.ToStringJsonConverter;

/// <summary>
/// Static helpers
/// </summary>
public static class AppData
{
	/// <summary>
	/// The path where persistent data is stored for this application
	/// </summary>
	public static AbsoluteDirectoryPath Path => AppDataPath / AppDomain;
	private static RelativeDirectoryPath AppDomain => (RelativeDirectoryPath)System.AppDomain.CurrentDomain.FriendlyName;
	private static AbsoluteDirectoryPath AppDataPath => (AbsoluteDirectoryPath)Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);

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

	internal static IFileSystem FileSystem { get; set; } = new FileSystem();

	internal static void EnsureDirectoryExists(AbsoluteFilePath path)
	{
		var dirPath = path.DirectoryPath;
		EnsureDirectoryExists(dirPath);
	}

	internal static void EnsureDirectoryExists(AbsoluteDirectoryPath path)
	{
		if (!string.IsNullOrEmpty(path))
		{
			FileSystem.Directory.CreateDirectory(path);
		}
	}

	internal static AbsoluteFilePath MakeTempFilePath(AbsoluteFilePath filePath) => filePath.WithSuffix(".tmp");
	internal static AbsoluteFilePath MakeBackupFilePath(AbsoluteFilePath filePath) => filePath.WithSuffix(".bk");

	/// <summary>
	/// Write text to a file within this applications app data folder
	/// </summary>
	/// <param name="fileName">The name of the file to write</param>
	/// <param name="text">The text to write</param>
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
	/// Reads text from a file within this applications app data folder
	/// </summary>
	/// <param name="fileName">The name of the file to read</param>
	/// <returns>A string containing the text in the file</returns>
	public static string ReadText(FileName fileName)
	{
		var filePath = Path / fileName;
		try
		{
			return FileSystem.File.ReadAllText(filePath);
		}
		catch (FileNotFoundException)
		{
			var bkFilePath = MakeBackupFilePath(filePath);
			if (bkFilePath.Exists)
			{
				EnsureDirectoryExists(filePath);
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
public abstract class AppData<T> where T : AppData<T>, new()
{
	private static FileName FileName => (FileName)$"{typeof(T).Name.ToSnakeCase()}.json";
	internal static AbsoluteFilePath FilePath => AppData.Path / FileName;

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
