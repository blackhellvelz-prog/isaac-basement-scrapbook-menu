# Credits

Other mods this mod works with. Their files are not changed and not included here: our code reads their data or wraps their functions at runtime, and does nothing when the mod is not installed.

| Mod | Author | What our code does | Where |
|---|---|---|---|
| [REPENTOGON: Isaac Script Extender](https://steamcommunity.com/sharedfiles/filedetails/?id=3127536138) | jerb | menus are drawn through its menu API (MenuManager, CharacterMenu, XMLData, input masks) | `menu_*.lua, charcard.lua` |
| [Passive Skill Trees (Rep+)](https://steamcommunity.com/sharedfiles/filedetails/?id=3305869734) | Ab Aeterno | the Talents card on character select; its tree opens on the selected character (V / LB) | `menu_charsel.lua, charcard.lua` |
| [The Binding of Isaac: Epiphany](https://steamcommunity.com/sharedfiles/filedetails/?id=3012430463) | The Epiphany Team | tarnished characters on character select (its door to start them) | `menu_charsel.lua` |
| [External Item Descriptions](https://steamcommunity.com/sharedfiles/filedetails/?id=836319872) | Wofsauge | hotkey reminder on the pause screen reads its keys; item cards show its descriptions | `hotkeys.lua, menu_lists.lua` |
| [Fiend Folio: Reloaded](https://steamcommunity.com/sharedfiles/filedetails/?id=3778123093) | Erfly | its characters get a tab on character select; character data is read, not changed | `menu_charsel.lua, charcard.lua` |

Library: [REPENTOGON](https://steamcommunity.com/sharedfiles/filedetails/?id=3127536138) by jerb and the REPENTOGON team — required.

Thanks to the authors of these mods and to the whole Isaac modding community.
