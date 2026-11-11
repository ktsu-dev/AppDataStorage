// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions.TestingHelpers;
using System.Text.Json.Serialization;

using ktsu.Semantics.Paths;

/// <summary>
/// A public property whose setter is not public is the natural shape for an encapsulated setting, so
/// its stored value has to load back rather than reset to the default.
/// </summary>
[TestClass]
public sealed class NonPublicSetterTests
{
	[ClassInitialize]
	public static void ClassSetup(TestContext testContext) => AppData.ConfigureForTesting(() => new MockFileSystem());

	[TestInitialize]
	public void SetupTest() => AppData.ClearCachedFileSystem();

	private static AbsoluteDirectoryPath Root(string name) =>
		AbsoluteDirectoryPath.Create(OperatingSystem.IsWindows() ? "C:/" : "/") / RelativeDirectoryPath.Create(name);

	public sealed class EncapsulatedSettings : AppData<EncapsulatedSettings>
	{
		public int Volume { get; private set; } = 50;
		public string Theme { get; internal set; } = "light";
		public int Plain { get; set; } = 1;

		[JsonIgnore]
		public int Ignored { get; private set; } = 7;

		public void Change(int volume, string theme, int ignored)
		{
			Volume = volume;
			Theme = theme;
			Ignored = ignored;
		}
	}

	[TestMethod]
	public void NonPublicSettersRoundTrip()
	{
		AbsoluteDirectoryPath root = Root("non_public_setters");
		using (EncapsulatedSettings settings = EncapsulatedSettings.LoadOrCreateIn(root))
		{
			settings.Change(80, "dark", ignored: 9);
			settings.Plain = 2;
			settings.Save();
		}

		using EncapsulatedSettings reloaded = EncapsulatedSettings.LoadOrCreateIn(root);
		Assert.AreEqual(80, reloaded.Volume, "A private setter should be used when loading.");
		Assert.AreEqual("dark", reloaded.Theme, "An internal setter should be used when loading.");
		Assert.AreEqual(2, reloaded.Plain, "A public setter should still be used when loading.");
		Assert.AreEqual(7, reloaded.Ignored, "A [JsonIgnore] property should still be ignored.");
	}

	[TestMethod]
	public void NextSaveKeepsTheStoredValue()
	{
		AbsoluteDirectoryPath root = Root("non_public_setters_resave");
		using (EncapsulatedSettings settings = EncapsulatedSettings.LoadOrCreateIn(root))
		{
			settings.Change(80, "dark", ignored: 0);
			settings.Save();
		}

		using (EncapsulatedSettings reloaded = EncapsulatedSettings.LoadOrCreateIn(root))
		{
			reloaded.Save();
		}

		using EncapsulatedSettings again = EncapsulatedSettings.LoadOrCreateIn(root);
		Assert.AreEqual(80, again.Volume, "Saving a reloaded instance should not erase the stored value.");
	}

	public sealed class ValidatedPrivateSettings : AppData<ValidatedPrivateSettings>
	{
		public int Volume
		{
			get;
			private set => field = value is < 0 or > 100 ? throw new ArgumentOutOfRangeException(nameof(value)) : value;
		} = 50;
	}

	public sealed class ValidatedPublicSettings : AppData<ValidatedPublicSettings>
	{
		public int Volume
		{
			get;
			set => field = value is < 0 or > 100 ? throw new ArgumentOutOfRangeException(nameof(value)) : value;
		} = 50;
	}

	public sealed class ValidatedPrivateSingleton : AppData<ValidatedPrivateSingleton>
	{
		public int Volume
		{
			get;
			private set => field = value is < 0 or > 100 ? throw new ArgumentOutOfRangeException(nameof(value)) : value;
		} = 50;
	}

	private const string OutOfRange = "{\"Volume\":150}";

	private static string[] Archived(AbsoluteFilePath filePath) =>
		AppData.FileSystem.Directory.GetFiles(filePath.AbsoluteDirectoryPath.ToString(), $"{Path.GetFileName(filePath.ToString())}.corrupt.*");

	private static AbsoluteFilePath WriteStored<T>(AbsoluteDirectoryPath root)
		where T : AppData<T>, IDisposable, new()
	{
		AbsoluteFilePath filePath;
		using (T probe = AppData<T>.LoadOrCreateIn(root))
		{
			filePath = probe.FilePath;
		}

		AppData.EnsureDirectoryExists(filePath);
		AppData.FileSystem.File.WriteAllText(filePath, OutOfRange);
		return filePath;
	}

	[TestMethod]
	public void PrivateSetterThatRejectsTheStoredValueFallsBackToDefaults()
	{
		AbsoluteDirectoryPath root = Root("non_public_setter_rejects");
		AbsoluteFilePath filePath = WriteStored<ValidatedPrivateSettings>(root);

		using ValidatedPrivateSettings loaded = ValidatedPrivateSettings.LoadOrCreateIn(root);

		Assert.AreEqual(50, loaded.Volume, "A value the private setter rejects should fall back to the default.");
		string[] archived = Archived(filePath);
		Assert.HasCount(1, archived, "The rejected file must be archived as .corrupt, not left to fail again.");
		Assert.AreEqual(OutOfRange, AppData.FileSystem.File.ReadAllText(archived[0]), "The archive must hold the original content.");
	}

	[TestMethod]
	public void PublicSetterThatRejectsTheStoredValueStillFallsBackToDefaults()
	{
		AbsoluteDirectoryPath root = Root("public_setter_rejects");
		AbsoluteFilePath filePath = WriteStored<ValidatedPublicSettings>(root);

		using ValidatedPublicSettings loaded = ValidatedPublicSettings.LoadOrCreateIn(root);

		Assert.AreEqual(50, loaded.Volume, "A value the public setter rejects should fall back to the default.");
		Assert.HasCount(1, Archived(filePath), "The rejected file must be archived as .corrupt.");
	}

	[TestMethod]
	[DoNotParallelize]
	public void GetDoesNotThrowWhenAPrivateSetterRejectsTheStoredValue()
	{
		AbsoluteFilePath filePath;
		using (ValidatedPrivateSingleton probe = new())
		{
			filePath = probe.FilePath;
		}

		AppData.EnsureDirectoryExists(filePath);
		AppData.FileSystem.File.WriteAllText(filePath, OutOfRange);

		ValidatedPrivateSingleton instance = ValidatedPrivateSingleton.Get();

		Assert.AreEqual(50, instance.Volume, "Get() should fall back to the default rather than throw.");
		Assert.AreSame(instance, ValidatedPrivateSingleton.Get(), "Get() should keep returning the recovered instance.");
		Assert.HasCount(1, Archived(filePath), "The rejected file must be archived as .corrupt.");
	}
}
