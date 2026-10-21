local _, ns = ...
-- All eight client languages have navigation labels; missing explanatory text falls back to English.
local keys = { "bags", "bank", "characters", "prices", "settings", "search", "sections", "grid", "list", "new", "quest", "equipment", "consumable", "recipe", "materials", "keys", "junk", "other", "empty", "cached", "scan", "bagScan", "stop", "close", "custom", "pin", "hide", "disable", "show", "move", "next", "done", "quality", "name", "size", "questTag", "boe", "recipeTag" }
local rows = {
    enUS = { "Bags", "Bank", "Characters", "Prices", "Settings", "Search", "Sections", "Grid", "List", "New", "Quest", "Equipment", "Consumables", "Recipes", "Materials", "Keys", "Junk", "Other", "Free slots", "Cached", "Full scan", "Scan bag items", "Stop", "Close", "Custom category", "Pin", "Hide", "Disable", "Show", "Move category", "Next item", "Done", "Quality", "Name", "Size", "Q", "BoE", "Recipe" },
    koKR = { "가방", "은행", "캐릭터", "시세", "설정", "검색", "분류", "전체", "목록", "새 아이템", "퀘스트", "장비", "소모품", "제조법", "재료", "열쇠", "잡동사니", "기타", "빈 칸", "저장된 정보", "전체 시세 수집", "가방 아이템 조회", "중지", "닫기", "사용자 분류", "고정", "숨김", "분류 끄기", "표시", "분류 이동", "다음 아이템", "완료", "등급", "이름", "크기", "퀘", "비귀속", "책" },
    deDE = { "Taschen", "Bank", "Charaktere", "Preise", "Optionen", "Suchen", "Kategorien", "Raster", "Liste", "Neu", "Quest", "Ausrüstung", "Verbrauchbar", "Rezepte", "Materialien", "Schlüssel", "Plunder", "Sonstiges", "Freie Plätze", "Gespeichert", "Vollscan", "Taschen scannen", "Stopp", "Schließen", "Eigene Kategorie", "Anheften", "Ausblenden", "Deaktivieren", "Anzeigen", "Kategorie bewegen", "Nächster Gegenstand", "Fertig", "Qualität", "Name", "Größe", "Q", "BoE", "Rezept" },
    frFR = { "Sacs", "Banque", "Personnages", "Prix", "Options", "Rechercher", "Catégories", "Grille", "Liste", "Nouveau", "Quête", "Équipement", "Consommables", "Recettes", "Matériaux", "Clés", "Camelote", "Divers", "Places libres", "Enregistré", "Scan complet", "Scanner les sacs", "Arrêter", "Fermer", "Catégorie perso", "Épingler", "Masquer", "Désactiver", "Afficher", "Déplacer", "Objet suivant", "Terminé", "Qualité", "Nom", "Taille", "Q", "LdE", "Recette" },
    esES = { "Bolsas", "Banco", "Personajes", "Precios", "Opciones", "Buscar", "Categorías", "Cuadrícula", "Lista", "Nuevo", "Misión", "Equipo", "Consumibles", "Recetas", "Materiales", "Llaves", "Basura", "Otros", "Huecos libres", "Guardado", "Escaneo completo", "Escanear bolsas", "Parar", "Cerrar", "Categoría propia", "Fijar", "Ocultar", "Desactivar", "Mostrar", "Mover categoría", "Siguiente objeto", "Hecho", "Calidad", "Nombre", "Tamaño", "M", "LaE", "Receta" },
    ruRU = { "Сумки", "Банк", "Персонажи", "Цены", "Настройки", "Поиск", "Категории", "Сетка", "Список", "Новое", "Задания", "Экипировка", "Расходуемое", "Рецепты", "Материалы", "Ключи", "Хлам", "Прочее", "Свободно", "Сохранено", "Полный скан", "Скан сумок", "Стоп", "Закрыть", "Своя категория", "Закрепить", "Скрыть", "Отключить", "Показать", "Переместить", "Следующий", "Готово", "Качество", "Имя", "Размер", "З", "BoE", "Рецепт" },
    zhCN = { "背包", "银行", "角色", "价格", "设置", "搜索", "分类", "网格", "列表", "新物品", "任务", "装备", "消耗品", "配方", "材料", "钥匙", "杂物", "其他", "空位", "已缓存", "完整扫描", "扫描背包物品", "停止", "关闭", "自定义分类", "置顶", "隐藏", "禁用", "显示", "移动分类", "下一件", "完成", "品质", "名称", "大小", "任务", "装绑", "配方" },
    zhTW = { "背包", "銀行", "角色", "價格", "設定", "搜尋", "分類", "網格", "清單", "新物品", "任務", "裝備", "消耗品", "配方", "材料", "鑰匙", "雜物", "其他", "空位", "已快取", "完整掃描", "掃描背包物品", "停止", "關閉", "自訂分類", "置頂", "隱藏", "停用", "顯示", "移動分類", "下一件", "完成", "品質", "名稱", "大小", "任務", "裝綁", "配方" },
}
ns.languages = { "auto", "koKR", "enUS", "deDE", "frFR", "esES", "ruRU", "zhCN", "zhTW" }
function ns.T(key)
    local locale = ns.cfg and ns.cfg.language or "auto"
    if locale == "auto" then locale = GetLocale() end
    if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
    for i, k in ipairs(keys) do
        if k == key then return (rows[locale] or rows.enUS)[i] or rows.enUS[i] end
    end
    return key
