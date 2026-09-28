# Inventory Tags 0.1.5

Source base: canonical 23cbaac13f0e326076b2ef2691a2a7d4d970f0cb,
with clean Inventory Tags 0.1.4 source at the approved checkpoint.

B42.21.0 native createMenuNoItems triggers OnFillInventoryContextMenuNoItems,
but the engine's initial Events table omits it. Register only this missing event
through LuaEventManager.AddEvent before attaching the existing IT callback.
Existing event listeners and repeated-load guards are preserved. Add empty
AnimSets/actiongroups directory placeholders under common/media and 42.20/media.

The 90-case selection suite executes the installed native empty-menu function
for mouse/controller and inventory/loot, plus pause, disabled selection and
existing-listener cases. Old hooks fail the missing-event regression; repaired
hooks pass. A real game Java/Kahlua probe verifies event registration. The existing
75-case native packing suite, Lua syntax, 13 trilingual outputs and complete
42-file runtime manifest pass. No selection/filter/packing transaction changed.

Workshop 3806178177 manifest 1938499946890324543 independently downloads
42 exact source files; runtime Git tree a400864dc724bb50de52b2eb4083f57b3121c732.
Live description, title, cover, tags and visibility remain exactly unchanged.
No game/server restart or manual deployment was performed; actual in-game
acceptance remains pending after the updated package loads.
