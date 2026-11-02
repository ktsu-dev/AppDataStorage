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
}
