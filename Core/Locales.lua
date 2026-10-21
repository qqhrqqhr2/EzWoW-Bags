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
-- Longer messages in all eight languages: { koKR, enUS, deDE, frFR, esES, ruRU, zhCN, zhTW }
local ORDER = { koKR = 1, enUS = 2, deDE = 3, frFR = 4, esES = 5, ruRU = 6, zhCN = 7, zhTW = 8 }
local function langIndex()
    local locale = ns.cfg and ns.cfg.language or "auto"
    if locale == "auto" then locale = GetLocale() end
    if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
    return ORDER[locale] or 2
end
ns.LangIndex = langIndex
ns.text = {
    general = { "일반", "General", "Allgemein", "Général", "General", "Обычные", "普通", "一般" },
    special = { "특수", "Special", "Spezial", "Spécial", "Especial", "Особые", "特殊", "特殊" },
    keyring = { "열쇠고리", "Keyring", "Schlüsselbund", "Trousseau", "Llavero", "Связка ключей", "钥匙链", "鑰匙圈" },
    backpack = { "배낭", "Backpack", "Rucksack", "Sac à dos", "Mochila", "Рюкзак", "行囊", "背包" },
    combat = { "전투 중에는 아이템 조작을 잠시 멈춥니다.", "Item actions are paused during combat.",
        "Im Kampf werden Gegenstandsaktionen angehalten.", "Les actions sur les objets sont suspendues en combat.",
        "Las acciones con objetos se pausan en combate.", "В бою действия с предметами приостановлены.",
        "战斗中暂停物品操作。", "戰鬥中暫停物品操作。" },
    stale = { "아이템 위치가 바뀌었습니다. 다시 선택해 주세요.", "The item moved. Select it again.",
        "Der Gegenstand wurde verschoben. Bitte erneut auswählen.", "L'objet a été déplacé. Sélectionnez-le à nouveau.",
        "El objeto se ha movido. Selecciónalo de nuevo.", "Предмет переместился. Выберите его снова.",
        "物品位置已改变，请重新选择。", "物品位置已改變，請重新選擇。" },
    bankUnknown = { "이 캐릭터로 은행을 방문하면 저장됩니다.", "Visit a bank on this character to cache its contents.",
        "Besuche mit diesem Charakter eine Bank, um den Inhalt zu speichern.", "Visitez une banque avec ce personnage pour enregistrer son contenu.",
        "Visita un banco con este personaje para guardar su contenido.", "Посетите банк этим персонажем, чтобы сохранить содержимое.",
        "用此角色访问一次银行即可保存内容。", "用此角色造訪一次銀行即可儲存內容。" },
    readonly = { "저장된 정보 · 보기 전용", "Cached snapshot · read only", "Gespeicherter Stand · nur ansehen",
        "Instantané enregistré · lecture seule", "Copia guardada · solo lectura", "Сохранённые данные · только просмотр",
        "已保存的快照 · 只读", "已儲存的快照 · 唯讀" },
    ahClosed = { "경매장을 연 뒤 수집해 주세요.", "Open the auction house before scanning.",
        "Öffne vor dem Scan das Auktionshaus.", "Ouvrez l'hôtel des ventes avant l'analyse.",
        "Abre la casa de subastas antes de escanear.", "Откройте аукцион перед сканированием.",
        "请先打开拍卖行再扫描。", "請先打開拍賣場再掃描。" },
    ahBusy = { "경매장 조회 대기 중입니다. 잠시 뒤 다시 눌러 주세요.", "Auction queries are throttled. Try again shortly.",
        "Auktionsabfragen sind gedrosselt. Versuche es gleich noch einmal.", "Les requêtes sont limitées. Réessayez dans un instant.",
        "Las consultas están limitadas. Inténtalo de nuevo en breve.", "Запросы к аукциону ограничены. Повторите чуть позже.",
        "拍卖行查询受限，请稍后再试。", "拍賣場查詢受限，請稍後再試。" },
    ahUnsupported = { "이 클라이언트의 경매 API를 지원하지 않습니다.", "This client's auction API is not supported.",
        "Die Auktions-API dieses Clients wird nicht unterstützt.", "L'API d'enchères de ce client n'est pas prise en charge.",
        "La API de subastas de este cliente no es compatible.", "API аукциона этого клиента не поддерживается.",
        "不支持此客户端的拍卖 API。", "不支援此用戶端的拍賣 API。" },
    timeout = { "시세 수집 응답이 없어 중단했습니다. 저장된 시세는 유지됩니다.", "Auction scan timed out; previous prices were kept.",
        "Zeitüberschreitung beim Scan; bisherige Preise bleiben erhalten.", "Délai dépassé ; les prix précédents sont conservés.",
        "El escaneo agotó el tiempo; se conservan los precios anteriores.", "Сканирование прервано по таймауту; прежние цены сохранены.",
        "扫描超时，已保留之前的价格。", "掃描逾時，已保留先前的價格。" },
    ahWaiting = { "경매장 응답 대기 중", "Waiting for auction results", "Warte auf Auktionsergebnisse",
        "En attente des résultats", "Esperando resultados de la subasta", "Ожидание результатов аукциона",
        "等待拍卖行结果", "等待拍賣場結果" },
    ahEmpty = { "저장할 즉시구매 시세가 없습니다. 경매장 응답과 /ezbags debug를 확인해 주세요.", "No valid buyout prices were received. Check /ezbags debug.",
        "Keine gültigen Sofortkaufpreise erhalten. Prüfe /ezbags debug.", "Aucun prix d'achat immédiat valide reçu. Vérifiez /ezbags debug.",
        "No se recibieron precios de compra válidos. Revisa /ezbags debug.", "Не получено цен выкупа. Проверьте /ezbags debug.",
        "未收到有效的一口价。请检查 /ezbags debug。", "未收到有效的直購價。請檢查 /ezbags debug。" },
    ahCached = { "클라이언트에 남아 있는 경매 결과 읽는 중", "Reading the client's existing auction results",
        "Lese vorhandene Auktionsergebnisse des Clients", "Lecture des résultats déjà reçus par le client",
        "Leyendo los resultados ya recibidos por el cliente", "Чтение уже полученных результатов аукциона",
        "正在读取客户端已有的拍卖结果", "正在讀取用戶端已有的拍賣結果" },
    ahPartial = { "일부 매물을 읽지 못했습니다", "Some auction rows could not be read", "Einige Auktionen konnten nicht gelesen werden",
        "Certaines enchères n'ont pas pu être lues", "No se pudieron leer algunas subastas", "Некоторые лоты не удалось прочитать",
        "部分拍卖条目无法读取", "部分拍賣項目無法讀取" },
    ahShared = { "Tooltip 시세 공유 중 · Bags 직접 조회 꺼짐", "Sharing Tooltip prices · Bags scanning off",
        "Preise von Tooltip geteilt · Bags-Scan aus", "Prix partagés avec Tooltip · analyse Bags désactivée",
        "Precios compartidos con Tooltip · escaneo de Bags desactivado", "Цены берутся из Tooltip · скан Bags выключен",
        "共享 Tooltip 价格 · Bags 扫描关闭", "共用 Tooltip 價格 · Bags 掃描關閉" },
    queryError = { "검색식을 확인해 주세요: ", "Check the search expression: ", "Suchausdruck prüfen: ",
        "Vérifiez l'expression de recherche : ", "Revisa la expresión de búsqueda: ", "Проверьте поисковый запрос: ",
        "请检查搜索表达式：", "請檢查搜尋運算式：" },
    help = { "아이템 이름이나 용도를 입력하세요.\n예: 물약, 천, 연금", "Enter an item name or purpose.\nExamples: potion, cloth, alchemy",
        "Gib einen Gegenstandsnamen oder Verwendungszweck ein.\nBeispiele: Trank, Stoff, Alchemie",
        "Saisissez un nom d'objet ou un usage.\nExemples : potion, tissu, alchimie",
        "Escribe el nombre o el uso de un objeto.\nEjemplos: poción, paño, alquimia",
        "Введите название или назначение предмета.\nНапример: зелье, ткань, алхимия",
        "输入物品名称或用途。\n例如：药水、布、炼金", "輸入物品名稱或用途。\n例如：藥水、布、鍊金" },
    stacks = { "%d개 묶음", "%d stacks", "%d Stapel", "%d piles", "%d montones", "Стопок: %d", "%d 组", "%d 組" },
    noSpace = { "일반 가방에 빈 칸이 없습니다.", "No general bag space.", "Kein freier Platz in normalen Taschen.",
        "Plus de place dans les sacs normaux.", "No queda espacio en las bolsas normales.", "Нет места в обычных сумках.",
        "普通背包没有空位。", "一般背包沒有空位。" },
    nameLength = { "분류 이름은 1–80바이트로 입력해 주세요.", "Category name: 1–80 bytes.", "Kategoriename: 1–80 Bytes.",
        "Nom de catégorie : 1 à 80 octets.", "Nombre de categoría: 1–80 bytes.", "Имя категории: 1–80 байт.",
        "分类名称：1–80 字节。", "分類名稱：1–80 位元組。" },
    maxCategories = { "사용자 분류는 40개까지 만들 수 있습니다.", "Maximum 40 categories.", "Höchstens 40 Kategorien.",
        "40 catégories au maximum.", "Máximo 40 categorías.", "Не больше 40 категорий.", "最多 40 个分类。", "最多 40 個分類。" },
    mail = { "우편", "Mail", "Post", "Courrier", "Correo", "Почта", "邮件", "郵件" },
    trade = { "거래", "Trade", "Handel", "Échange", "Comercio", "Обмен", "交易", "交易" },
    merchant = { "상인에게 판매", "Sell to vendor", "An Händler verkaufen", "Vendre au marchand", "Vender al mercader",
        "Продать торговцу", "卖给商人", "賣給商人" },
}
function ns.Text(key)
    local row = ns.text[key]
    if not row then return key end
    return row[langIndex()] or row[2] or key
