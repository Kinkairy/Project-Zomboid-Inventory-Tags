# Changelog

## 0.1.3

- Fix Auto Pack output receipt matching after native server input restoration, so crafted outputs return to the original container before the next batch.
- Set both mod.info version fields to 0.1.3, keeping their existing trilingual description unchanged; the owner verified single-player and multiplayer play.
- Publish the same 38-file runtime to private/public source and existing Workshop item 3806178177.

## 0.1.1-LT9

- Sync the owner-approved complete LT9 runtime rather than mixing old and new Lua modules.
- Organize native inventory categories under 16 approved parent groups; preserve raw child IDs, game translations and LT9 selection keys.
- Place purpose/weapon categories under their approved purpose groups, including MaterialWeapon under Materials.
- Filter hidden/obsolete definitions and the 16 reviewed exact Base debug/test/placeholder IDs before category discovery.
- Preserve physical FirstAid bandages and eligible Appearance products; do not expose empty internal categories as ordinary menu choices.
- Include EN/CN/CH source rows and deterministic translation/fallback checks.
- Document the bounded vanilla 42.20.4 static audit without claiming complete runtime or other-mod validation.

This remains the LT9 test build. Source synchronization does not deploy the mod, restart a server or upload a Workshop item.
