// Copyright (c) 2023-2026 ktsu-dev contributors

namespace ktsu.AppDataStorage.Test
{
	using System.IO.Abstractions.TestingHelpers;

	using ktsu.Semantics.Paths;

	/// <summary>
	/// The default file name is the simple type name, so two types with the same name, or two closed
	/// generics of one class, resolve to one file. Each would load the other's file and save over it, so
	/// the second type to use the file must be refused (ktsu-dev/AppDataStorage#336).
	/// </summary>
	[TestClass]
	public sealed class FileCollisionTests
	{
		[ClassInitialize]
		public static void ClassSetup(TestContext testContext) => AppData.ConfigureForTesting(() => new MockFileSystem());

		[TestInitialize]
		public void SetupTest() => AppData.ClearCachedFileSystem();

		private static AbsoluteDirectoryPath Root(string name) =>
			AbsoluteDirectoryPath.Create(OperatingSystem.IsWindows() ? "C:/" : "/") / RelativeDirectoryPath.Create(name);

		[TestMethod]
		public void SameNamedTypesInDifferentNamespacesAreRefused()
		{
			AbsoluteDirectoryPath root = Root("same_named_types");
			using (CollisionPluginA.Settings a = CollisionPluginA.Settings.LoadOrCreateIn(root))
			{
				a.ApiKey = "secret-A";
				a.Save();
			}

			InvalidOperationException ex = Assert.ThrowsExactly<InvalidOperationException>(() => CollisionPluginB.Settings.LoadOrCreateIn(root));
			Assert.Contains("CollisionPluginA.Settings", ex.Message, "The message should name the type already using the file.");
			Assert.Contains("CollisionPluginB.Settings", ex.Message, "The message should name the type that was refused.");

			using CollisionPluginA.Settings reloaded = CollisionPluginA.Settings.LoadOrCreateIn(root);
			Assert.AreEqual("secret-A", reloaded.ApiKey, "The first type's data must be untouched.");
		}

		[TestMethod]
		public void ClosedGenericsOfOneClassAreRefused()
		{
			AbsoluteDirectoryPath root = Root("closed_generics");
			using (CollisionGeneric<int> ints = CollisionGeneric<int>.LoadOrCreateIn(root))
			{
				ints.Save();
			}

			InvalidOperationException ex = Assert.ThrowsExactly<InvalidOperationException>(() => CollisionGeneric<string>.LoadOrCreateIn(root));
			Assert.Contains("CollisionGeneric<System.Int32>", ex.Message);
			Assert.Contains("CollisionGeneric<System.String>", ex.Message);
		}

		[TestMethod]
		public void SaveIsRefusedForASecondTypeToo()
		{
			AbsoluteDirectoryPath root = Root("refused_save");
			using CollisionPluginA.Settings a = CollisionPluginA.Settings.LoadOrCreateIn(root);
			using CollisionPluginB.Settings b = new() { Root = root };

			Assert.ThrowsExactly<InvalidOperationException>(b.Save, "A save must not reach a file another type uses.");
		}

		[TestMethod]
		public void TheSameTypeCanLoadAndSaveRepeatedly()
		{
			AbsoluteDirectoryPath root = Root("same_type_twice");
			using (CollisionPluginA.Settings first = CollisionPluginA.Settings.LoadOrCreateIn(root))
			{
				first.ApiKey = "one";
				first.Save();
			}

			using CollisionPluginA.Settings second = CollisionPluginA.Settings.LoadOrCreateIn(root);
			second.ApiKey = "two";
			second.Save();
			Assert.AreEqual("two", CollisionPluginA.Settings.LoadOrCreateIn(root).ApiKey);
		}

		[TestMethod]
		public void SameNamedTypesWithTheirOwnFileNamesCoexist()
		{
			AbsoluteDirectoryPath root = Root("own_file_names");
			using CollisionPluginA.Settings a = CollisionPluginA.Settings.LoadOrCreateIn(root);
			using CollisionPluginB.Settings b = CollisionPluginB.Settings.LoadOrCreateIn(root, FileName.Create("plugin_b.json"));
			a.ApiKey = "secret-A";
			a.Save();
			b.Volume = 7;
			b.Save();

			Assert.AreEqual("secret-A", CollisionPluginA.Settings.LoadOrCreateIn(root).ApiKey);
			Assert.AreEqual(7, CollisionPluginB.Settings.LoadOrCreateIn(root, FileName.Create("plugin_b.json")).Volume);
		}

		[TestMethod]
		public void TheSamePathOnAnotherFileSystemIsAnotherFile()
		{
			AbsoluteDirectoryPath root = Root("other_file_system");
			using (CollisionPluginA.Settings a = CollisionPluginA.Settings.LoadOrCreateIn(root))
			{
				a.Save();
			}

			AppData.UseFileSystemOnThisThread(new MockFileSystem());
			using (CollisionPluginB.Settings b = CollisionPluginB.Settings.LoadOrCreateIn(root))
			{
				b.Volume = 7;
				b.Save();
			}

			Assert.AreEqual(7, CollisionPluginB.Settings.LoadOrCreateIn(root).Volume, "On its own file system, the second type owns the path.");
		}
	}

	public sealed class CollisionGeneric<TValue> : AppData<CollisionGeneric<TValue>>
	{
		public TValue? Value { get; set; }
	}
}

namespace ktsu.AppDataStorage.Test.CollisionPluginA
{
	public sealed class Settings : AppData<Settings>
	{
		public string ApiKey { get; set; } = string.Empty;
	}
}

namespace ktsu.AppDataStorage.Test.CollisionPluginB
{
	public sealed class Settings : AppData<Settings>
	{
		public int Volume { get; set; } = 50;
	}
}
