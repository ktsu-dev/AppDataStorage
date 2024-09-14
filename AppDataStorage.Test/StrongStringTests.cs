namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions.TestingHelpers;
using ktsu.StrongStrings;

public sealed record class StrongName : StrongStringAbstract<StrongName> { }

public class Storage : AppData<Storage>
{
	public string WeakName { get; set; } = "";

	public StrongName StrongName { get; set; } = new();

	public Dictionary<StrongName, string> StrongNames { get; init; } = [];
}

[TestClass]
public class StrongStringTests
{
	[TestInitialize]
	public void Setup()
	{
		AppData.FileSystem = new MockFileSystem();
		AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", "/app");
	}

	[TestMethod]
	public void TestStrongStrings()
	{
		AppData.EnsureDirectoryExists(Storage.FilePath);
		AppData.FileSystem.File.Delete(Storage.FilePath);
		var storage = Storage.LoadOrCreate();
		storage.WeakName = "WeakName";
		storage.StrongName = (StrongName)"StrongName";
		storage.StrongNames.Add((StrongName)"StrongName1", "StrongName1");
		storage.StrongNames.Add((StrongName)"StrongName2", "StrongName2");
		storage.Save();

		var storage2 = Storage.LoadOrCreate();
		Assert.AreEqual(storage.WeakName, storage2.WeakName);
		Assert.AreEqual(storage.StrongName, storage2.StrongName);
		foreach (var (key, value) in storage.StrongNames)
		{
			Assert.AreEqual(value, storage2.StrongNames[key]);
		}
	}
}
