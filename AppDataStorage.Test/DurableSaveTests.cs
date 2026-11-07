// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions;
using System.IO.Abstractions.TestingHelpers;

using ktsu.Semantics.Paths;

/// <summary>
/// A save must survive a power loss or OS crash shortly after it returns, and an empty settings file
/// left by one must not be read as "no settings" and overwritten with defaults (ktsu-dev/AppDataStorage#325).
/// </summary>
[TestClass]
public sealed class DurableSaveTests
{
	[ClassInitialize]
	public static void ClassSetup(TestContext testContext) => AppData.ConfigureForTesting(() => new MockFileSystem());

	[TestInitialize]
	public void SetupTest() => AppData.ClearCachedFileSystem();

	[TestCleanup]
	public void CleanupTest() => AppData.ClearCachedFileSystem();

	public sealed class DurableSettings : AppData<DurableSettings>
	{
		public string Data { get; set; } = string.Empty;
	}

	private static AbsoluteFilePath SettingsFilePath()
	{
		using DurableSettings locator = new();
		AppData.EnsureDirectoryExists(locator.FilePath);
		return locator.FilePath;
	}

	private static bool HasArchivedCopy(AbsoluteFilePath filePath, string label)
	{
		string directory = AppData.FileSystem.Path.GetDirectoryName(filePath)!;
		string prefix = AppData.FileSystem.Path.GetFileName(filePath) + label + ".";
		return Array.Exists(
			AppData.FileSystem.Directory.GetFiles(directory),
			file => AppData.FileSystem.Path.GetFileName(file).StartsWith(prefix, StringComparison.Ordinal));
	}

	[TestMethod]
	[DataRow("")]
	[DataRow("   \n")]
	public void EmptyMainFileWithABackup_LoadsTheBackup(string emptyContent)
	{
		AbsoluteFilePath filePath = SettingsFilePath();
		AppData.FileSystem.File.WriteAllText(filePath, emptyContent);
		AppData.FileSystem.File.WriteAllText(AppData.MakeBackupFilePath(filePath), "{\"Data\":\"precious\"}");

		using DurableSettings settings = DurableSettings.LoadOrCreate();

		Assert.AreEqual("precious", settings.Data, "The backup should be loaded, not replaced with defaults.");
		Assert.IsTrue(HasArchivedCopy(filePath, ".empty"), "The empty main file should be archived.");
	}

	[TestMethod]
	public void EmptyMainFileWithATempFile_LoadsTheTempFile()
	{
		AbsoluteFilePath filePath = SettingsFilePath();
		AppData.FileSystem.File.WriteAllText(filePath, string.Empty);
		AppData.FileSystem.File.WriteAllText(AppData.MakeTempFilePath(filePath), "{\"Data\":\"in flight\"}");

		using DurableSettings settings = DurableSettings.LoadOrCreate();

		Assert.AreEqual("in flight", settings.Data, "The temp file should be loaded, not replaced with defaults.");
	}

	[TestMethod]
	public void EmptyMainFileWithNoCandidates_IsArchivedNotOverwritten()
	{
		AbsoluteFilePath filePath = SettingsFilePath();
		AppData.FileSystem.File.WriteAllText(filePath, string.Empty);

		using DurableSettings settings = DurableSettings.LoadOrCreate();

		Assert.AreEqual(string.Empty, settings.Data, "With nothing to recover, defaults are loaded.");
		Assert.IsTrue(
			HasArchivedCopy(filePath, ".empty"),
			"The empty file should be archived, so its loss is visible, rather than silently overwritten.");
	}

	[TestMethod]
	public void Save_FlushesTheTempFileToDiskBeforeReplacingTheMainFile()
	{
		FlushRecordingMockFileSystem fileSystem = new();
		AppData.UseFileSystemOnThisThread(fileSystem);
		AbsoluteFilePath filePath = SettingsFilePath();
		AbsoluteFilePath tempFilePath = AppData.MakeTempFilePath(filePath);
		AppData.FileSystem.File.WriteAllText(filePath, "{\"Data\":\"old\"}");
		string? mainFileAtFlush = null;
		fileSystem.FlushedToDisk = () => mainFileAtFlush = fileSystem.File.ReadAllText(filePath);

		using (DurableSettings settings = new() { Data = "new" })
		{
			settings.Save();
		}

		CollectionAssert.Contains(fileSystem.PathsFlushedToDisk, fileSystem.Path.GetFullPath(tempFilePath));
		Assert.AreEqual("{\"Data\":\"old\"}", mainFileAtFlush, "The flush should happen before the main file is replaced.");
		StringAssert.Contains(fileSystem.File.ReadAllText(filePath), "new");
		Assert.IsFalse(fileSystem.File.Exists(tempFilePath), "The temp file should have replaced the main file.");
		Assert.IsFalse(fileSystem.File.Exists(AppData.MakeBackupFilePath(filePath)), "The backup should be removed after a save.");
	}

