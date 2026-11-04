// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions.TestingHelpers;

using ktsu.Semantics.Paths;

/// <summary>
/// NaN and the infinities are ordinary settings values ("no limit", "not measured yet"), so they
/// have to save and load back like any other number.
/// </summary>
[TestClass]
public sealed class NonFiniteNumberTests
{
	[ClassInitialize]
	public static void ClassSetup(TestContext testContext) => AppData.ConfigureForTesting(() => new MockFileSystem());

	[TestInitialize]
	public void SetupTest() => AppData.ClearCachedFileSystem();

	private static AbsoluteDirectoryPath Root(string name) =>
		AbsoluteDirectoryPath.Create(OperatingSystem.IsWindows() ? "C:/" : "/") / RelativeDirectoryPath.Create(name);

	public sealed class FloatSettings : AppData<FloatSettings>
	{
		public double Zoom { get; set; } = 4;
		public float Gain { get; set; } = 4;
	}

	public sealed class NanDefaults : AppData<NanDefaults>
	{
		public float LastMeasured { get; set; } = float.NaN;
		public double MaxZoom { get; set; } = double.PositiveInfinity;
	}

	[TestMethod]
	[DataRow(double.NaN)]
	[DataRow(double.PositiveInfinity)]
	[DataRow(double.NegativeInfinity)]
	public void NonFiniteDoubleRoundTrips(double value)
	{
		AbsoluteDirectoryPath root = Root("non_finite_double");
		using (FloatSettings settings = FloatSettings.LoadOrCreateIn(root))
		{
			settings.Zoom = value;
			settings.Save();
		}

		using FloatSettings reloaded = FloatSettings.LoadOrCreateIn(root);
		Assert.AreEqual(value, reloaded.Zoom, "A non-finite double should load back unchanged.");
	}

	[TestMethod]
	[DataRow(float.NaN)]
	[DataRow(float.PositiveInfinity)]
	[DataRow(float.NegativeInfinity)]
	public void NonFiniteSingleRoundTrips(float value)
	{
		AbsoluteDirectoryPath root = Root("non_finite_single");
		using (FloatSettings settings = FloatSettings.LoadOrCreateIn(root))
		{
			settings.Gain = value;
			settings.Save();
		}

		using FloatSettings reloaded = FloatSettings.LoadOrCreateIn(root);
		Assert.AreEqual(value, reloaded.Gain, "A non-finite float should load back unchanged.");
	}

	[TestMethod]
	public void LoadOrCreateSucceedsForNonFiniteDefaults()
	{
		AbsoluteDirectoryPath root = Root("nan_defaults");
		using (NanDefaults created = NanDefaults.LoadOrCreateIn(root))
		{
			Assert.IsTrue(float.IsNaN(created.LastMeasured), "The NaN default should survive creation.");
		}

		using NanDefaults reloaded = NanDefaults.LoadOrCreateIn(root);
		Assert.IsTrue(float.IsNaN(reloaded.LastMeasured), "The NaN default should load back from the file creation wrote.");
		Assert.AreEqual(double.PositiveInfinity, reloaded.MaxZoom, "The infinite default should load back from the file creation wrote.");
	}

	[TestMethod]
	public void FiniteNumbersAreStillWrittenAsJsonNumbers()
	{
		AbsoluteDirectoryPath root = Root("finite_format");
		using FloatSettings settings = FloatSettings.LoadOrCreateIn(root);
		settings.Zoom = 1.5;
		settings.Save();

		string json = AppData.FileSystem.File.ReadAllText(settings.FilePath);
		StringAssert.Contains(json, "\"Zoom\": 1.5", "Finite numbers should keep their existing JSON number format.");
	}

	[TestMethod]
	public void FileWrittenWithoutNamedLiteralsStillLoads()
	{
		AbsoluteDirectoryPath root = Root("legacy_format");
		AbsoluteFilePath filePath;
		using (FloatSettings settings = FloatSettings.LoadOrCreateIn(root))
		{
			filePath = settings.FilePath;
		}

		AppData.FileSystem.File.WriteAllText(filePath, "{\n  \"$id\": \"1\",\n  \"Zoom\": 2.25,\n  \"Gain\": 3\n}");

		using FloatSettings reloaded = FloatSettings.LoadOrCreateIn(root);
		Assert.AreEqual(2.25, reloaded.Zoom, "A file in the current format should still load.");
		Assert.AreEqual(3f, reloaded.Gain, "A file in the current format should still load.");
	}
}
