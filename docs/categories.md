# Inventory Tags LT9 — approved category groups

Parents are mod-owned purpose groups. Children keep the game's raw category IDs and current language labels. The following layout is the owner-approved LT9 mapping; no child category is split or renamed.

| Parent | Native child category IDs |
|---|---|
| Food / 食物 | Food, Water |
| Medical / 医疗 | FirstAid, FirstAidWeapon |
| Weapons / 武器 | Weapon, WeaponImprovised, WeaponCrafted, BrokenWeapon, Ammo, WeaponPart, Explosives |
| Clothes / 衣服 | Clothing, Accessory, ProtectiveGear, Appearance, Ears, Tail |
| Tools / 工具 | Tool, ToolWeapon, LightSource, FireSource |
| Materials / 材料 | Material, MaterialWeapon, AnimalPart, AnimalPartWeapon, Paint |
| Books / 书籍 | Literature, SkillBook, Cartography, RecipeResource |
| Electronics / 电子 | Electronics, Communications |
| Vehicles / 车辆 | VehicleMaintenance, VehicleMaintenanceWeapon |
| Outdoors / 户外 | Gardening, GardeningWeapon, Fishing, FishingWeapon, Trapping, Camping, Animal |
| Kitchenware / 厨具 | Cooking, CookingWeapon |
| Containers / 容器 | Bag, Container, WaterContainer, Bear |
| Household / 家居 | Furniture, Household, HouseholdWeapon, Security |
| Entertainment / 娱乐 | Entertainment, Instrument, InstrumentWeapon, Sports, SportsWeapon |
| Toys / 玩具 | Memento, Teddy Bear, Goblin, Eye, Bunny, Fox, Squirrel, Beaver, Mole, Hedgehog, Badger, Dog, Raccoon, Duck, Spider, Bug |
| Other / 其他 | Junk, JunkWeapon, Corpse, Frog |

`Teddy Bear` contains a space. `Eye` is singular. These spellings are intentional.
`MaterialWeapon` belongs to Materials, not Weapons. Purpose/Weapon categories remain separate selectable children under their approved purpose groups.

Hidden and obsolete definitions are screened at item level before catalog discovery. Sixteen reviewed Base item IDs are excluded individually; their full list is in InventoryTags_Categories.lua. `Hidden` and `Generic` do not create ordinary menu entries. Empty internal groups such as Bandage, Wound, ZedDmg and MaleBody are not manufactured from translation keys. Physical FirstAid bandages and eligible Appearance products remain.

The vanilla 42.20.4 source audit found 76 eligible child categories under these 16 groups. This is a bounded static audit, not certification of every enabled mod or future game version. Unknown, actually loaded eligible category IDs remain distinct children under Other.
