## v1.19.0 (minor)

Changes since v1.18.0:

- Save and load NaN and infinite float settings [patch] (#363) (matt-edmondson)
- Document that LoadOrCreate() is a separate copy from Get() [patch] (#360) (matt-edmondson)
- Regenerate CompatibilitySuppressions.xml after the Polyfill 11.4.5 bump [patch] (#359) (matt-edmondson)
- Time the save debounce on a monotonic clock [patch] (matt-edmondson)
- Add LoadOrCreateIn to load app data from an absolute root directory [minor] (matt-edmondson)
- Recover the backup when the temp file left by a crash is empty [patch] (matt-edmondson)
- Use Assert.HasCount for the archive count in the new test (Claude)
- Recover from a saved value a semantic type rejects, and retry Get() after a failed load [patch] (Claude)
- Archive a settings file that fails to deserialize instead of deleting it [patch] (Claude)

