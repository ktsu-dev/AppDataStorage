// Copyright (c) ktsu.dev
// All rights reserved.
// Licensed under the MIT license.

namespace ktsu.AppDataStorage.Test;

using System;
using System.IO.Abstractions.TestingHelpers;
using System.Net.Sockets;
using System.Text.Json;

using ktsu.CaseConverter;
using ktsu.Extensions;
using ktsu.StrongPaths;

[TestClass]
public sealed class AppDataTests
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

	internal sealed class TestAppData : AppData<TestAppData>
	{
		public string Data { get; set; } = string.Empty;
	}

	[TestMethod]
	public void TestSaveCreatesFile()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		appData.Save();

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestSaveCleansBackupFile()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		appData.Save();

		string backupFilePath = appData.FilePath + ".bk";
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should not exist initially.");

		appData.Save();

		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should get cleaned up.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsForFilePath()
	{
		AbsoluteFilePath filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		AbsoluteDirectoryPath dirPath = filePath.DirectoryPath;
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(filePath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsForDirectoryPath()
	{
		AbsoluteDirectoryPath dirPath = (AppData.Path / "testDir".As<RelativeDirectoryPath>()).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(dirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestMakeTempFilePathCreatesCorrectPath()
	{
		AbsoluteFilePath filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		AbsoluteFilePath tempFilePath = AppData.MakeTempFilePath(filePath);
		Assert.AreEqual(filePath + ".tmp", tempFilePath, "Temp file path does not match expected value.");
	}

	[TestMethod]
	public void TestMakeBackupFilePathCreatesCorrectPath()
	{
		AbsoluteFilePath filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(filePath);
		Assert.AreEqual(filePath + ".bk", backupFilePath, "Backup file path does not match expected value.");
	}

	[TestMethod]
	public void TestWriteTextCreatesFile()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		AppData.WriteText(appData, "Test data");

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestWriteTextCreatesBackupFileOnOverwrite()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		AppData.WriteText(appData, "Initial data");

		AppData.WriteText(appData, "Updated data");

		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should be cleaned up after save.");
	}

	[TestMethod]
	public void TestReadTextReturnsCorrectData()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		AppData.WriteText(appData, "Test data");

		string text = AppData.ReadText(appData);
		Assert.AreEqual("Test data", text, "Read text does not match written text.");
	}

	[TestMethod]
	public void TestReadTextRestoresFromBackupIfMainFileMissing()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		AppData.WriteText(appData, "Test data");

		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		AppData.FileSystem.File.Copy(appData.FilePath, backupFilePath);
		AppData.FileSystem.File.Delete(appData.FilePath);

		string text = AppData.ReadText(appData);
		Assert.AreEqual("Test data", text, "Read text does not match backup text.");
		Assert.IsTrue(AppData.FileSystem.File.Exists(appData.FilePath), "Main file should be restored from backup.");
	}

	[TestMethod]
	public void TestQueueSaveSetsSaveQueuedTime()
	{
		using TestAppData appData = new();
		DateTime beforeQueueTime = DateTime.UtcNow;

		appData.QueueSave();

		Assert.IsTrue(appData.SaveQueuedTime >= beforeQueueTime, "SaveQueuedTime was not set correctly.");
	}

	[TestMethod]
	public void TestSaveIfRequiredSavesDataAfterDebounceTime()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		appData.QueueSave();
		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100)); // Wait for more than debounce time

		appData.SaveIfRequired();

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not saved.");

		TestAppData? fileContents = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(filePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(fileContents, "Saved data should be deserialized correctly.");
		Assert.AreEqual("Test data", fileContents.Data, "Saved data does not match.");
	}

	[TestMethod]
	public void TestSaveIfRequiredDoesNotSaveBeforeDebounceTime()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		appData.QueueSave();

		appData.SaveIfRequired();

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsFalse(AppData.FileSystem.File.Exists(filePath), "File should not be saved due to debounce.");
	}

	[TestMethod]
	public void TestDisposeSavesDataIfSaveQueued()
	{
		TestAppData appData = new()
		{ Data = "Test data" };
		appData.QueueSave();

		appData.Dispose();

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File should be saved upon disposal.");
	}

	[TestMethod]
	public void TestDisposeDoesNotSaveIfNoSaveQueued()
	{
		TestAppData appData = new()
		{ Data = "Test data" };

		appData.Dispose();

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsFalse(AppData.FileSystem.File.Exists(filePath), "File should not be saved if no save was queued.");
	}

	[TestMethod]
	public void TestEnsureDisposeOnExitRegistersEvent()
	{
		using TestAppData appData = new();

		appData.EnsureDisposeOnExit();

		Assert.IsTrue(appData.IsDisposeRegistered, "DisposeOnExit should register an event.");
	}

	[TestMethod]
	public void TestIsSaveQueuedReturnsCorrectValue()
	{
		using TestAppData appData = new();
		Assert.IsFalse(appData.IsSaveQueued(), "Save should not be queued initially.");

		appData.QueueSave();

		Assert.IsTrue(appData.IsSaveQueued(), "Save should be queued after QueueSave is called.");
	}

	[TestMethod]
	public void TestIsDebounceTimeElapsedReturnsCorrectValue()
	{
		using TestAppData appData = new();

		appData.QueueSave();
		Assert.IsFalse(appData.IsDoubounceTimeElapsed(), "Debounce should not have elapsed immediately after QueueSave.");

		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100));

		Assert.IsTrue(appData.IsDoubounceTimeElapsed(), "Debounce should have elapsed after waiting.");
	}

	[TestMethod]
	public void TestLoadOrCreateHandlesCorruptFile()
	{
		AbsoluteFilePath filePath = TestAppData.Get().FilePath;
		AppData.EnsureDirectoryExists(filePath);
		AppData.FileSystem.File.WriteAllText(filePath, "Invalid JSON");

		TestAppData appData = TestAppData.LoadOrCreate();

		Assert.IsNotNull(appData, "LoadOrCreate should return a new instance if file is corrupt.");
		Assert.AreEqual(string.Empty, appData.Data, "Data should be default if loaded from corrupt file.");
	}

	[TestMethod]
	public void TestMultipleSavesOnlyWriteOnceWithinDebouncePeriod()
	{
		using TestAppData appData = new()
		{ Data = "Data1" };
		appData.Save();

		appData.Data = "Data2";
		appData.QueueSave();
		appData.SaveIfRequired();

		TestAppData? fileContent = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(appData.FilePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(fileContent, "File should not be empty after save.");
		Assert.AreEqual("Data1", fileContent.Data, "Data should not be updated due to debounce.");

		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100));
		appData.SaveIfRequired();

		fileContent = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(appData.FilePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(fileContent, "File should not be empty after debounce period.");
		Assert.AreEqual("Data2", fileContent.Data, "Data should be updated after debounce period.");
	}

	[TestMethod]
	public void TestFileNameUsesSnakeCase()
	{
		using TestAppData appData = new();

		string expectedFileName = $"{nameof(TestAppData).ToSnakeCase()}.json";
		Assert.AreEqual(expectedFileName, appData.FileName.ToString(), "FileName should be in snake_case.");
	}

	[TestMethod]
	public void TestAppDomainIsSetCorrectly()
	{
		string appDomainName = AppData.AppDomain.ToString();
		Assert.AreEqual(AppDomain.CurrentDomain.FriendlyName, appDomainName, "AppDomain should match current domain's friendly name.");
	}

	[TestMethod]
	public void TestAppDataPathIsSetCorrectly()
	{
		string expectedPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData) + "\\" + AppData.AppDomain;
		Assert.AreEqual(expectedPath, AppData.Path.ToString(), "AppData path should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithNullSubdirectoryAndFileName()
	{
		TestAppData appData = TestAppData.LoadOrCreate(null, null);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.IsNull(appData.Subdirectory, "Subdirectory should be null.");
		Assert.IsNull(appData.FileNameOverride, "FileNameOverride should be null.");
	}

	[TestMethod]
	public void TestConfigureForTesting()
	{
		AppData.ConfigureForTesting(() => new MockFileSystem());

		Assert.IsInstanceOfType<MockFileSystem>(AppData.FileSystem, "FileSystem should be a MockFileSystem instance.");
	}

	[TestMethod]
	public void TestAppDataSerializationIncludesFields()
	{
		using TestAppData appData = new();
		string json = JsonSerializer.Serialize(appData, AppData.JsonSerializerOptions);

		Assert.IsTrue(json.Contains("\"Data\""), "Serialized JSON should include fields.");
	}

	[TestMethod]
	public void TestSaveThrowsExceptionIfSerializationFails()
	{
		using FaultyAppData appData = new();
		Assert.ThrowsException<NotSupportedException>(appData.Save);
	}

	internal sealed class FaultyAppData : AppData<FaultyAppData>
	{
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Performance", "CA1822:Mark members as static", Justification = "<Pending>")]
		public object UnsupportedProperty => new Socket(SocketType.Stream, ProtocolType.Tcp);
	}

	[TestMethod]
	public void TestDisposeCanBeCalledMultipleTimes()
	{
		TestAppData appData = new();
		appData.QueueSave();
		appData.Dispose();
		appData.Dispose();

		Assert.IsTrue(appData.IsDisposeRegistered, "IsDisposeRegistered should remain true after multiple disposals.");
	}

	[TestMethod]
	public void TestGetReturnsSameInstance()
	{
		TestAppData appData1 = TestAppData.Get();
		TestAppData appData2 = TestAppData.Get();

		Assert.AreSame(appData1, appData2, "Get should return the same instance.");
	}

	[TestMethod]
	public void TestLoadOrCreateDoesNotOverwriteExistingData()
	{
		TestAppData appData = TestAppData.Get();
		appData.Data = "Persistent Data";
		appData.Save();

		TestAppData loadedAppData = TestAppData.LoadOrCreate();
		Assert.AreEqual("Persistent Data", loadedAppData.Data, "Data should persist across LoadOrCreate calls.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithNullFilePath()
	{
		AbsoluteFilePath path = null!;
		AppData.EnsureDirectoryExists(path);
		// No exception should be thrown
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithEmptyFilePath()
	{
		AbsoluteFilePath path = new();
		AppData.EnsureDirectoryExists(path);
		// No exception should be thrown
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithNullDirectoryPath()
	{
		AbsoluteDirectoryPath path = null!;
		AppData.EnsureDirectoryExists(path);
		// No exception should be thrown
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithEmptyDirectoryPath()
	{
		AbsoluteDirectoryPath path = new();
		AppData.EnsureDirectoryExists(path);
		// No exception should be thrown
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithValidFilePath()
	{
		AbsoluteFilePath filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		AbsoluteDirectoryPath dirPath = filePath.DirectoryPath;
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(filePath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithValidDirectoryPath()
	{
		AbsoluteDirectoryPath dirPath = (AppData.Path / "testDir".As<RelativeDirectoryPath>()).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(dirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithNestedDirectories()
	{
		AbsoluteDirectoryPath dirPath = (AppData.Path / "nested/dir/structure".As<RelativeDirectoryPath>()).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Nested directory structure should not exist initially.");

		AppData.EnsureDirectoryExists(dirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Nested directory structure was not created.");
	}

	[TestMethod]
	public void TestSaveCreatesBackupIfInitialSaveFails()
	{
		using TestAppData appData = new()
		{ Data = "Test data" };
		appData.Save();

		MockFileData mockFile = ((MockFileSystem)AppData.FileSystem).GetFile(appData.FilePath);
		mockFile.AllowedFileShare = FileShare.None;

		Assert.ThrowsException<IOException>(appData.Save);

		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should not exist if save fails.");
	}

	[TestMethod]
	public void TestLoadOrCreateRecoversFromCorruptBackup()
	{
		AbsoluteFilePath filePath = TestAppData.Get().FilePath;
		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(filePath);

		AppData.EnsureDirectoryExists(filePath);
		AppData.EnsureDirectoryExists(backupFilePath);

		AppData.FileSystem.File.WriteAllText(filePath, "Invalid JSON");
		AppData.FileSystem.File.WriteAllText(backupFilePath, "Invalid JSON");

		TestAppData appData = TestAppData.LoadOrCreate();

		Assert.IsNotNull(appData, "LoadOrCreate should return a new instance if both main and backup files are corrupt.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesDirectoryIfNotExists()
	{
		TestAppData appData = TestAppData.LoadOrCreate();

		AbsoluteDirectoryPath dirPath = appData.FilePath.DirectoryPath;
		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory should be created if it doesn't exist.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsHandlesRelativePaths()
	{
		RelativeDirectoryPath relativeDirPath = "relative/dir".As<RelativeDirectoryPath>();
		AbsoluteDirectoryPath absoluteDirPath = (AppData.Path / relativeDirPath).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(absoluteDirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(absoluteDirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(absoluteDirPath), "Directory should be created.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithSubdirectory()
	{
		RelativeDirectoryPath subdirectory = "subdir".As<RelativeDirectoryPath>();
		TestAppData appData = TestAppData.LoadOrCreate(subdirectory);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(subdirectory, appData.Subdirectory, "Subdirectory should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithFileName()
	{
		FileName fileName = "custom_file.json".As<FileName>();
		TestAppData appData = TestAppData.LoadOrCreate(fileName);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(fileName, appData.FileNameOverride, "FileNameOverride should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithSubdirectoryAndFileName()
	{
		RelativeDirectoryPath subdirectory = "subdir".As<RelativeDirectoryPath>();
		FileName fileName = "custom_file.json".As<FileName>();
		TestAppData appData = TestAppData.LoadOrCreate(subdirectory, fileName);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(subdirectory, appData.Subdirectory, "Subdirectory should be set correctly.");
		Assert.AreEqual(fileName, appData.FileNameOverride, "FileNameOverride should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesNewInstanceIfFileDoesNotExist()
	{
		TestAppData appData = TestAppData.LoadOrCreate();

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(string.Empty, appData.Data, "Data should be default if file does not exist.");
	}

	[TestMethod]
	public void TestLoadOrCreateLoadsExistingData()
	{
		TestAppData appData = TestAppData.Get();
		appData.Data = "Persistent Data";
		appData.Save();

		TestAppData loadedAppData = TestAppData.LoadOrCreate();
		Assert.AreEqual("Persistent Data", loadedAppData.Data, "Data should persist across LoadOrCreate calls.");
	}

	[TestMethod]
	public void TestQueueSaveStaticMethod()
	{
		DateTime beforeQueueTime = DateTime.UtcNow;

		TestAppData.QueueSave();

		TestAppData appData = TestAppData.Get();
		Assert.IsTrue(appData.SaveQueuedTime >= beforeQueueTime, "SaveQueuedTime was not set correctly.");
	}

	[TestMethod]
	public void TestSaveIfRequiredStaticMethod()
	{
		TestAppData appData = TestAppData.Get();
		appData.Data = "Test data";
		appData.QueueSave();
		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100)); // Wait for more than debounce time

		TestAppData.SaveIfRequired();

		AbsoluteFilePath filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not saved.");

		TestAppData? testAppData = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(filePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(testAppData, "Saved data should be deserialized correctly.");
		Assert.AreEqual("Test data", testAppData.Data, "Saved data does not match.");
	}
}
