// Copyright (c) ktsu.dev
// All rights reserved.
// Licensed under the MIT license.

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
	[ClassInitialize]
	public static void ClassSetup(TestContext _)
	{
		AppData.ConfigureForTesting(() => new MockFileSystem());
		AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", "/app");
	}

	[TestInitialize]
	public void SetupTest()
	{
		// Clear any cached instance so the factory creates a fresh one for this test
		AppData.ClearCachedFileSystem();
	}

	private static void CreateAndSetupStorage(out Storage storage)
	{
		using Storage storage1 = new();
		AppData.EnsureDirectoryExists(storage1.FilePath);
		AppData.FileSystem.File.Delete(storage1.FilePath);
		storage = Storage.LoadOrCreate();
		storage.WeakName = "WeakName";
		storage.StrongName = (StrongName)"StrongName";
		storage.StrongNames.Add((StrongName)"StrongName1", "StrongName1");
		storage.StrongNames.Add((StrongName)"StrongName2", "StrongName2");
	}

	private static void VerifyStorageData(Storage originalStorage, Storage loadedStorage)
	{
		Assert.AreEqual(originalStorage.WeakName, loadedStorage.WeakName);
		Assert.AreEqual(originalStorage.StrongName, loadedStorage.StrongName);
		foreach ((StrongName key, string value) in originalStorage.StrongNames)
		{
			Assert.AreEqual(value, loadedStorage.StrongNames[key]);
		}
	}

	[TestMethod]
	public void TestStrongStringInstantiation()
	{
		StrongName s = new();
		Assert.AreEqual("", s);
	}

	[TestMethod]
	public void TestStrongStrings()
	{
		CreateAndSetupStorage(out Storage storage);
		using (storage)
		{
			storage.Save();
		}

		using Storage storage2 = Storage.LoadOrCreate();
		VerifyStorageData(storage, storage2);
	}

	[TestMethod]
	public void TestWeakNameProperty()
	{
		using Storage storage = new();
		storage.WeakName = "TestWeakName";
		Assert.AreEqual("TestWeakName", storage.WeakName);
	}

	[TestMethod]
	public void TestStrongNameProperty()
	{
		using Storage storage = new();
		storage.StrongName = (StrongName)"TestStrongName";
		Assert.AreEqual((StrongName)"TestStrongName", storage.StrongName);
	}

	[TestMethod]
	public void TestStrongNamesDictionary()
	{
		using Storage storage = new();
		storage.StrongNames.Add((StrongName)"Key1", "Value1");
		storage.StrongNames.Add((StrongName)"Key2", "Value2");

		Assert.AreEqual("Value1", storage.StrongNames[(StrongName)"Key1"]);
		Assert.AreEqual("Value2", storage.StrongNames[(StrongName)"Key2"]);
	}

	[TestMethod]
	public void TestSaveAndLoad()
	{
		CreateAndSetupStorage(out Storage storage);
		using (storage)
		{
			storage.Save();
		}

		using Storage storage2 = Storage.LoadOrCreate();
		VerifyStorageData(storage, storage2);
	}
}
