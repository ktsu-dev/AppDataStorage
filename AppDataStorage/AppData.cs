

namespace ktsu.io.AppDataStorage;

public abstract class AppData
{
	private static string AppName => Path.GetFileNameWithoutExtension(AppDomain.CurrentDomain.FriendlyName);
	private static string AppDataPath => Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
	private static string StoragePath => Path.Combine(AppDataPath, AppName);
	private string Filename => $"{GetType().Name.ToLowerInvariant()}.json";
	private string FilePath => Path.Join(StoragePath, Filename);
	public void Save() => LoadAndSave(load: false);
	public void Load() => LoadAndSave(save: false);

	public static JsonSerializerSettings JsonSettings { get; } = new()
	{
		ContractResolver = new RealNameContractResolver(),
		Formatting = Formatting.Indented,
		DefaultValueHandling = DefaultValueHandling.Include,
		Converters = { new StringEnumConverter() },
	};

	public void LoadAndSave() => LoadAndSave(load: true, save: true);

	private void LoadAndSave(bool load = true, bool save = true)
	{
		Directory.CreateDirectory(StoragePath);
		string json;
		if (load)
		{
			try
			{
				json = File.ReadAllText(FilePath);
				lock (this)
				{
					JsonConvert.PopulateObject(json, this, JsonSettings);
				}
			}
			catch (FileNotFoundException) { }
		}

		if (save)
		{
			lock (this)
			{
				json = JsonConvert.SerializeObject(this, JsonSettings);
			}

			File.WriteAllText(FilePath, json);
		}
	}
}
