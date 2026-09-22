# Inventory Tags LT9 — validation scope

The approved source is 0.1.1-LT9, protocol/schema 6. The originally audited runtime contains 35 files. Its original Git tree is `7e5cb554bf867b9c7cb27b21787f26317be6d113`.

An owner-provided vanilla 42.20.4 source snapshot was statically audited: 1004 script files, 5105 item declarations, 5092 unique item IDs and 82 native category IDs. Duplicate declarations were not counted as new items. The bounded screen excluded 198 explicitly hidden IDs and 16 individually reviewed test/debug/placeholder IDs. One Base.Animal/Generic definition is menu-suppressed only. The resulting ordinary catalog had 4877 unique IDs and 76 child categories.

The hidden definitions comprised Appearance 27, Bandage 34, Wound 60, ZedDmg 74 and MaleBody 3. Normal FirstAid bandages and nine physical Appearance items remain. No obsolete=true declaration was found in the collected item definitions; the runtime obsolete-state check remains enabled.

The LT9 exact-ID additions were Base.TestWaterMug, Base.TestHotDrink, Base.TestMug, Base.TestDebugWater, Base.DebugFluid, Base.BucketWaterDebug, Base.Animal_Item_Dummy and Base.Bitters. These supplement the eight already reviewed LT8 exclusions. The code does not globally exclude names containing test/debug, small weights, missing models or missing recipe references.

The LT9 package records successful Lua 5.4 syntax checks for 20 runtime Lua files, 305 regression cases in both standard and next=nil environments, and source-derived proxy checks for all 5092 unique IDs in both environments. The publication check independently verified the 35 runtime files and all 13 generated trilingual/fallback outputs against the prepared source package.

These checks do not constitute Windows installer execution, PZ Java/Kahlua runtime execution, dedicated-server acceptance, or exhaustive other-mod compatibility testing. A retained item passed bounded exclusion criteria; it was not necessarily functionally tested in game.

No original game source collection, source-derived full-game fixture, machine details, save, server configuration, credentials or private repository history belongs in the public mirror. Future collectors must write their result ZIP beside the collector script.

## Compact cover and icon integration (2026-09-22)

The LT9 source version and protocol are unchanged. The runtime contains 37
files: the original 35 source files, with only `icon=icon.png` added to each
`mod.info`, plus root and B42.20 icon files. Its Git tree is
`3f107a9ccba5893b58ddd50ea926879b06dc5de8`.

All 20 runtime Lua files and the existing translation files remain byte-identical
to the approved LT9 package. Local checks verify the 37-file manifest/tree and
all 13 generated trilingual/fallback outputs. The two `mod.info` files are
identical and their only change from LT9 is the icon reference.

The owner requested smaller images. All four repository PNG exports are the
same 256 x 256, 20-color, 10,236-byte image derived from the approved illustration.
Downsizing and palette reduction trade resolution/color detail for file size;
the image is not redrawn. PNG decoding and chunk integrity were checked locally.
SHA-256: `cf0d69836a58827550dd325bcffa46ad450b549b36ae1e7fe61c117048618e7f`.
Git blob: `dbb9d294055611f32675952930d0158042a95e9b`.
The filename `assets/cover-master.png` now holds this optimized export; the
original 1254 x 1254 image remains in the previously supplied review ZIP.

Only the 10 approved cover/icon integration paths are changed. These checks are
not Windows installer execution, deployment, Workshop publication, or fresh
PZ engine/controller/multiplayer validation.

The two generated English guide candidates remain excluded; this revision adds
no explanatory screenshots and makes no classification, sorting, or packing
logic changes.
