// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test;

using System;
using System.IO.Abstractions.TestingHelpers;
using System.Text.Json;
using ktsu.Semantics.Paths;
using ktsu.Semantics.Strings;
using Microsoft.VisualStudio.TestTools.UnitTesting;

/// <summary>
/// Guards that semantic string types persist as JSON strings.
/// </summary>
/// <remarks>
/// Reported in #152: an <see cref="AbsoluteDirectoryPath"/> property wrote as a char array
/// (<c>{ "$id": "2", "$values": ["C", ":", "\\", "t", ...] }</c>) rather than a string, because
/// <c>RoundTripStringJsonConverterFactory</c> declined the type and System.Text.Json fell back to
/// treating it as <see cref="System.Collections.Generic.IEnumerable{T}"/> of <see cref="char"/>.
/// Nothing pinned the correct shape, so the regression was invisible until someone opened a
/// settings file.
/// </remarks>
[TestClass]
public sealed class SemanticStringSerializationTests
{
	public sealed record Label : SemanticString<Label> { }

	// An absolute directory path that is valid on the host operating system. These tests never touch
	// the disk, the file system is mocked, but AbsoluteDirectoryPath still validates the shape of
	// what it is given, and a drive letter is not an absolute path on Linux.
	private static readonly AbsoluteDirectoryPath SampleDirectory =
		(OperatingSystem.IsWindows() ? "C:/temp" : "/tmp").As<AbsoluteDirectoryPath>();

	private sealed class PathAppData : AppData<PathAppData>
	{
		public string Data { get; set; } = string.Empty;
		public AbsoluteDirectoryPath Path { get; set; } = SampleDirectory;
		public Label Name { get; set; } = "widget".As<Label>();
	}

	[ClassInitialize]
	public static void ClassSetup(TestContext testContext)
	{
		AppData.ConfigureForTesting(() => new MockFileSystem());
		AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", "/app");
	}

	[TestInitialize]
	public void SetupTest() => AppData.ClearCachedFileSystem();

	[TestMethod]
	public void Save_WritesSemanticStringsAsJsonStrings()
	{
		using PathAppData appData = new() { Data = "Data for file 1" };
		appData.Save();

		string written = AppData.FileSystem.File.ReadAllText(appData.FilePath);

		Assert.DoesNotContain("$values", written, "Semantic strings must not persist as char arrays.");
		// Build the expected fragments through the serializer rather than hand-escaping them, so
		// the test asserts on the shape (a JSON string) without depending on escaping levels.
		string expectedPath = JsonSerializer.Serialize(appData.Path, AppData.JsonSerializerOptions);
		string expectedName = JsonSerializer.Serialize(appData.Name, AppData.JsonSerializerOptions);

		Assert.Contains(expectedPath, written, "Expected the path to persist as a JSON string.");
		Assert.Contains(expectedName, written, "Expected the name to persist as a JSON string.");
	}

	[TestMethod]
	public void Save_ThenLoad_RoundTripsSemanticStrings()
	{
		using PathAppData appData = new() { Data = "Data for file 1" };
		appData.Save();

		using PathAppData loaded = AppData<PathAppData>.LoadOrCreate();

		Assert.AreEqual(SampleDirectory, loaded.Path);
		Assert.AreEqual("widget".As<Label>(), loaded.Name);
	}
}
