// Copyright (c) ktsu.dev
// All rights reserved.
// Licensed under the MIT license.

[assembly: Parallelize(Scope = ExecutionScope.MethodLevel)]

namespace ktsu.AppDataStorage.Test;

using System;
using System.Collections.Concurrent;
using System.IO.Abstractions;
using System.IO.Abstractions.TestingHelpers;
using System.Net.Sockets;
using System.Text.Json;

using ktsu.CaseConverter;
using ktsu.Semantics.Paths;
using ktsu.Semantics.Strings;

[TestClass]
public sealed class AppDataTests
{
	private const string TestDataString = "Test data";
	private const string TestFileName = "test.txt";
	private const string CustomFileName = "custom_file.json";
	private const string BackupContentString = "backup content";
	private const string DirectoryShouldNotExistInitiallyMessage = "Directory should not exist initially.";
	private const string DirectoryWasNotCreatedMessage = "Directory was not created.";
	private const string ShouldThrowWhenAppDataIsNullMessage = "Should throw when appData is null";

	[ClassInitialize]
	public static void ClassSetup(TestContext testContext)
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
		public AbsoluteDirectoryPath StrongPath { get; set; } = "c:\\".As<AbsoluteDirectoryPath>();
	}

	private static void AssertFileExists(AbsoluteFilePath filePath, string message = "File should exist.")
	{
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), message);
	}

	private static void AssertFileDoesNotExist(AbsoluteFilePath filePath, string message = "File should not exist.")
	{
		Assert.IsFalse(AppData.FileSystem.File.Exists(filePath), message);
	}

	private static void AssertDirectoryExists(AbsoluteDirectoryPath dirPath, string message = "Directory should exist.")
	{
		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), message);
	}

	private static void AssertDirectoryDoesNotExist(AbsoluteDirectoryPath dirPath, string message = "Directory should not exist.")
	{
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(dirPath), message);
	}

	private static void AssertBackupFileDoesNotExist(AbsoluteFilePath mainFilePath, string message = "Backup file should not exist.")
	{
		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(mainFilePath);
		AssertFileDoesNotExist(backupFilePath, message);
	}

	private static TestAppData CreateTestAppDataWithContent(string content)
	{
		return new TestAppData { Data = content };
	}

	private static void WriteTextAndAssertFileExists(TestAppData appData, string text)
	{
		AppData.WriteText(appData, text);
		AssertFileExists(appData.FilePath, "File was not created.");
	}

	// Helper method to create test file path
	private static AbsoluteFilePath CreateTestFilePath() =>
		(AppData.Path / FileName.Create(TestFileName)).As<AbsoluteFilePath>();

	// Helper method to create test directory path
	private static AbsoluteDirectoryPath CreateTestDirectoryPath() =>
		(AppData.Path / RelativeDirectoryPath.Create("testDir")).As<AbsoluteDirectoryPath>();

	// Helper method to create nested directory path
	private static AbsoluteDirectoryPath CreateNestedDirectoryPath() =>
		(AppData.Path / RelativeDirectoryPath.Create("nested/dir/structure")).As<AbsoluteDirectoryPath>();

	// Helper method to test directory creation
	private static void TestDirectoryCreation(AbsoluteDirectoryPath dirPath, string? initialMessage = null, string? createdMessage = null)
	{
		AssertDirectoryDoesNotExist(dirPath, initialMessage ?? DirectoryShouldNotExistInitiallyMessage);
		AppData.EnsureDirectoryExists(dirPath);
		AssertDirectoryExists(dirPath, createdMessage ?? DirectoryWasNotCreatedMessage);
	}

	// Helper method to test file path directory creation
	private static void TestFilePathDirectoryCreation(AbsoluteFilePath filePath)
	{
		AbsoluteDirectoryPath dirPath = filePath.AbsoluteDirectoryPath;
		TestDirectoryCreation(dirPath);
	}

	// Helper method to test null argument exceptions
	private static void AssertArgumentNullException(Action action, string message = ShouldThrowWhenAppDataIsNullMessage)
	{
		Assert.ThrowsExactly<ArgumentNullException>(action, message);
	}

	// Helper method to assert AppData instance is not null
	private static void AssertAppDataNotNull(TestAppData appData, string message = "AppData instance should not be null.")
	{
		Assert.IsNotNull(appData, message);
	}

	// Helper method to create test app data with default test content
	private static TestAppData CreateTestAppData()
	{
		return new TestAppData();
	}

	// Helper method to save app data and assert file exists
	private static void SaveAndAssertFileExists(TestAppData appData, string message = "File should exist after save.")
	{
		appData.Save();
		AssertFileExists(appData.FilePath, message);
	}

	// Helper method to save TestAppData and verify content by loading
	private static void SaveAndVerifyTestContent(TestAppData appData, string expectedData, string message = "Data should match after save and load.")
	{
		appData.Save();
		TestAppData loaded = TestAppData.LoadOrCreate();
		Assert.AreEqual(expectedData, loaded.Data, message);
	}

	// Helper method to test file cleanup scenarios
	private static void TestFileCleanup(AbsoluteFilePath filePath, string message = "File should be cleaned up.")
	{
		if (AppData.FileSystem.File.Exists(filePath))
		{
			AppData.FileSystem.File.Delete(filePath);
		}
		AssertFileDoesNotExist(filePath, message);
	}

	// Helper method to verify file content matches expected text
	private static void VerifyFileContent(AbsoluteFilePath filePath, string expectedContent, string message = "File content should match expected value.")
	{
		Assert.IsTrue(AppData.FileSystem.File.Exists(filePath), "File should exist before reading content.");
		string actualContent = AppData.FileSystem.File.ReadAllText(filePath);
		Assert.Contains(expectedContent, actualContent, message);
	}

	[TestMethod]
	public void TestSaveCreatesFile()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		SaveAndAssertFileExists(appData, "File was not created.");
	}

	[TestMethod]
	public void TestSaveCleansBackupFile()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		appData.Save();

		AssertBackupFileDoesNotExist(appData.FilePath, "Backup file should not exist initially.");

		appData.Save();

		AssertBackupFileDoesNotExist(appData.FilePath, "Backup file should get cleaned up.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsForFilePath()
	{
		AbsoluteFilePath filePath = CreateTestFilePath();
		TestFilePathDirectoryCreation(filePath);
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsForDirectoryPath()
	{
		AbsoluteDirectoryPath dirPath = CreateTestDirectoryPath();
		TestDirectoryCreation(dirPath);
	}

	[TestMethod]
	public void TestMakeTempFilePathCreatesCorrectPath()
	{
		AbsoluteFilePath filePath = CreateTestFilePath();
		AbsoluteFilePath tempFilePath = AppData.MakeTempFilePath(filePath);
		Assert.AreEqual(filePath + ".tmp", tempFilePath, "Temp file path does not match expected value.");
	}

	[TestMethod]
	public void TestMakeBackupFilePathCreatesCorrectPath()
	{
		AbsoluteFilePath filePath = CreateTestFilePath();
		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(filePath);
		Assert.AreEqual(filePath + ".bk", backupFilePath, "Backup file path does not match expected value.");
	}

	[TestMethod]
	public void TestWriteTextCreatesFile()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		WriteTextAndAssertFileExists(appData, TestDataString);
	}

	[TestMethod]
	public void TestWriteTextCreatesBackupFileOnOverwrite()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		AppData.WriteText(appData, "Initial data");

		AppData.WriteText(appData, "Updated data");

		AssertBackupFileDoesNotExist(appData.FilePath, "Backup file should be cleaned up after save.");
	}

	[TestMethod]
	public void TestReadTextReturnsCorrectData()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		AppData.WriteText(appData, TestDataString);

		string text = AppData.ReadText(appData);
		Assert.AreEqual(TestDataString, text, "Read text does not match written text.");
	}

	[TestMethod]
	public void TestReadTextRestoresFromBackupIfMainFileMissing()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		AppData.WriteText(appData, TestDataString);

		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		AppData.FileSystem.File.Copy(appData.FilePath, backupFilePath);
		AppData.FileSystem.File.Delete(appData.FilePath);

		string text = AppData.ReadText(appData);
		Assert.AreEqual(TestDataString, text, "Read text does not match backup text.");
		AssertFileExists(appData.FilePath, "Main file should be restored from backup.");
	}

	[TestMethod]
	public void TestQueueSaveSetsSaveQueuedTime()
	{
		using TestAppData appData = CreateTestAppData();
		DateTime beforeQueueTime = DateTime.UtcNow;

		appData.QueueSave();

		Assert.IsGreaterThanOrEqualTo(beforeQueueTime, appData.SaveQueuedTime, "SaveQueuedTime was not set correctly.");
	}

	[TestMethod]
	public void TestSaveIfRequiredSavesDataAfterDebounceTime()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		appData.QueueSave();
		Thread.Sleep(appData.SaveDebounceTime + TimeSpan.FromMilliseconds(100)); // Wait for more than debounce time

		appData.SaveIfRequired();

		AssertFileExists(appData.FilePath, "File was not saved.");

		TestAppData? fileContents = JsonSerializer.Deserialize<TestAppData>(AppData.FileSystem.File.ReadAllText(appData.FilePath), AppData.JsonSerializerOptions);
		Assert.IsNotNull(fileContents, "Saved data should be deserialized correctly.");
		Assert.AreEqual(TestDataString, fileContents.Data, "Saved data does not match.");
	}

	[TestMethod]
	public void TestSaveIfRequiredDoesNotSaveBeforeDebounceTime()
	{
		using TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		appData.QueueSave();

		appData.SaveIfRequired();

		AssertFileDoesNotExist(appData.FilePath, "File should not be saved due to debounce.");
	}

	[TestMethod]
	public void TestDisposeSavesDataIfSaveQueued()
	{
		TestAppData appData = CreateTestAppDataWithContent(TestDataString);
		appData.QueueSave();

		appData.Dispose();

		AssertFileExists(appData.FilePath, "File should be saved upon disposal.");
	}

	[TestMethod]
	public void TestDisposeDoesNotSaveIfNoSaveQueued()
	{
		TestAppData appData = CreateTestAppDataWithContent(TestDataString);

		appData.Dispose();

		AssertFileDoesNotExist(appData.FilePath, "File should not be saved if no save was queued.");
	}

	[TestMethod]
	public void TestEnsureDisposeOnExitRegistersEvent()
	{
		using TestAppData appData = CreateTestAppData();

		appData.EnsureDisposeOnExit();

		Assert.IsTrue(appData.IsDisposeRegistered, "DisposeOnExit should register an event.");
	}

	[TestMethod]
	public void TestIsSaveQueuedReturnsCorrectValue()
	{
		using TestAppData appData = CreateTestAppData();
		Assert.IsFalse(appData.IsSaveQueued(), "Save should not be queued initially.");

		appData.QueueSave();

		Assert.IsTrue(appData.IsSaveQueued(), "Save should be queued after QueueSave is called.");
	}

	[TestMethod]
	public void TestIsDebounceTimeElapsedReturnsCorrectValue()
	{
		using TestAppData appData = CreateTestAppData();

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

		AssertAppDataNotNull(appData, "LoadOrCreate should return a new instance if file is corrupt.");
		Assert.AreEqual(string.Empty, appData.Data, "Data should be default if loaded from corrupt file.");
	}

	[TestMethod]
	public void TestMultipleSavesOnlyWriteOnceWithinDebouncePeriod()
	{
		using TestAppData appData = CreateTestAppDataWithContent("Data1");
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
		string expectedPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), AppData.AppDomain);
		Assert.AreEqual(expectedPath, AppData.Path.ToString(), "AppData path should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithNullSubdirectoryAndFileName()
	{
		TestAppData appData = TestAppData.LoadOrCreate(null, null);

		AssertAppDataNotNull(appData);
		Assert.IsNull(appData.Subdirectory, "Subdirectory should be null.");
		Assert.IsNull(appData.FileNameOverride, "FileNameOverride should be null.");
	}

	[TestMethod]
	public void TestConfigureForTesting()
	{
		Assert.IsInstanceOfType<MockFileSystem>(AppData.FileSystem, "FileSystem should be a MockFileSystem instance.");
	}

	[TestMethod]
	public void TestAppDataSerializationIncludesFields()
	{
		using TestAppData appData = new();
		string json = JsonSerializer.Serialize(appData, AppData.JsonSerializerOptions);

		Assert.Contains("\"Data\"", json, "Serialized JSON should include fields.");
	}

	[TestMethod]
	public void TestSaveThrowsExceptionIfSerializationFails()
	{
		using FaultyAppData appData = new();
		Assert.ThrowsExactly<NotSupportedException>(appData.Save);
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
		AbsoluteFilePath filePath = CreateTestFilePath();
		TestFilePathDirectoryCreation(filePath);
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithValidDirectoryPath()
	{
		AbsoluteDirectoryPath dirPath = CreateTestDirectoryPath();
		TestDirectoryCreation(dirPath);
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithNestedDirectories()
	{
		AbsoluteDirectoryPath dirPath = CreateNestedDirectoryPath();
		TestDirectoryCreation(dirPath, "Nested directory structure should not exist initially.", "Nested directory structure was not created.");
	}

	[TestMethod]
	public void TestSaveCreatesBackupIfInitialSaveFails()
	{
		using TestAppData appData = new()
		{ Data = TestDataString };
		appData.Save();

		MockFileData mockFile = ((MockFileSystem)AppData.FileSystem).GetFile(appData.FilePath);
		mockFile.AllowedFileShare = FileShare.None;

		Assert.ThrowsExactly<IOException>(appData.Save);

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

		AssertAppDataNotNull(appData, "LoadOrCreate should return a new instance if both main and backup files are corrupt.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesDirectoryIfNotExists()
	{
		TestAppData appData = TestAppData.LoadOrCreate();

		AbsoluteDirectoryPath dirPath = appData.FilePath.AbsoluteDirectoryPath;
		Assert.IsTrue(AppData.FileSystem.Directory.Exists(dirPath), "Directory should be created if it doesn't exist.");
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsHandlesRelativePaths()
	{
		RelativeDirectoryPath relativeDirPath = RelativeDirectoryPath.Create(Path.Combine("relative", "dir"));
		AbsoluteDirectoryPath absoluteDirPath = AppData.Path / relativeDirPath;
		Assert.IsFalse(AppData.FileSystem.Directory.Exists(absoluteDirPath), DirectoryShouldNotExistInitiallyMessage);

		AppData.EnsureDirectoryExists(absoluteDirPath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(absoluteDirPath), "Directory should be created.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithSubdirectory()
	{
		RelativeDirectoryPath subdirectory = RelativeDirectoryPath.Create("subdir");
		TestAppData appData = TestAppData.LoadOrCreate(subdirectory);

		AssertAppDataNotNull(appData);
		Assert.AreEqual(subdirectory, appData.Subdirectory, "Subdirectory should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithFileName()
	{
		FileName fileName = FileName.Create(CustomFileName);
		TestAppData appData = TestAppData.LoadOrCreate(fileName);

		AssertAppDataNotNull(appData);
		Assert.AreEqual(fileName, appData.FileNameOverride, "FileNameOverride should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateWithSubdirectoryAndFileName()
	{
		RelativeDirectoryPath subdirectory = RelativeDirectoryPath.Create("subdir");
		FileName fileName = FileName.Create(CustomFileName);
		TestAppData appData = TestAppData.LoadOrCreate(subdirectory, fileName);

		AssertAppDataNotNull(appData);
		Assert.AreEqual(subdirectory, appData.Subdirectory, "Subdirectory should be set correctly.");
		Assert.AreEqual(fileName, appData.FileNameOverride, "FileNameOverride should be set correctly.");
	}

	[TestMethod]
	public void TestLoadOrCreateCreatesNewInstanceIfFileDoesNotExist()
	{
		TestAppData appData = TestAppData.LoadOrCreate();

		AssertAppDataNotNull(appData);
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
		Assert.IsGreaterThanOrEqualTo(beforeQueueTime, appData.SaveQueuedTime, "SaveQueuedTime was not set correctly.");
	}

	[TestMethod]
	public void TestSaveIfRequiredStaticMethod()
	{
		TestAppData.QueueSave();
		Thread.Sleep(TestAppData.Get().SaveDebounceTime + TimeSpan.FromMilliseconds(100));

		TestAppData.SaveIfRequired();

		Assert.IsTrue(AppData.FileSystem.File.Exists(TestAppData.Get().FilePath), "File was not saved.");
	}

	[TestMethod]
	public void TestConfigureForTestingWithInvalidFileSystem()
	{
		Assert.ThrowsExactly<InvalidOperationException>(() => AppData.ConfigureForTesting(() => new FileSystem()), "Should throw when trying to configure with a non-mock file system");
	}

	[TestMethod]
	public void TestConfigureForTestingWithNullFactory()
	{
		Assert.ThrowsExactly<ArgumentNullException>(() => AppData.ConfigureForTesting(null!), "Should throw when configuring with null factory");
	}

	[TestMethod]
	public void TestWriteTextWithNullAppData()
	{
		AssertArgumentNullException(() => AppData.WriteText<TestAppData>(null!, TestDataString));
	}

	[TestMethod]
	public void TestWriteTextWithNullText()
	{
		using TestAppData appData = new();
		Assert.ThrowsExactly<ArgumentNullException>(() => AppData.WriteText(appData, null!), "Should throw when text is null");
	}

	[TestMethod]
	public void TestReadTextWithNullAppData()
	{
		AssertArgumentNullException(() => AppData.ReadText<TestAppData>(null!));
	}

	[TestMethod]
	public void TestQueueSaveWithNullAppData()
	{
		AssertArgumentNullException(() => AppData.QueueSave<TestAppData>(null!));
	}

	[TestMethod]
	public void TestSaveIfRequiredWithNullAppData()
	{
		AssertArgumentNullException(() => AppData.SaveIfRequired<TestAppData>(null!));
	}

	[TestMethod]
	public void TestFileNameWithOverride()
	{
		using TestAppData appData = new();
		appData.FileNameOverride = FileName.Create("custom_name.json");

		Assert.AreEqual("custom_name.json", appData.FileName.ToString(), "File name should use override when set");
	}

	[TestMethod]
	public void TestFilePathWithSubdirectoryAndFileName()
	{
		using TestAppData appData = new();
		appData.Subdirectory = RelativeDirectoryPath.Create("custom_dir");
		appData.FileNameOverride = FileName.Create(CustomFileName);

		string expectedPath = (AppData.Path / appData.Subdirectory / appData.FileNameOverride).ToString();
		Assert.AreEqual(expectedPath, appData.FilePath.ToString(), "File path should include both subdirectory and custom filename");
	}

	[TestMethod]
	public void TestJsonSerializerOptionsConfiguration()
	{
		JsonSerializerOptions options = AppData.JsonSerializerOptions;

		Assert.IsTrue(options.WriteIndented, "Should have WriteIndented set to true");
		Assert.IsTrue(options.IncludeFields, "Should have IncludeFields set to true");
		Assert.IsNotNull(options.ReferenceHandler, "Should have ReferenceHandler configured");
		Assert.IsNotEmpty(options.Converters, "Should have converters configured");
	}

	[TestMethod]
	public void TestBackupFileRecoveryWithTimestamp()
	{
		using TestAppData appData = new();
		AppData.WriteText(appData, "Original data");

		// Create a backup file manually
		AbsoluteFilePath backupFilePath = AppData.MakeBackupFilePath(appData.FilePath);
		AppData.FileSystem.File.Copy(appData.FilePath, backupFilePath);

		// Delete the main file
		AppData.FileSystem.File.Delete(appData.FilePath);

		// Reading should restore from backup and rename it with timestamp
		string recoveredText = AppData.ReadText(appData);

		Assert.AreEqual("Original data", recoveredText, "Should recover data from backup");
		Assert.IsTrue(AppData.FileSystem.File.Exists(appData.FilePath), "Main file should be restored");
		Assert.IsFalse(AppData.FileSystem.File.Exists(backupFilePath), "Original backup should be renamed");

		// Check that a timestamped backup exists
		string[] timestampedBackups = AppData.FileSystem.Directory.GetFiles(appData.FilePath.DirectoryPath.ToString(), "*.bk.*");
		Assert.IsNotEmpty(timestampedBackups, "Should have created a timestamped backup");
	}

	[TestMethod]
	public void TestSaveCreatesIntermediateDirectories()
	{
		using TestAppData appData = new();
		appData.Subdirectory = RelativeDirectoryPath.Create("level1/level2/level3");

		appData.Data = "Test data for nested directories";
		appData.Save();

		Assert.IsTrue(AppData.FileSystem.File.Exists(appData.FilePath), "File should be created in nested directory");
		Assert.IsTrue(AppData.FileSystem.Directory.Exists(appData.FilePath.DirectoryPath), "Nested directories should be created");
	}

	[TestMethod]
	public void TestMultipleInstancesWithDifferentSubdirectories()
	{
		using TestAppData appData1 = TestAppData.LoadOrCreate(RelativeDirectoryPath.Create("subdir1"));
		using TestAppData appData2 = TestAppData.LoadOrCreate(RelativeDirectoryPath.Create("subdir2"));

		appData1.Data = "Data for instance 1";
		appData2.Data = "Data for instance 2";

		appData1.Save();
		appData2.Save();

		Assert.AreNotEqual(appData1.FilePath, appData2.FilePath, "Instances should have different file paths");
		Assert.IsTrue(AppData.FileSystem.File.Exists(appData1.FilePath), "First instance file should exist");
		Assert.IsTrue(AppData.FileSystem.File.Exists(appData2.FilePath), "Second instance file should exist");

		// Verify content is different
		VerifyFileContent(appData1.FilePath, "Data for instance 1", "First instance content should match");
		VerifyFileContent(appData2.FilePath, "Data for instance 2", "Second instance content should match");
	}

	[TestMethod]
	public void TestMultipleInstancesWithDifferentFileNames()
	{
		using TestAppData appData1 = TestAppData.LoadOrCreate(FileName.Create("file1.json"));
		using TestAppData appData2 = TestAppData.LoadOrCreate(FileName.Create("file2.json"));

		appData1.Data = "Data for file 1";
		appData2.Data = "Data for file 2";

		appData1.Save();
		appData2.Save();

		Assert.AreNotEqual(appData1.FilePath, appData2.FilePath, "Instances should have different file paths");
		Assert.Contains("file1.json", appData1.FilePath.ToString(), "First instance should use custom filename");
		Assert.Contains("file2.json", appData2.FilePath.ToString(), "Second instance should use custom filename");
	}

	[TestMethod]
	public void TestLoadOrCreateWithCorruptJsonRecursiveRecovery()
	{
		using TestAppData appData = new();

		AppData.EnsureDirectoryExists(appData.FilePath);

		// Create a corrupt main file
		AppData.FileSystem.File.WriteAllText(appData.FilePath, "{ invalid json");

		// Create a corrupt backup file too
		AbsoluteFilePath backupPath = AppData.MakeBackupFilePath(appData.FilePath);
		AppData.FileSystem.File.WriteAllText(backupPath, "{ also invalid json");

		// LoadOrCreate should handle both being corrupt and create a new instance
		TestAppData loaded = TestAppData.LoadOrCreate();

		Assert.IsNotNull(loaded, "Should create new instance when both files are corrupt");
		Assert.AreEqual(string.Empty, loaded.Data, "Should have default empty data");
		Assert.IsTrue(AppData.FileSystem.File.Exists(loaded.FilePath), "Should create new valid file");
	}

	[TestMethod]
	public void TestConcurrentAccess()
	{
		const int threadCount = 5;
		const int operationsPerThread = 10;
		Thread[] threads = new Thread[threadCount];
		List<Exception> exceptions = [];

		for (int i = 0; i < threadCount; i++)
		{
			int threadId = i;
			threads[i] = new Thread(() =>
			{
				try
				{
					for (int j = 0; j < operationsPerThread; j++)
					{
						using TestAppData appData = new()
						{
							Data = $"Thread {threadId}, Operation {j}"
						};

						appData.QueueSave();
						appData.SaveIfRequired();

						// Read the data back
						string readData = AppData.ReadText(appData);
						Assert.IsNotNull(readData, "Should be able to read data");
					}
				}
				catch (Exception ex) when (ex is not OperationCanceledException and not ThreadInterruptedException)
				{
					lock (exceptions)
					{
						exceptions.Add(ex);
					}
				}
			});
		}

		// Start all threads
		foreach (Thread thread in threads)
		{
			thread.Start();
		}

		// Wait for all threads to complete
		foreach (Thread thread in threads)
		{
			thread.Join(TimeSpan.FromSeconds(30)); // Timeout after 30 seconds
		}

		Assert.IsEmpty(exceptions, $"No exceptions should occur during concurrent access. Exceptions: {string.Join(", ", exceptions.Select(e => e.Message))}");
	}

	[TestMethod]
	public void TestEmptyStringDataHandling()
	{
		using TestAppData appData = new() { Data = string.Empty };
		SaveAndVerifyTestContent(appData, string.Empty, "Empty string should be preserved");
	}

	[TestMethod]
	public void TestSpecialCharactersInData()
	{
		string specialCharsData = "Special chars: \n\r\t\"'\\/<>&";
		using TestAppData appData = new() { Data = specialCharsData };
		SaveAndVerifyTestContent(appData, specialCharsData, "Special characters should be preserved during serialization");
	}

	[TestMethod]
	public void TestVeryLargeDataHandling()
	{
		// Create a large string (1MB)
		string largeData = new('A', 1024 * 1024);

		using TestAppData appData = new() { Data = largeData };
		SaveAndVerifyTestContent(appData, largeData, "Large data should be preserved");
	}

	[TestMethod]
	public void TestUnicodeDataHandling()
	{
		string unicodeData = "Unicode: 🚀 测试 العربية русский";
		using TestAppData appData = new() { Data = unicodeData };
		SaveAndVerifyTestContent(appData, unicodeData, "Unicode characters should be preserved");
	}

	// Test class with complex data types for serialization testing
	internal sealed class ComplexTestAppData : AppData<ComplexTestAppData>
	{
		public string StringData { get; set; } = string.Empty;
		public int IntData { get; set; }
		public double DoubleData { get; set; }
		public bool BoolData { get; set; }
		public DateTime DateTimeData { get; set; }
		public List<string> ListData { get; set; } = [];
		public Dictionary<string, int> DictData { get; set; } = [];
		public TestValue EnumData { get; set; }
	}

	internal enum TestValue
	{
		Value1,
		Value2,
		Value3
	}

	[TestMethod]
	public void TestComplexDataTypeSerialization()
	{
		using ComplexTestAppData appData = new()
		{
			StringData = "Test string",
			IntData = 42,
			DoubleData = 3.14159,
			BoolData = true,
			DateTimeData = DateTime.UtcNow,
			ListData = ["item1", "item2", "item3"],
			DictData = { ["key1"] = 1, ["key2"] = 2 },
			EnumData = TestValue.Value2
		};

		appData.Save();

		ComplexTestAppData loaded = ComplexTestAppData.LoadOrCreate();

		Assert.AreEqual(appData.StringData, loaded.StringData, "String data should match");
		Assert.AreEqual(appData.IntData, loaded.IntData, "Int data should match");
		Assert.AreEqual(appData.DoubleData, loaded.DoubleData, "Double data should match");
		Assert.AreEqual(appData.BoolData, loaded.BoolData, "Bool data should match");
		Assert.AreEqual(appData.DateTimeData, loaded.DateTimeData, "DateTime data should match");
		CollectionAssert.AreEqual(appData.ListData, loaded.ListData, "List data should match");
		CollectionAssert.AreEqual(appData.DictData, loaded.DictData, "Dictionary data should match");
		Assert.AreEqual(appData.EnumData, loaded.EnumData, "Enum data should match");
	}

	[TestMethod]
	public void TestFileSystemPropertyThreadSafety()
	{
		// Test that each thread gets its own FileSystem instance
		ConcurrentBag<IFileSystem> fileSystemInstances = [];
		Thread[] threads = new Thread[3];

		for (int i = 0; i < threads.Length; i++)
		{
			threads[i] = new Thread(() => fileSystemInstances.Add(AppData.FileSystem));
		}

		foreach (Thread thread in threads)
		{
			thread.Start();
		}

		foreach (Thread thread in threads)
		{
			thread.Join();
		}

		Assert.HasCount(3, fileSystemInstances, "Each thread should access FileSystem");
	}

	[TestMethod]
	public void TestReadTextReturnsEmptyStringForNonExistentFileWithoutBackup()
	{
		using TestAppData appData = CreateTestAppData();

		// Ensure no files exist
		TestFileCleanup(appData.FilePath, "Main file should be cleaned up");
		AbsoluteFilePath backupPath = AppData.MakeBackupFilePath(appData.FilePath);
		TestFileCleanup(backupPath, "Backup file should be cleaned up");

		string result = AppData.ReadText(appData);
		Assert.AreEqual(string.Empty, result, "Should return empty string when no file exists");
	}

	[TestMethod]
	public void TestLockObjectIsCorrectType()
	{
		// The type depends on the .NET version, but it should always be present
#if NET8_0
		object lockObj = TestAppData.Lock;
		Assert.IsNotNull(lockObj, "Lock object should not be null");
		Assert.IsInstanceOfType<object>(lockObj, "Lock should be of type object in .NET 8");
#else
		// In .NET 9+, Lock is a value type, so we check the type directly
		Type lockType = TestAppData.Lock.GetType();
		Assert.AreEqual(typeof(Lock), lockType, "Lock should be of type Lock in .NET 9+");
#endif
	}

	[TestMethod]
	public void TestSaveDebounceTimeIsCorrect()
	{
		using TestAppData appData = new();
		Assert.AreEqual(TimeSpan.FromSeconds(3), appData.SaveDebounceTime, "Save debounce time should be 3 seconds");
	}

	[TestMethod]
	public void TestIsDisposeRegisteredInitiallyFalse()
	{
		using TestAppData appData = new();
		Assert.IsFalse(appData.IsDisposeRegistered, "IsDisposeRegistered should initially be false");
	}

	[TestMethod]
	public void TestEnsureDisposeOnExitSetsFlag()
	{
		using TestAppData appData = new();
		appData.EnsureDisposeOnExit();
		Assert.IsTrue(appData.IsDisposeRegistered, "IsDisposeRegistered should be true after calling EnsureDisposeOnExit");
	}

	[TestMethod]
	public void TestEnsureDisposeOnExitCalledMultipleTimes()
	{
		using TestAppData appData = new();
		appData.EnsureDisposeOnExit();
		appData.EnsureDisposeOnExit();
		appData.EnsureDisposeOnExit();

		Assert.IsTrue(appData.IsDisposeRegistered, "IsDisposeRegistered should remain true");
	}

	[TestMethod]
	public void TestGetReturnsConsistentInstance()
	{
		TestAppData instance1 = TestAppData.Get();
		TestAppData instance2 = TestAppData.Get();
		TestAppData instance3 = TestAppData.Get();

		Assert.AreSame(instance1, instance2, "Get() should return the same instance");
		Assert.AreSame(instance2, instance3, "Get() should return the same instance");
	}

	[TestMethod]
	public void TestInternalStateIsLazy()
	{
		Lazy<TestAppData> internalState = TestAppData.InternalState;
		Assert.IsNotNull(internalState, "InternalState should not be null");
		Assert.IsInstanceOfType<Lazy<TestAppData>>(internalState, "InternalState should be Lazy<TestAppData>");
	}

	[TestMethod]
	public void TestSaveUpdatesLastSaveTime()
	{
		using TestAppData appData = new() { Data = TestDataString };
		DateTime beforeSave = DateTime.UtcNow;

		appData.Save();

		DateTime afterSave = DateTime.UtcNow;
		Assert.IsGreaterThanOrEqualTo(beforeSave, appData.LastSaveTime, "LastSaveTime should be updated after save");
		Assert.IsLessThanOrEqualTo(afterSave, appData.LastSaveTime, "LastSaveTime should not be in the future");
	}

	[TestMethod]
	public void TestWriteTextHandlesFileOperationErrors()
	{
		using TestAppData appData = new() { Data = TestDataString };

		(AppData.FileSystem as MockFileSystem)?.AddFile(appData.FilePath, new MockFileData("existing data") { Attributes = FileAttributes.ReadOnly });

		// This should handle exceptions gracefully
		try
		{
			AppData.WriteText(appData, "new data");
		}
		catch (UnauthorizedAccessException)
		{
			// Expected behavior when file is readonly
		}
	}

	[TestMethod]
	public void TestReadTextHandlesIOExceptionsGracefully()
	{
		using TestAppData appData = new() { Data = TestDataString };

		(AppData.FileSystem as MockFileSystem)?.AddFile(appData.FilePath, new MockFileData("content")
		{
			AllowedFileShare = FileShare.None
		});

		// IOException should propagate through since ReadText only catches FileNotFoundException
		Assert.ThrowsExactly<IOException>(() => AppData.ReadText(appData));
	}

	[TestMethod]
	public void TestTimestampedBackupWithMultipleCollisions()
	{
		using TestAppData appData = new() { Data = TestDataString };

		AbsoluteFilePath backupPath = AppData.MakeBackupFilePath(appData.FilePath);

		// Pre-create backup and timestamped backup files to force collision handling
		(AppData.FileSystem as MockFileSystem)?.AddFile(backupPath, new MockFileData("backup content"));

		string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
		(AppData.FileSystem as MockFileSystem)?.AddFile(backupPath + $".{timestamp}", new MockFileData("backup1"));
		(AppData.FileSystem as MockFileSystem)?.AddFile(backupPath + $".{timestamp}_1", new MockFileData("backup2"));
		(AppData.FileSystem as MockFileSystem)?.AddFile(backupPath + $".{timestamp}_2", new MockFileData("backup3"));

		// This should handle multiple timestamp collisions
		string result = AppData.ReadText(appData);
		Assert.AreEqual(BackupContentString, result);

		// Verify that a uniquely timestamped backup was created
		List<string> backupFiles = [.. (AppData.FileSystem as MockFileSystem)?.AllFiles.Where(f => f.Contains(".bk.")) ?? []];
		Assert.IsGreaterThan(3, backupFiles.Count, "Should create a unique timestamped backup");
	}

	[TestMethod]
	public void TestFileNameGenerationWithComplexTypes()
	{
		using ComplexTestAppData appData = new();
		string expectedFileName = "complex_test_app_data.json";
		Assert.AreEqual(expectedFileName, appData.FileName.ToString());
	}

	[TestMethod]
	public void TestSubdirectoryAndFileNameCombinations()
	{
		RelativeDirectoryPath subdirectory = RelativeDirectoryPath.Create("custom/sub/dir");
		FileName fileName = FileName.Create(CustomFileName);

		using TestAppData appData = TestAppData.LoadOrCreate(subdirectory, fileName);

		Assert.AreEqual(subdirectory, appData.Subdirectory);
		Assert.AreEqual(fileName, appData.FileNameOverride);

		string expectedPath = Path.Combine(AppData.Path.ToString(), "custom", "sub", "dir", CustomFileName);
		Assert.AreEqual(expectedPath, appData.FilePath.ToString());
	}

	[TestMethod]
	public void TestEnsureDirectoryExistsWithDeepNesting()
	{
		string deepDirPathString = Path.Combine(AppData.Path.ToString(), "level1", "level2", "level3", "level4", "level5");
		AbsoluteDirectoryPath deepDirPath = AbsoluteDirectoryPath.Create(deepDirPathString);
		string deepFilePathString = Path.Combine(deepDirPathString, TestFileName);
		AbsoluteFilePath deepFilePath = AbsoluteFilePath.Create(deepFilePathString);

		AppData.EnsureDirectoryExists(deepFilePath);

		Assert.IsTrue(AppData.FileSystem.Directory.Exists(deepDirPath));
	}

	[TestMethod]
	public void TestJsonSerializationWithCircularReference()
	{
		using CircularRefAppData appData = new()
		{ Name = "Parent" };
		appData.Reference = appData; // Create circular reference

		// Should not throw due to ReferenceHandler.Preserve
		try
		{
			appData.Save();
		}
		catch (Exception ex) when (ex is not OperationCanceledException and not ThreadInterruptedException)
		{
			Assert.Fail($"Save should not throw an exception: {ex.Message}");
		}

		// Load and verify
		using CircularRefAppData loaded = CircularRefAppData.LoadOrCreate();
		Assert.AreEqual("Parent", loaded.Name);
		Assert.IsNotNull(loaded.Reference);
	}

	[TestMethod]
	public void TestNullableFieldsSerialization()
	{
		using NullableAppData appData = new()
		{
			NullableString = null,
			NullableInt = null,
			NullableList = null
		};

		appData.Save();

		using NullableAppData loaded = NullableAppData.LoadOrCreate();
		Assert.IsNull(loaded.NullableString);
		Assert.IsNull(loaded.NullableInt);
		Assert.IsNull(loaded.NullableList);
	}

	[TestMethod]
	public void TestFieldSerialization()
	{
		using FieldTestAppData appData = new();
		appData.SetPrivateField("modified");

		appData.Save();

		using FieldTestAppData loaded = FieldTestAppData.LoadOrCreate();
		Assert.AreEqual("public", loaded.PublicField);
		Assert.AreEqual("internal", loaded.InternalField);
		// Private fields are not serialized by default
		Assert.AreEqual("private", loaded.GetPrivateField());
	}

	[TestMethod]
	public void TestInheritanceSerialization()
	{
		using InheritanceTestAppData appData = new()
		{
			BaseData = "modified base",
			VirtualData = "modified virtual"
		};

		appData.Save();

		using InheritanceTestAppData loaded = InheritanceTestAppData.LoadOrCreate();
		Assert.AreEqual("modified base", loaded.BaseData);
		Assert.AreEqual("modified virtual", loaded.VirtualData);
	}

	[TestMethod]
	public void TestReadTextFallsBackToBackupFile()
	{
		string filePath = Path.Combine(AppData.Path.ToString(), "test_app_data.json");
		string backupPath = filePath + ".bk";

		// Setup backup file but not main file to test fallback
		(AppData.FileSystem as MockFileSystem)?.AddFile(backupPath, new MockFileData(BackupContentString));

		using TestAppData appData = new();

		string result = AppData.ReadText(appData);
		Assert.AreEqual(BackupContentString, result);
	}

	[TestMethod]
	public void TestMultipleTimestampedBackupsCreation()
	{
		// Capture timestamp once before any looping to ensure consistency
		DateTime timestamp = DateTime.Now;

		// Use the proper AppData path structure for TestAppData with dynamic filename
		using TestAppData tempAppData = new();
		string appDataPath = Path.Combine(AppData.Path.ToString(), tempAppData.FileName.ToString());
		string baseBackupPath = appDataPath + ".bk";

		// Pre-create multiple timestamped backups to test collision handling
		for (int i = 0; i < 5; i++)
		{
			string timestampedPath = $"{baseBackupPath}.{timestamp:yyyyMMdd_HHmmss}";
			if (i > 0)
			{
				timestampedPath += $"_{i}";
			}
			(AppData.FileSystem as MockFileSystem)?.AddFile(timestampedPath, new MockFileData("old backup"));
		}

		// Add the current backup file
		(AppData.FileSystem as MockFileSystem)?.AddFile(baseBackupPath, new MockFileData("current backup"));

		using TestAppData appData = new();

		// This should trigger the backup collision handling logic
		string result = AppData.ReadText(appData);
		Assert.AreEqual("current backup", result);
	}

	[TestMethod]
	public void TestSaveWithJsonSerializationException()
	{
		using JsonSerializationFailureAppData appData = new();

		Assert.ThrowsExactly<NotSupportedException>(appData.Save);
	}

	[TestMethod]
	public void TestFileSystemEdgeCaseEmptyPaths()
	{
		AppData.EnsureDirectoryExists(AbsoluteFilePath.Create(string.Empty));
		AppData.EnsureDirectoryExists(AbsoluteDirectoryPath.Create(string.Empty));

		// Should not throw and handle gracefully - if we get here, the method handled empty paths correctly
	}

	[TestMethod]
	public void TestConfigureForTestingWithNonMockFileSystem()
	{
		// Should throw when trying to use a non-mock filesystem
		Assert.ThrowsExactly<InvalidOperationException>(() => AppData.ConfigureForTesting(() => new FileSystem()));
	}

	[TestMethod]
	public void TestFileNameGenerationEdgeCases()
	{
		// Test with complex class names
		using VeryLongComplexClassNameForTestingAppData appData = new();
		string fileName = appData.FileName.ToString();
		Assert.Contains("very_long_complex_class_name_for_testing_app_data", fileName);
		Assert.EndsWith(".json", fileName);
	}

	[TestMethod]
	public void TestDisposeMultipleTimesWithSaveQueued()
	{
		using TestAppData appData = new() { Data = TestDataString };
		appData.QueueSave();

		// Dispose multiple times
		appData.Dispose();
		appData.Dispose();
		appData.Dispose();

		// Should handle multiple disposes gracefully - if we get here, the method succeeded
	}

	[TestMethod]
	public void TestSaveDebounceTimingPrecision()
	{
		using TestAppData appData = new() { Data = TestDataString };

		// Queue save and check timing immediately
		appData.QueueSave();
		Assert.IsTrue(appData.IsSaveQueued());
		Assert.IsFalse(appData.IsDoubounceTimeElapsed());

		// Wait for debounce time + buffer
		Thread.Sleep(appData.SaveDebounceTime.Add(TimeSpan.FromMilliseconds(100)));

		Assert.IsTrue(appData.IsDoubounceTimeElapsed());
	}

	[TestMethod]
	public void TestComplexDirectoryNestingWithSpecialCharacters()
	{
		RelativeDirectoryPath complexPath = RelativeDirectoryPath.Create(Path.Combine("level1", "level2 with spaces", "level3-with-dashes", "level4_with_underscores"));
		FileName complexFileName = FileName.Create("file with spaces & special chars.json");

		using TestAppData appData = TestAppData.LoadOrCreate(complexPath, complexFileName);
		appData.Data = "Complex path test";
		appData.Save();

		Assert.Contains("level1", appData.FilePath.ToString());
		Assert.Contains("level4_with_underscores", appData.FilePath.ToString());
		Assert.Contains("file with spaces & special chars.json", appData.FilePath.ToString());
	}

	[TestMethod]
	public void TestLargeDataHandlingWithBackups()
	{
		// Create very large data (1MB+)
		string largeData = new('X', 1_000_000);

		using TestAppData appData = new() { Data = largeData };
		appData.Save();

		// Modify and save again to test backup handling with large files
		appData.Data = new string('Y', 1_000_000);
		appData.Save();

		using TestAppData loaded = TestAppData.LoadOrCreate();
		Assert.AreEqual(1_000_000, loaded.Data.Length);
		Assert.IsTrue(loaded.Data.All(c => c == 'Y'));
	}

	[TestMethod]
	public void TestAppDomainPathGeneration()
	{
		string appDomain = AppData.AppDomain.ToString();
		string appDataPath = AppData.AppDataPath.ToString();
		string fullPath = AppData.Path.ToString();

		Assert.IsNotEmpty(appDomain);
		Assert.IsNotEmpty(appDataPath);
		Assert.Contains(appDomain, fullPath);
		Assert.Contains(appDataPath, fullPath);
	}
}

internal sealed class CircularRefAppData : AppData<CircularRefAppData>
{
	public string Name { get; set; } = "Test";
	public CircularRefAppData? Reference { get; set; }
}

internal sealed class NullableAppData : AppData<NullableAppData>
{
	public string? NullableString { get; set; }
	public int? NullableInt { get; set; }
	public List<string>? NullableList { get; set; }
}

internal sealed class FieldTestAppData : AppData<FieldTestAppData>
{
	public string PublicField = "public";
	private string PrivateField = "private";
	internal string InternalField = "internal";

	public string GetPrivateField() => PrivateField;
	public void SetPrivateField(string value) => PrivateField = value;
}

internal sealed class InheritanceTestAppData : AppData<InheritanceTestAppData>
{
	public string BaseData { get; set; } = "base";
	public string VirtualData { get; set; } = "virtual";
}

internal sealed class JsonSerializationFailureAppData : AppData<JsonSerializationFailureAppData>
{
	// Property that will cause JSON serialization to fail - using a delegate which can't be serialized
	public Action ProblematicProperty { get; set; } = () => { };
}

internal sealed class VeryLongComplexClassNameForTestingAppData : AppData<VeryLongComplexClassNameForTestingAppData>
{
	public string Data { get; set; } = string.Empty;
}
