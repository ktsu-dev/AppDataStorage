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
		using var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		var filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestSaveCleansBackupFile()
	{
		using var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		string backupFilePath = appData.FilePath + ".bk";
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should not exist initially.");

		appData.Save();

		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should get cleaned up.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsForFilePath()
	{
		var filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		var dirPath = filePath.DirectoryPath;
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(filePath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsForDirectoryPath()
	{
		var dirPath = (AppData.Path / "testDir".As<RelativeDirectoryPath>()).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(dirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestMakeTempFilePathCreatesCorrectPath()
	{
		var filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		var tempFilePath = AppData.MakeTempFilePath(filePath);
		Assert.AreEqual(filePath + ".tmp", tempFilePath, "Temp file path does not match expected value.");
	}

	[TestMethod]
	public void TestMakeBackupFilePathCreatesCorrectPath()
	{
		var filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		var backupFilePath = AppData.MakeBackupFilePath(filePath);
		Assert.AreEqual(filePath + ".bk", backupFilePath, "Backup file path does not match expected value.");
	}

	[TestMethod]
	public void TestWriteTextCreatesFile()
	{
		using var appData = new TestAppData { Data = "Test data" };
		AppData.WriteText(appData, "Test data");

		var filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not created.");
	}

	[TestMethod]
	public void TestWriteTextCreatesBackupFileOnOverwrite()
	{
		using var appData = new TestAppData { Data = "Test data" };
		AppData.WriteText(appData, "Initial data");

		AppData.WriteText(appData, "Updated data");

		var backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should be cleaned up after save.");
	}

	[TestMethod]
	public void TestReadTextReturnsCorrectData()
	{
		using var appData = new TestAppData { Data = "Test data" };
		AppData.WriteText(appData, "Test data");

		string text = AppData.ReadText(appData);
		Assert.AreEqual("Test data", text, "Read text does not match written text.");
	}

	[TestMethod]
	public void TestReadTextRestoresFromBackupIfMainFileMissing()
	{
		using var appData = new TestAppData { Data = "Test data" };
		AppData.WriteText(appData, "Test data");

		var backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		AppData.FileSystem.File.Copy(appData.FilePath, backupFilePath);
		AppData.FileSystem.File.Delete(appData.FilePath);

		string text = AppData.ReadText(appData);
		Assert.AreEqual("Test data", text, "Read text does not match backup text.");
		Assert.IsTrue(AppData.FileSystem.File.Exists(appData.FilePath), "Main file should be restored from backup.");
	}

	[TestMethod]
	public void TestQueueSaveSetsSaveQueuedTime()
	{
		using var appData = new TestAppData();
		var beforeQueueTime = DateTime.UtcNow;

		appData.QueueSave();

		Assert.IsTrue(appData.SaveQueuedTime >= beforeQueueTime, "SaveQueuedTime was not set correctly.");
	}

	[TestMethod]
	public void TestSaveIfRequiredSavesDataAfterDebounceTime()
	{
		using var appData = new TestAppData { Data = "Test data" };
		appData.QueueSave();
		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100)); // Wait for more than debounce time

		appData.SaveIfRequired();

		var filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not saved.");

		var fileContents = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(filePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(fileContents, "Saved data should be deserialized correctly.");
		Assert.AreEqual("Test data", fileContents.Data, "Saved data does not match.");
	}

	[TestMethod]
	public void TestSaveIfRequiredDoesNotSaveBeforeDebounceTime()
	{
		using var appData = new TestAppData { Data = "Test data" };
		appData.QueueSave();

		appData.SaveIfRequired();

		var filePath = appData.FilePath;
		Assert.IsFalse(AppData.FileSystem.File.Exists(filePath), "File should not be saved due to debounce.");
	}

	[TestMethod]
	public void TestDisposeSavesDataIfSaveQueued()
	{
		var appData = new TestAppData { Data = "Test data" };
		appData.QueueSave();

		appData.Dispose();

		var filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File should be saved upon disposal.");
	}

	[TestMethod]
	public void TestDisposeDoesNotSaveIfNoSaveQueued()
	{
		var appData = new TestAppData { Data = "Test data" };

		appData.Dispose();

		var filePath = appData.FilePath;
		Assert.IsFalse(AppData.FileSystem.File.Exists(filePath), "File should not be saved if no save was queued.");
	}

	[TestMethod]
	public void TestEnsureDisposeOnExitRegistersEvent()
	{
		using var appData = new TestAppData();

		appData.EnsureDisposeOnExit();

		Assert.IsTrue(appData.IsDisposeRegistered, "DisposeOnExit should register an event.");
	}

	[TestMethod]
	public void TestIsSaveQueuedReturnsCorrectValue()
	{
		using var appData = new TestAppData();
		Assert.IsFalse(appData.IsSaveQueued(), "Save should not be queued initially.");

		appData.QueueSave();

		Assert.IsTrue(appData.IsSaveQueued(), "Save should be queued after QueueSave is called.");
	}

	[TestMethod]
	public void TestIsDebounceTimeElapsedReturnsCorrectValue()
	{
		using var appData = new TestAppData();

		appData.QueueSave();
		Assert.IsFalse(appData.IsDoubounceTimeElapsed(), "Debounce should not have elapsed immediately after QueueSave.");

		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100));

		Assert.IsTrue(appData.IsDoubounceTimeElapsed(), "Debounce should have elapsed after waiting.");
	}

	[TestMethod]
	public void TestLoadOrCreateHandlesCorruptFile()
	{
		var filePath = TestAppData.InternalState.FilePath;
		AppData.EnsureDirectoryExists(filePath);
		AppData.FileSystem.File.WriteAllText(filePath, "Invalid JSON");

		var appData = TestAppData.LoadOrCreate();

		Assert.IsNotNull(appData, "LoadOrCreate should return a new instance if file is corrupt.");
		Assert.AreEqual(string.Empty, appData.Data, "Data should be default if loaded from corrupt file.");
	}

	[TestMethod]
	public void TestMultipleSavesOnlyWriteOnceWithinDebouncePeriod()
	{
		using var appData = new TestAppData { Data = "Data1" };
		appData.Save();

		appData.Data = "Data2";
		appData.QueueSave();
		appData.SaveIfRequired();

		var fileContent = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(appData.FilePath), AppData.JsonSerializerOptions);
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
		using var appData = new TestAppData();

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
		var appData = TestAppData.LoadOrCreate(null, null);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.IsNull(appData.Subdirectory, "Subdirectory should be null.");
		Assert.IsNull(appData.FileNameOverride, "FileNameOverride should be null.");
	}

	[TestMethod]
	public void TestFileSystemSetter()
	{
		var mockFileSystem = new MockFileSystem();
		AppData.FileSystem = mockFileSystem;

		Assert.AreEqual(mockFileSystem, AppData.FileSystem, "FileSystem should be set correctly.");
	}

	[TestMethod]
	public void TestAppDataSerializationIncludesFields()
	{
		using var appData = new TestAppData();
		string json = JsonSerializer.Serialize(appData, AppData.JsonSerializerOptions);

		Assert.IsTrue(json.Contains("\"Data\""), "Serialized JSON should include fields.");
	}

	[TestMethod]
	public void TestSaveThrowsExceptionIfSerializationFails()
	{
		using var appData = new FaultyAppData();
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
		var appData = new TestAppData();
		appData.QueueSave();
		appData.Dispose();
		appData.Dispose();

		Assert.IsTrue(appData.IsDisposeRegistered, "IsDisposeRegistered should remain true after multiple disposals.");
	}

	[TestMethod]
	public void TestGetReturnsSameInstance()
	{
		var appData1 = TestAppData.Get();
		var appData2 = TestAppData.Get();

		Assert.AreSame(appData1, appData2, "Get should return the same instance.");
	}

	[TestMethod]
	public void TestLoadOrCreateDoesNotOverwriteExistingData()
	{
		var appData = TestAppData.Get();
		appData.Data = "Persistent Data";
		appData.Save();

		var loadedAppData = TestAppData.LoadOrCreate();
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
		var path = new AbsoluteFilePath();
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
		var path = new AbsoluteDirectoryPath();
		AppData.EnsureDirectoryExists(path);
		// No exception should be thrown
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithValidFilePath()
	{
		var filePath = (AppData.Path / "test.txt".As<FileName>()).As<AbsoluteFilePath>();
		var dirPath = filePath.DirectoryPath;
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(filePath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithValidDirectoryPath()
	{
		var dirPath = (AppData.Path / "testDir".As<RelativeDirectoryPath>()).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(dirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory was not created.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithNestedDirectories()
	{
		var dirPath = (AppData.Path / "nested/dir/structure".As<RelativeDirectoryPath>()).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), "Nested directory structure should not exist initially.");

		AppData.EnsureDirectoryExists(dirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Nested directory structure was not created.");
	}

	[TestMethod]
	public void TestSaveCreatesBackupIfInitialSaveFails()
	{
		using var appData = new TestAppData { Data = "Test data" };
		appData.Save();

		var mockFile = ((MockFileSystem)AppData.FileSystem).GetFile(appData.FilePath);
		mockFile.AllowedFileShare = FileShare.None;

		Assert.ThrowsException<IOException>(appData.Save);

		var backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Backup file should not exist if save fails.");
	}

	[TestMethod]
	public void TestLoadOrCreateRecoversFromCorruptBackup()
	{
		var filePath = TestAppData.InternalState.FilePath;
		var backupFilePath = AppData.MakeBackupFilePath(filePath);

		AppData.EnsureDirectoryExists(filePath);
		AppData.EnsureDirectoryExists(backupFilePath);

		AppData.FileSystem.File.WriteAllText(filePath, "Invalid JSON");
		AppData.FileSystem.File.WriteAllText(backupFilePath, "Invalid JSON");

		var appData = TestAppData.LoadOrCreate();

		Assert.IsNotNull(appData, "LoadOrCreate should return a new instance if both main and backup files are corrupt.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesDirectoryIfNotExists()
	{
		var appData = TestAppData.LoadOrCreate();

		var dirPath = appData.FilePath.DirectoryPath;
		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory should be created if it doesn't exist.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsHandlesRelativePaths()
	{
		var relativeDirPath = "relative/dir".As<RelativeDirectoryPath>();
		var absoluteDirPath = (AppData.Path / relativeDirPath).As<AbsoluteDirectoryPath>();
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(absoluteDirPath), "Directory should not exist initially.");

		AppData.EnsureDirectoryExists(absoluteDirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(absoluteDirPath), "Directory should be created.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithSubdirectory()
	{
		var subdirectory = "subdir".As<RelativeDirectoryPath>();
		var appData = TestAppData.LoadOrCreate(subdirectory);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(subdirectory, appData.Subdirectory, "Subdirectory should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithFileName()
	{
		var fileName = "custom_file.json".As<FileName>();
		var appData = TestAppData.LoadOrCreate(fileName);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(fileName, appData.FileNameOverride, "FileNameOverride should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithSubdirectoryAndFileName()
	{
		var subdirectory = "subdir".As<RelativeDirectoryPath>();
		var fileName = "custom_file.json".As<FileName>();
		var appData = TestAppData.LoadOrCreate(subdirectory, fileName);

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(subdirectory, appData.Subdirectory, "Subdirectory should be set correctly.");
		Assert.AreEqual(fileName, appData.FileNameOverride, "FileNameOverride should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesNewInstanceIfFileDoesNotExist()
	{
		var appData = TestAppData.LoadOrCreate();

		Assert.IsNotNull(appData, "AppData instance should not be null.");
		Assert.AreEqual(string.Empty, appData.Data, "Data should be default if file does not exist.");
	}

	[TestMethod]
	public void TestLoadOrCreateLoadsExistingData()
	{
		var appData = TestAppData.Get();
		appData.Data = "Persistent Data";
		appData.Save();

		var loadedAppData = TestAppData.LoadOrCreate();
		Assert.AreEqual("Persistent Data", loadedAppData.Data, "Data should persist across LoadOrCreate calls.");
	}

	[TestMethod]
	public void TestQueueSaveStaticMethod()
	{
		var beforeQueueTime = DateTime.UtcNow;

		TestAppData.QueueSave();

		var appData = TestAppData.Get();
		Assert.IsTrue(appData.SaveQueuedTime >= beforeQueueTime, "SaveQueuedTime was not set correctly.");
	}

	[TestMethod]
	public void TestSaveIfRequiredStaticMethod()
	{
		var appData = TestAppData.Get();
		appData.Data = "Test data";
		appData.QueueSave();
		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100)); // Wait for more than debounce time

		TestAppData.SaveIfRequired();

		var filePath = appData.FilePath;
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File was not saved.");

		var testAppData = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(filePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(testAppData, "Saved data should be deserialized correctly.");
		Assert.AreEqual("Test data", testAppData.Data, "Saved data does not match.");
	}
}
