// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions;
using System.Runtime.Versioning;

using ktsu.Semantics.Paths;

/// <summary>
/// A save replaces the settings file with a newly written one, so on Unix it must carry the settings
/// file's permissions across: a file restricted to 0600 because it holds a token must not come back
/// 0644 (ktsu-dev/AppDataStorage#380). These run against the real file system, since permissions are
/// what the OS does with them.
/// </summary>
[TestClass]
[OSCondition(OperatingSystems.Linux | OperatingSystems.OSX)]
[SupportedOSPlatform("linux")]
[SupportedOSPlatform("macos")]
public sealed class UnixFileModeTests
{
	private const UnixFileMode OwnerOnly = UnixFileMode.UserRead | UnixFileMode.UserWrite;

	private string directory = string.Empty;

	public sealed class TokenSettings : AppData<TokenSettings>
	{
		public string Token { get; set; } = string.Empty;
	}

	[TestInitialize]
	public void SetupTest()
	{
		directory = Path.Combine(Path.GetTempPath(), $"appdatastorage_mode_{Guid.NewGuid():N}");
		Directory.CreateDirectory(directory);
		AppData.UseFileSystemOnThisThread(new FileSystem());
	}

	[TestCleanup]
	public void CleanupTest()
	{
		AppData.ClearCachedFileSystem();
		Directory.Delete(directory, recursive: true);
	}

	private AbsoluteDirectoryPath Root => AbsoluteDirectoryPath.Create(directory);

	[TestMethod]
	[DataRow(OwnerOnly)]
	[DataRow(UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.GroupRead)]
	[DataRow(UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.GroupRead | UnixFileMode.GroupWrite | UnixFileMode.OtherRead | UnixFileMode.OtherWrite)]
	public void SaveKeepsTheSettingsFilePermissions(UnixFileMode mode)
	{
		using TokenSettings settings = TokenSettings.LoadOrCreateIn(Root);
		string filePath = settings.FilePath.ToString();
		File.SetUnixFileMode(filePath, mode);

		settings.Token = "s3cr3t";
		settings.Save();

		Assert.AreEqual(mode, File.GetUnixFileMode(filePath), "A save must keep the settings file's permissions.");
		using TokenSettings reloaded = TokenSettings.LoadOrCreateIn(Root);
		Assert.AreEqual("s3cr3t", reloaded.Token, "The save must still have written the new content.");
	}

	[TestMethod]
	public void SavingTwiceKeepsOwnerOnly()
	{
		using TokenSettings settings = TokenSettings.LoadOrCreateIn(Root);
		string filePath = settings.FilePath.ToString();
		File.SetUnixFileMode(filePath, OwnerOnly);

		settings.Token = "one";
		settings.Save();
		settings.Token = "two";
		settings.Save();

		Assert.AreEqual(OwnerOnly, File.GetUnixFileMode(filePath));
	}

	[TestMethod]
	public void AReaderHoldingAStaleTempFileNeverSeesTheNewContent()
	{
		using TokenSettings settings = TokenSettings.LoadOrCreateIn(Root);
		string filePath = settings.FilePath.ToString();
		File.SetUnixFileMode(filePath, OwnerOnly);

		// A .tmp left by an interrupted save, world-readable, which another account has already opened.
		string tempPath = filePath + ".tmp";
		File.WriteAllText(tempPath, string.Empty);
		File.SetUnixFileMode(tempPath, OwnerOnly | UnixFileMode.GroupRead | UnixFileMode.OtherRead);
		using FileStream reader = new(tempPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);

		settings.Token = "s3cr3t";
		settings.Save();

		using StreamReader text = new(reader);
		Assert.DoesNotContain("s3cr3t", text.ReadToEnd(), "The save must write to a newly created file, not through a descriptor someone else already holds.");
		Assert.AreEqual(OwnerOnly, File.GetUnixFileMode(filePath));
	}

	[TestMethod]
	public void ANewSettingsFileKeepsTheDefaultMode()
	{
		string probe = Path.Combine(directory, "probe");
		File.WriteAllText(probe, string.Empty);
		UnixFileMode defaultMode = File.GetUnixFileMode(probe);

		using TokenSettings settings = TokenSettings.LoadOrCreateIn(Root);

		Assert.AreEqual(defaultMode, File.GetUnixFileMode(settings.FilePath.ToString()), "A new file is created as before, with the process's default mode.");
	}
}
