## v1.19.0 (minor)

Changes since v1.18.0:

- Time the save debounce on a monotonic clock [patch] (matt-edmondson)
- Add LoadOrCreateIn to load app data from an absolute root directory [minor] (matt-edmondson)
- Recover the backup when the temp file left by a crash is empty [patch] (matt-edmondson)
- Use Assert.HasCount for the archive count in the new test (Claude)
- Recover from a saved value a semantic type rejects, and retry Get() after a failed load [patch] (Claude)
- Archive a settings file that fails to deserialize instead of deleting it [patch] (Claude)

