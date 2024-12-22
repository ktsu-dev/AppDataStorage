namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions.TestingHelpers;
using ktsu.StrongStrings;

public sealed record class StrongName : StrongStringAbstract<StrongName> { }

public sealed class Storage : AppData<Storage>
{
	public string WeakName { get; set; } = "";

	public StrongName StrongName { get; set; } = new();

	public Dictionary<StrongName, string> StrongNames { get; init; } = [];
}

[TestClass]
public sealed class StrongStringTests
{
	[TestInitialize]
	public void Setup()
	{
		AppData.FileSystem = new MockFileSystem();
		AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", "/app");
	}

	[TestMethod]
	public void TestStrongStringInstantiation()
	{
		var s = new StrongName();
		Assert.AreEqual("", s);
	}

	[TestMethod]
	public void TestStrongStrings()
	{
		using var storage1 = new Storage();
		AppData.EnsureDirectoryExists(storage1.FilePath);
		AppData.FileSystem.File.Delete(storage1.FilePath);
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

	[TestMethod]
	public void TestWeakNameProperty()
	{
		using var storage = new Storage();
		storage.WeakName = "TestWeakName";
		Assert.AreEqual("TestWeakName", storage.WeakName);
	}

	[TestMethod]
	public void TestStrongNameProperty()
	{
		using var storage = new Storage();
		storage.StrongName = (StrongName)"TestStrongName";
		Assert.AreEqual((StrongName)"TestStrongName", storage.StrongName);
	}

	[TestMethod]
	public void TestStrongNamesDictionary()
	{
		using var storage = new Storage();
		storage.StrongNames.Add((StrongName)"Key1", "Value1");
		storage.StrongNames.Add((StrongName)"Key2", "Value2");

		Assert.AreEqual("Value1", storage.StrongNames[(StrongName)"Key1"]);
		Assert.AreEqual("Value2", storage.StrongNames[(StrongName)"Key2"]);
	}

	[TestMethod]
	public void TestSaveAndLoad()
	{
		using var storage1 = new Storage();
		AppData.EnsureDirectoryExists(storage1.FilePath);
		AppData.FileSystem.File.Delete(storage1.FilePath);
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