end
ns.text = {
    general = { "일반", "General" },
    special = { "특수", "Special" },
    keyring = { "열쇠고리", "Keyring" },
    backpack = { "배낭", "Backpack" },
    combat = { "전투 중에는 아이템 조작을 잠시 멈춥니다.", "Item actions are paused during combat." },
    stale = { "아이템 위치가 바뀌었습니다. 다시 선택해 주세요.", "The item moved. Select it again." },
    bankUnknown = { "이 캐릭터로 은행을 방문하면 저장됩니다.", "Visit a bank on this character to cache its contents." },
    readonly = { "저장된 정보 · 보기 전용", "Cached snapshot · read only" },
    ahClosed = { "경매장을 연 뒤 수집해 주세요.", "Open the auction house before scanning." },
    ahBusy = { "경매장 조회 대기 중입니다. 잠시 뒤 다시 눌러 주세요.", "Auction queries are throttled. Try again shortly." },
    ahUnsupported = { "이 클라이언트의 경매 API를 지원하지 않습니다.", "This client's auction API is not supported." },
    timeout = { "시세 수집 응답이 없어 중단했습니다. 저장된 시세는 유지됩니다.", "Auction scan timed out; previous prices were kept." },
    ahWaiting = { "경매장 응답 대기 중", "Waiting for auction results" },
    ahEmpty = { "저장할 즉시구매 시세가 없습니다. 경매장 응답과 /ezbags debug를 확인해 주세요.", "No valid buyout prices were received. Check /ezbags debug." },
    ahCached = { "클라이언트에 남아 있는 경매 결과 읽는 중", "Reading the client's existing auction results" },
    ahPartial = { "일부 매물을 읽지 못했습니다", "Some auction rows could not be read" },
    ahShared = { "Tooltip 시세 공유 중 · Bags 직접 조회 꺼짐", "Sharing Tooltip prices · Bags scanning off" },
    queryError = { "검색식을 확인해 주세요: ", "Check the search expression: " },
    help = { "아이템 이름이나 용도를 입력하세요.\n예: 물약, 천, 연금", "Enter an item name or purpose.\nExamples: potion, cloth, alchemy" },
}
function ns.Text(key)
    local lang = ns.cfg and ns.cfg.language or "auto"
    local ko = lang == "koKR" or (lang == "auto" and GetLocale() == "koKR")
    return ns.text[key] and ns.text[key][ko and 1 or 2] or key
end