end

-- Option labels and search errors keyed by their English text: { deDE, frFR, esES, ruRU, zhCN, zhTW }
local byEnglish = {
    ["Auto (game language)"] = { "Automatisch (Spielsprache)", "Automatique (langue du jeu)", "Automático (idioma del juego)", "Авто (язык игры)", "自动（游戏语言）", "自動（遊戲語言）" },
    ["Language"] = { "Sprache", "Langue", "Idioma", "Язык", "语言", "語言" },
    ["Replace default bags"] = { "Standardtaschen ersetzen", "Remplacer les sacs par défaut", "Reemplazar bolsas predeterminadas", "Заменить стандартные сумки", "替换默认背包", "取代預設背包" },
    ["Applies after login or /reload."] = { "Gilt nach dem Einloggen oder /reload.", "S'applique après connexion ou /reload.", "Se aplica tras iniciar sesión o /reload.", "Применяется после входа или /reload.", "登录或 /reload 后生效。", "登入或 /reload 後生效。" },
    ["Combine stacks"] = { "Stapel zusammenfassen", "Regrouper les piles", "Combinar montones", "Объединять стопки", "合并堆叠", "合併堆疊" },
    ["Combine identical item counts. Clicking acts on the first stack."] = { "Fasst gleiche Gegenstände zusammen. Ein Klick wirkt auf den ersten Stapel.", "Additionne les objets identiques. Le clic agit sur la première pile.", "Suma los objetos idénticos. El clic actúa sobre el primer montón.", "Складывает одинаковые предметы. Щелчок действует на первую стопку.", "合并相同物品的数量。点击时作用于第一组。", "合併相同物品的數量。點擊時作用於第一組。" },
    ["Purpose labels"] = { "Verwendungs-Hinweise", "Étiquettes d'usage", "Etiquetas de uso", "Метки назначения", "用途标签", "用途標籤" },
    ["Equipment levels"] = { "Gegenstandsstufe", "Niveau d'objet", "Nivel de objeto", "Уровень предмета", "装备等级", "裝備等級" },
    ["Individual free slots"] = { "Freie Plätze einzeln", "Places libres individuelles", "Huecos libres individuales", "Свободные ячейки по одной", "逐个显示空位", "逐格顯示空位" },
    ["New item category"] = { "Kategorie für neue Gegenstände", "Catégorie des nouveaux objets", "Categoría de objetos nuevos", "Категория новых предметов", "新物品分类", "新物品分類" },
    ["View"] = { "Ansicht", "Affichage", "Vista", "Вид", "显示方式", "顯示方式" },
    ["Item sorting"] = { "Gegenstände sortieren", "Tri des objets", "Orden de objetos", "Сортировка предметов", "物品排序", "物品排序" },
    ["Category sorting"] = { "Kategorien sortieren", "Tri des catégories", "Orden de categorías", "Сортировка категорий", "分类排序", "分類排序" },
    ["Items per row (total)"] = { "Plätze pro Zeile (gesamt)", "Cases par ligne (total)", "Huecos por fila (total)", "Ячеек в ряду (всего)", "每行格数（总计）", "每行格數（總計）" },
    ["Category columns"] = { "Kategoriespalten", "Colonnes de catégories", "Columnas de categorías", "Колонок категорий", "分类列数", "分類欄數" },
    ["Icon size"] = { "Symbolgröße", "Taille des icônes", "Tamaño de iconos", "Размер значков", "图标大小", "圖示大小" },
    ["Window scale"] = { "Fenstergröße", "Taille de la fenêtre", "Tamaño de ventana", "Масштаб окна", "窗口大小", "視窗大小" },
    ["Opacity"] = { "Deckkraft", "Opacité", "Opacidad", "Непрозрачность", "不透明度", "不透明度" },
    ["Restore categories"] = { "Kategorien wiederherstellen", "Restaurer les catégories", "Restaurar categorías", "Вернуть категории", "恢复分类", "還原分類" },
    ["Reset position"] = { "Position zurücksetzen", "Réinitialiser la position", "Restablecer posición", "Сбросить позицию", "重置位置", "重設位置" },
    ["Category name"] = { "Kategoriename", "Nom de catégorie", "Nombre de categoría", "Имя категории", "分类名称", "分類名稱" },
    ["Search expression"] = { "Suchausdruck", "Expression de recherche", "Expresión de búsqueda", "Поисковый запрос", "搜索表达式", "搜尋運算式" },
    ["Leave the query empty to assign items by dragging."] = { "Ohne Suchausdruck ordnest du Gegenstände per Ziehen zu.", "Sans expression, attribuez les objets par glisser-déposer.", "Sin expresión, asigna objetos arrastrándolos.", "Без запроса предметы добавляются перетаскиванием.", "表达式留空时，拖放物品即可指定。", "運算式留空時，拖放物品即可指定。" },
    -- search errors
    ["512 characters maximum"] = { "Höchstens 512 Zeichen", "512 caractères au maximum", "Máximo 512 caracteres", "Не больше 512 символов", "最多 512 个字符", "最多 512 個字元" },
    ["too many terms"] = { "zu viele Begriffe", "trop de termes", "demasiados términos", "слишком много условий", "条件过多", "條件過多" },
    ["unclosed quote"] = { "Anführungszeichen nicht geschlossen", "guillemet non fermé", "comilla sin cerrar", "незакрытая кавычка", "引号未闭合", "引號未閉合" },
    ["text fields use = or !="] = { "Textfelder nutzen = oder !=", "les champs texte utilisent = ou !=", "los campos de texto usan = o !=", "для текста используйте = или !=", "文本字段请用 = 或 !=", "文字欄位請用 = 或 !=" },
    ["invalid operator"] = { "ungültiger Operator", "opérateur invalide", "operador no válido", "неверный оператор", "无效的运算符", "無效的運算子" },
    ["unknown field"] = { "unbekanntes Feld", "champ inconnu", "campo desconocido", "неизвестное поле", "未知字段", "未知欄位" },
    ["invalid number or rarity"] = { "ungültige Zahl oder Qualität", "nombre ou qualité invalide", "número o calidad no válidos", "неверное число или качество", "无效的数字或品质", "無效的數字或品質" },
    ["expression too deep"] = { "Ausdruck zu tief verschachtelt", "expression trop imbriquée", "expresión demasiado anidada", "слишком глубокая вложенность", "表达式嵌套过深", "運算式巢狀過深" },
    ["missing )"] = { ") fehlt", ") manquante", "falta )", "не хватает )", "缺少 )", "缺少 )" },
    ["missing search term"] = { "Suchbegriff fehlt", "terme de recherche manquant", "falta un término", "не хватает условия", "缺少搜索条件", "缺少搜尋條件" },
    ["missing field value"] = { "Feldwert fehlt", "valeur de champ manquante", "falta el valor del campo", "не указано значение поля", "缺少字段值", "缺少欄位值" },
    ["unexpected"] = { "unerwartet", "inattendu", "inesperado", "неожиданно", "意外的", "意外的" },
}
local KO = {
    ["512 characters maximum"] = "최대 512자까지 입력할 수 있습니다", ["too many terms"] = "조건이 너무 많습니다",
    ["unclosed quote"] = "따옴표가 닫히지 않았습니다", ["text fields use = or !="] = "글자 항목은 = 또는 != 를 사용합니다",
    ["invalid operator"] = "비교 기호가 올바르지 않습니다", ["unknown field"] = "알 수 없는 항목",
    ["invalid number or rarity"] = "숫자나 등급이 올바르지 않습니다", ["expression too deep"] = "괄호가 너무 깊습니다",
    ["missing )"] = ") 가 빠졌습니다", ["missing search term"] = "검색 조건이 빠졌습니다",
    ["missing field value"] = "항목 값이 빠졌습니다", ["unexpected"] = "예상하지 못한 글자",
}
-- Korean and English come from the caller; other languages from the table above.
function ns.Lang(ko, en)
    local i = langIndex()
    if i == 1 then return ko end
    if i == 2 then return en end
    local row = byEnglish[en]
    return row and row[i - 2] or en
end
-- Search errors are produced in English ("unknown field: foo"); show them in the chosen language.
function ns.TranslateError(err)
    if type(err) ~= "string" then return err end
    local base, rest = err:match("^(.-): (.*)$")
    base = base or err
    local i = langIndex()
    local text
    if i == 1 then text = KO[base]
    elseif i > 2 and byEnglish[base] then text = byEnglish[base][i - 2] end
    text = text or base
    return rest and (text .. ": " .. rest) or text
end