	[TestMethod]
	public void Save_WithNoMainFile_FlushesTheTempFileAndMovesItIntoPlace()
	{
		FlushRecordingMockFileSystem fileSystem = new();
		AppData.UseFileSystemOnThisThread(fileSystem);
		AbsoluteFilePath filePath = SettingsFilePath();

		using (DurableSettings settings = new() { Data = "first" })
		{
			settings.Save();
		}

		CollectionAssert.Contains(fileSystem.PathsFlushedToDisk, fileSystem.Path.GetFullPath(AppData.MakeTempFilePath(filePath)));
		StringAssert.Contains(fileSystem.File.ReadAllText(filePath), "first");
	}

	/// <summary>
	/// A <see cref="MockFileSystem"/> that records every stream flushed with <c>flushToDisk: true</c>.
	/// </summary>
	private sealed class FlushRecordingMockFileSystem : MockFileSystem
	{
		private readonly RecordingFileStreamFactory fileStream;

		public FlushRecordingMockFileSystem() => fileStream = new RecordingFileStreamFactory(this, base.FileStream);

		public List<string> PathsFlushedToDisk { get; } = [];

		public Action? FlushedToDisk { get; set; }

		public override IFileStreamFactory FileStream => fileStream;

		internal void RecordFlushToDisk(string path)
		{
			PathsFlushedToDisk.Add(Path.GetFullPath(path));
			FlushedToDisk?.Invoke();
		}
	}

	private sealed class RecordingFileStreamFactory(FlushRecordingMockFileSystem owner, IFileStreamFactory inner) : IFileStreamFactory
	{
		public IFileSystem FileSystem => owner;

		private RecordingStream Record(FileSystemStream stream) => new(owner, stream);

		public FileSystemStream New(Microsoft.Win32.SafeHandles.SafeFileHandle handle, FileAccess access) => inner.New(handle, access);

		public FileSystemStream New(Microsoft.Win32.SafeHandles.SafeFileHandle handle, FileAccess access, int bufferSize) => inner.New(handle, access, bufferSize);

		public FileSystemStream New(Microsoft.Win32.SafeHandles.SafeFileHandle handle, FileAccess access, int bufferSize, bool isAsync) => inner.New(handle, access, bufferSize, isAsync);

		public FileSystemStream New(string path, FileMode mode) => Record(inner.New(path, mode));

		public FileSystemStream New(string path, FileMode mode, FileAccess access) => Record(inner.New(path, mode, access));

		public FileSystemStream New(string path, FileMode mode, FileAccess access, FileShare share) => Record(inner.New(path, mode, access, share));

		public FileSystemStream New(string path, FileMode mode, FileAccess access, FileShare share, int bufferSize) => Record(inner.New(path, mode, access, share, bufferSize));

		public FileSystemStream New(string path, FileMode mode, FileAccess access, FileShare share, int bufferSize, bool useAsync) => Record(inner.New(path, mode, access, share, bufferSize, useAsync));

		public FileSystemStream New(string path, FileMode mode, FileAccess access, FileShare share, int bufferSize, FileOptions options) => Record(inner.New(path, mode, access, share, bufferSize, options));

		public FileSystemStream New(string path, FileStreamOptions options) => Record(inner.New(path, options));

		public FileSystemStream Wrap(FileStream fileStream) => inner.Wrap(fileStream);
	}

	private sealed class RecordingStream(FlushRecordingMockFileSystem owner, FileSystemStream inner) : FileSystemStream(inner, inner.Name, inner.IsAsync)
	{
		public override void Flush(bool flushToDisk)
		{
			inner.Flush(flushToDisk);
			if (flushToDisk)
			{
				owner.RecordFlushToDisk(inner.Name);
			}
		}

		protected override void Dispose(bool disposing)
		{
			if (disposing)
			{
				inner.Dispose();
			}

			base.Dispose(disposing);
		}
	}
}
