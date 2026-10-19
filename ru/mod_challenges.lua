-- localfixes: названия испытаний модов по-русски — один словарь для экрана испытаний модов (menu_lists.lua), подсказок
-- DSS и энциклопедии. Ключ — английское имя из challenges.xml мода без метки в квадратных скобках ([FF], [Epiph] …):
-- номера испытаний модов у каждого игрока свои (зависят от подписок и порядка загрузки). Метка остаётся в строке
-- списка (19.10: «Там в [] указано что за мод»); модам без метки — своя короткая (TAGS, по номеру мода в Workshop).
-- Переводы — по смыслу испытания в самом моде (правила из challenges.xml, код и журналы изменений мода); имена
-- собственные и устоявшиеся (Грязный Пузырь, Вавилонская башня, Мир света) — как их принято называть по-русски.
return {
	TAGS = { ["1925867065"] = "IPECAC", ["3440586497"] = "LnF" },
	-- короткие имена модов для карточки (полное имя мода из metadata.xml длинное: «Damn, Fiend Folio: RELOADED»)
	MODS = { ["3778123093"] = "Fiend Folio", ["3503885496"] = "Heaven's Call", ["1925867065"] = "IPECAC",
		["3440586497"] = "Lost and Forgotten", ["3134600246"] = "Reshaken", ["3012430463"] = "Epiphany" },
	-- персонажи модов, которых нет на экране выбора (только для испытания): русское имя по имени из players.xml
	PLAYERS = { ["Sol (HC)"] = "Сол" },
	-- не испытания, а меню мода под видом испытания: на карточке — что оно открывает (вместо цели и вещей)
	SPECIAL = {
		["Achievements List (IPECAC Mod)"] = "Меню мода: открывает список достижений IPECAC",
		["Options Menu (IPECAC Mod) (WIP)"] = "Меню мода: открывает настройки IPECAC",
	},
	NAMES = {
		-- Fiend Folio: Reloaded (content-repentogon/challenges.xml)
		["The Devil's Harvest"] = "Жатва дьявола",           -- за Изверга-классика; предмет «Жатва дьявола» (EID FF)
		["No Offense"] = "Без обид",
		["Handle With Care"] = "Обращаться осторожно",
		["Dad's Home+"] = "Папа дома+",
		["Blursed"] = "Благопроклятый",                    -- blessed + cursed
		["Mr. Hands"] = "Мистер Руки",
		["Frog Mode"] = "Лягушачий режим",
		["Dirty Bubble Challenge"] = "Испытание Грязного Пузыря", -- злодей из «Губки Боба»
		["Pen Island"] = "Остров ручек",
		["The Real Jon"] = "Настоящий Джон",
		["Brick By Brick"] = "Кирпичик за кирпичиком",       -- за Голема, с Кирпичным камнем
		["Tower Offense"] = "Башни в атаку",                -- наоборот к tower defense
		["Craig's Challenge"] = "Испытание Крейга",
		["Allow Enemy Replacements"] = "Разрешить замену врагов",
		["Embryos Akimbo"] = "Эмбрионы с двух рук",
		["Magna Farta"] = "Магна Фарта",                    -- Magna Carta + пук (за Порченого ???, 6 бомб)
		["Isaac Rebuilt"] = "Исаак пересобран",
		["Boss Makes a Dollar"] = "Босс получает доллар",    -- «…а я получаю цент — поэтому какаю в рабочее время»
		["Baby Sensory"] = "Детская сенсорика",
		["The Gauntlet"] = "Сквозь строй",
		["Imperishable Night"] = "Бессмертная ночь",         -- Touhou 8, за Инабу
		["Hands On"] = "Своими руками",
		["Punkychunk Challenge"] = "Испытание Панкичанка",
		["Follow the Rabbit"] = "Следуй за кроликом",
		-- Heaven's Call (content/challenges.xml; «Побег от Вечноменяющегося», «Вавилонская башня» — как в переводе DSS)
		["Tower of Babel"] = "Вавилонская башня",
		["True Solar System"] = "Настоящая Солнечная система", -- к испытанию игры «Солнечная система», за Сол
		["Escape the Everchanger"] = "Побег от Вечноменяющегося",
		["Doomsday!"] = "Судный день!",
		["Omnitricked"] = "Кругом обман",
		-- IPECAC (два первых — не испытания, а меню мода: список достижений и настройки)
		["Achievements List (IPECAC Mod)"] = "Список достижений мода",
		["Options Menu (IPECAC Mod) (WIP)"] = "Настройки мода (в работе)",
		["2 Maggys 1 Ipecac (WIP)"] = "Две Мэгги, один Ипекак (в работе)",
		["Nuzlocke (WIP)"] = "Нузлок (в работе)",
		["Beatdown (WIP)"] = "Избиение (в работе)",
		["Rainbow Run"] = "Радужный забег",
		-- Lost and Forgotten
		["Danger Zone"] = "Опасная зона",
		["Damned"] = "Проклятый",
		["Pure Nightmare"] = "Чистый кошмар",
		["Protected"] = "Под защитой",
		-- Reshaken
		["Spirit Sage"] = "Мудрец духов",                    -- за Порченую Вифанию
		["Isaac Clicker"] = "Исаак-кликер",
		["World of Light"] = "Мир света",                    -- Super Smash Bros. Ultimate
		-- Epiphany
		["Kagemane no Jutsu"] = "Кагэманэ-но дзюцу",          -- «Наруто»: техника теневого подражания
		["NullPointerException"] = "NullPointerException",   -- имя ошибки Java — как есть
		["Pool!"] = "Бильярд!",                               -- мешок Самсона и мешок Людовико: удар — как кием по шару
		["Sweet Tooth"] = "Сладкоежка",
		["One With Nothing"] = "Единение с ничем",           -- карта Magic: The Gathering
		["Dealmaker"] = "Делец",
		["Overwhelming Odds"] = "Неравные силы",
		["He Who Casts The First Stone"] = "Кто первым бросит камень",
		["Retribution"] = "Возмездие",
		["Emperor Of Flies"] = "Император мух",
	},
}
