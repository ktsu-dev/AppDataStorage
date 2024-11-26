// Ignore Spelling: App

namespace ktsu.AppDataStorage.Tests;

using System;
using System.IO.Abstractions.TestingHelpers;

[TestClass]
internal sealed class AppDataTests
{
	[TestInitialize]
	public void Setup()
	{
		AppData.FileSystem = new MockFileSystem();
		AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", "/app");
	}

	internal sealed class TestAppData : AppData<TestAppData>
	{
		public string Data { get; set; } = string.Empty;
	}

	[TestMethod]
	public void TestSaveCreatesFile()
	{
		var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		var filePath = TestAppData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestSaveCleansBackupFile()
	{
		var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		string backupFilePath = TestAppData.FilePath + ".bk";
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should not exist initially.");

		appData.Save();

		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should get cleaned up.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesNewFile()
	{
		_ = TestAppData.LoadOrCreate();

		var filePath = TestAppData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not created.");
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
		AppData.EnsureDirectoryExists(filePath);
		AppData.FileSystem.File.WriteAllText(filePath, "{ invalid json }");

		var appData = TestAppData.LoadOrCreate();

		Assert.AreEqual(string.Empty, appData.Data, "Invalid file should result in new instance with default values.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsCreatesDirectory()
	{
		var path = TestAppData.FilePath.DirectoryPath;
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(path), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(TestAppData.FilePath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(path), "Directory was not created.");
	}
}
