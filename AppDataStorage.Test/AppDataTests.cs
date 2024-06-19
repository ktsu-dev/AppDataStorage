// Ignore Spelling: App

namespace ktsu.io.AppDataStorage.Tests;

using System;
using System.IO.Abstractions.TestingHelpers;

[TestClass]
public class AppDataTests
{
	[TestInitialize]
	public void Setup()
	{
		AppDataShared.FileSystem = new MockFileSystem();
		AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", "/app");
	}

	public class TestAppData : AppData<TestAppData>
	{
		public string Data { get; set; } = string.Empty;
	}

	[TestMethod]
	public void TestSaveCreatesFile()
	{
		var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		var filePath = TestAppData.FilePath;
		Assert.IsTrue(AppDataShared.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestSaveCleansBackupFile()
	{
		var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		string backupFilePath = TestAppData.FilePath + ".bk";
		Assert.IsFalse(AppDataShared.FileSystem.File.Exists(backupFilePath), "Backup file should not exist initially.");

		appData.Save();

		Assert.IsFalse(AppDataShared.FileSystem.File.Exists(backupFilePath), "Backup file should get cleaned up.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesNewFile()
	{
		_ = TestAppData.LoadOrCreate();

		var filePath = TestAppData.FilePath;
		Assert.IsTrue(AppDataShared.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestLoadOrCreateLoadsExistingFile()
	{
		var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		var loadedAppData = TestAppData.LoadOrCreate();
		Assert.AreEqual(appData.Data, loadedAppData.Data, "Loaded data does not match saved data.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesNewFileWhenInvalid()
	{
		var filePath = TestAppData.FilePath;
		TestAppData.EnsureDirectoryExists(filePath);
		AppDataShared.FileSystem.File.WriteAllText(filePath, "{ invalid json }");

		var appData = TestAppData.LoadOrCreate();

		Assert.AreEqual(string.Empty, appData.Data, "Invalid file should result in new instance with default values.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsCreatesDirectory()
	{
		var path = TestAppData.FilePath.DirectoryPath;
		Assert.IsFalse(AppDataShared.FileSystem.Directory.Exists(path), "Directory should not exist initially.");

		TestAppData.EnsureDirectoryExists(TestAppData.FilePath);

		Assert.IsTrue(AppDataShared.FileSystem.Directory.Exists(path), "Directory was not created.");
	}
}
