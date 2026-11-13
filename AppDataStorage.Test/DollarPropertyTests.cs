// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test;

using System.IO.Abstractions.TestingHelpers;
using System.Text.Json;

using ktsu.Semantics.Paths;

/// <summary>
/// Property names that start with '$' are reference metadata to System.Text.Json under
/// ReferenceHandler.Preserve, so it writes them but refuses to read them. A save must not write a file
/// the next load would archive as corrupt, and a hand-added "$schema" must not reset every setting
/// (ktsu-dev/AppDataStorage#376).
/// </summary>
[TestClass]
public sealed class DollarPropertyTests
{
	[ClassInitialize]
	public static void ClassSetup(TestContext testContext) => AppData.ConfigureForTesting(() => new MockFileSystem());

	[TestInitialize]
	public void SetupTest() => AppData.ClearCachedFileSystem();

	private static AbsoluteDirectoryPath Root(string name) =>
		AbsoluteDirectoryPath.Create(OperatingSystem.IsWindows() ? "C:/" : "/") / RelativeDirectoryPath.Create(name);

	private static string[] Archived(AbsoluteFilePath filePath) =>
		AppData.FileSystem.Directory.GetFiles(filePath.AbsoluteDirectoryPath.ToString(), $"{Path.GetFileName(filePath.ToString())}.corrupt.*");

	public sealed class VariableSettings : AppData<VariableSettings>
	{
		public string Theme { get; set; } = "Light";
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Usage", "CA2227:Collection properties should be read only", Justification = "A get-only collection does not load back (ktsu-dev/AppDataStorage#341), so a settings dictionary needs a setter.")]
		public Dictionary<string, string> Variables { get; set; } = [];
	}

	[TestMethod]
	[DataRow("$HOME", "home")]
	[DataRow("$schema", "schema")]
	[DataRow("$id", "id")]
	public void SaveRefusesADollarKeyAndKeepsTheLastGoodFile(string key, string directory)
	{
		AbsoluteDirectoryPath root = Root($"dollar_key_{directory}");
		AbsoluteFilePath filePath;
		using (VariableSettings settings = VariableSettings.LoadOrCreateIn(root))
		{
			filePath = settings.FilePath;
			settings.Theme = "Dark";
			settings.Save();

			settings.Variables[key] = "/home/me";
			Assert.ThrowsExactly<JsonException>(settings.Save, "A save the next load could not read must throw.");
		}

		using VariableSettings reloaded = VariableSettings.LoadOrCreateIn(root);
		Assert.AreEqual("Dark", reloaded.Theme, "The last good save must still load.");
		Assert.IsEmpty(reloaded.Variables, "The refused save must not have reached the file.");
		Assert.IsEmpty(Archived(filePath), "Nothing should have been archived as corrupt.");
	}

	[TestMethod]
	public void OrdinaryDictionaryKeysStillRoundTrip()
	{
		AbsoluteDirectoryPath root = Root("ordinary_keys");
		using (VariableSettings settings = VariableSettings.LoadOrCreateIn(root))
		{
			settings.Variables["HOME"] = "/home/me";
			settings.Variables["a$b"] = "x";
			settings.Save();
		}

		using VariableSettings reloaded = VariableSettings.LoadOrCreateIn(root);
		Assert.AreEqual("/home/me", reloaded.Variables["HOME"]);
		Assert.AreEqual("x", reloaded.Variables["a$b"], "Only a leading '$' is metadata.");
	}

	[TestMethod]
	public void HandAddedSchemaPropertyLoads()
	{
		AbsoluteDirectoryPath root = Root("hand_added_schema");
		AbsoluteFilePath filePath;
		using (VariableSettings settings = VariableSettings.LoadOrCreateIn(root))
		{
			filePath = settings.FilePath;
		}

		AppData.FileSystem.File.WriteAllText(filePath, """{"$schema":"./settings.schema.json","Theme":"Dark","Variables":{"HOME":"/home/me"}}""");

		using VariableSettings reloaded = VariableSettings.LoadOrCreateIn(root);
		Assert.AreEqual("Dark", reloaded.Theme, "A hand-added $schema must not reset the settings.");
		Assert.AreEqual("/home/me", reloaded.Variables["HOME"]);
		Assert.IsEmpty(Archived(filePath), "A hand-added $schema must not get the file archived as corrupt.");
	}

	[TestMethod]
	public void SchemaPropertyBeforePreservedReferenceMetadataLoads()
	{
		AbsoluteDirectoryPath root = Root("schema_before_id");
		AbsoluteFilePath filePath;
		using (VariableSettings settings = VariableSettings.LoadOrCreateIn(root))
		{
			filePath = settings.FilePath;
			settings.Theme = "Dark";
			settings.Save();
		}

		string saved = AppData.FileSystem.File.ReadAllText(filePath);
		Assert.StartsWith("{", saved.TrimStart());
		AppData.FileSystem.File.WriteAllText(filePath, "{\"$schema\":\"./s.json\"," + saved.TrimStart()[1..]);

		using VariableSettings reloaded = VariableSettings.LoadOrCreateIn(root);
		Assert.AreEqual("Dark", reloaded.Theme, "A $schema ahead of the file's own $id must still load.");
		Assert.IsEmpty(Archived(filePath));
	}

	[TestMethod]
	public void NestedSchemaKeyIsStillUnreadable()
	{
		AbsoluteDirectoryPath root = Root("nested_schema");
		AbsoluteFilePath filePath;
		using (VariableSettings settings = VariableSettings.LoadOrCreateIn(root))
		{
			filePath = settings.FilePath;
		}

		AppData.FileSystem.File.WriteAllText(filePath, """{"Theme":"Dark","Variables":{"$schema":"x"}}""");

		using VariableSettings reloaded = VariableSettings.LoadOrCreateIn(root);
		Assert.AreEqual("Light", reloaded.Theme, "Only the top-level $schema is an editor hint; a nested one is still unreadable.");
		Assert.HasCount(1, Archived(filePath));
	}
}
