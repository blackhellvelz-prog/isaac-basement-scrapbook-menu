-- Basement Scrapbook Menu — меню игры в стиле рукописного альбома (автор blackhellvelz). Мод Мастерской собирается
-- tools/build_workshop.py из модулей src/localfixes (титул, выбор файла, главное меню, выбор персонажа, испытания,
-- статистика, коллекция, бестиарий, концовки, секреты, настройки, управление, экран модов; рукописный шрифт; памятка
-- горячих клавиш на паузе). Язык — по языку игры (русский или английский).
LOCALFIXES = LOCALFIXES or {}
if LOCALFIXES.AllInOne then   -- на ПК разработки стоит общая сборка localfixes — в ней всё это уже есть
	Isaac.DebugString("[Basement Scrapbook] пропуск: стоит общая сборка localfixes")
	return
end
local mod = RegisterMod("Basement Scrapbook Menu", 1)
mod.RenderEveryFrame = true                   -- меню рисуется каждый кадр (и при высокой частоте кадров)
LOCALFIXES.Mod = mod                          -- модули берут свой мод при загрузке

local function load(name)
	local ok, r = pcall(include, name)
	if not ok then Isaac.DebugString("[Basement Scrapbook] " .. name .. ": " .. tostring(r)) end
	return ok and r or nil
end

local charcard = load("charcard")             -- карточка персонажа на экране выбора
if charcard then LOCALFIXES.CharCard = charcard end
load("hand_text")                             -- рукописные шрифты меню и выбор языка
load("menu_charsel")                          -- выбор сложности и персонажа
load("menu_fx")                               -- частицы и движение элементов меню
load("menu_screens")                          -- титул, выбор файла, главное меню
load("menu_lists")                            -- остальные экраны меню
LOCALFIXES.Mod = mod
local hotkeys = load("hotkeys")               -- горячие клавиши модов и памятка на экране паузы
if type(hotkeys) == "table" then
	LOCALFIXES.EIDReminderHeld = hotkeys.EIDReminderHeld
	LOCALFIXES.DrawKeys = hotkeys.drawKeys
end
