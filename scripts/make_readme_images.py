#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Bags (docs/images/ui_*.png, settings_*.png).

The windows are rebuilt from the sizes, positions, colours and texts in UI/Window.lua,
UI/Widgets.lua and UI/Options.lua (game pixels x SCALE). Item art is simplified.
usage: python3 scripts/make_readme_images.py .   (needs: pip install playwright)
"""
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

SCALE = 1.36
ACCENT = "#f0b86b"          # UI.Theme.accent .94 .72 .42
BG = "rgba(18,24,31,.97)"   # UI.Theme.bg
PANEL = "#1d2831"           # UI.Theme.panel
INPUT = "#0c1116"
BORDER = "#344c5b"
TEXT = "#edf4f7"
MUTED = "#a7b9c5"
QUALITY = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee"}
CALL = "#f0b86b"

T = {
    "ko": {
        "subtitle": "가방·은행을 분류별로 보고 부캐 보관함과 경매장 시세를 확인합니다.",
        "head": "분류별 통합 가방, 아이템 용도 표시, 부캐 가방·은행 보기, 경매장 시세",
        "bags": "가방", "bank": "은행", "prices": "시세", "settings": "설정",
        "char": "가방지기 - 포에버", "status": "가방 · 10-21 20:40", "allGrid": "표시 · 전체",
        "groups": {"equipment": "장비", "consumable": "소모품", "materials": "재료", "quest": "퀘스트",
                   "recipe": "제조법", "junk": "잡동사니"},
        "free": "빈 칸: 13 (일반 13) · 열쇠고리 29", "new": "새 아이템 ✓", "search": "",
        "items": {
            "harness": "싸움꾼의 갑옷", "boots": "거친 가죽 장화", "shield": "단단한 버클러",
            "potion": "하급 치유 물약", "ribs": "구운 멧돼지 갈비", "hearth": "귀환석",
            "linen": "리넨 옷감", "peace": "평온초", "copper": "구리 광석", "leather": "얇은 가죽", "dust": "이상한 가루",
            "docs": "맥브라이드 보안관의 문서", "recipe": "제조법: 하급 치유 물약", "watch": "작은 회중시계",
        },
        "tags": {"boe": "비귀속", "q": "퀘", "book": "책", "tl": "재봉…", "al": "연금…", "mi": "채광…", "lw": "가죽…", "en": "마부…"},
        "tip": ["리넨 옷감", "재료: 기공, 대장, 응급, 재봉", ("시세 / 1", "45s 20c"), "저장된 정보: 10-21 20:35",
                ("가방지기", "가방 27 · 은행 20"), ("은행지기", "가방 0 · 은행 60")],
        "notes": [
            ("탭", "가방 · 은행 · 시세 화면 전환. 시세 탭에서 전체 시세 수집·가방 아이템 조회."),
            ("검색", "이름·종류·용도로 찾기. ilvl>=50, rarity=rare, AND·OR·NOT, 괄호."),
            ("캐릭터 선택", "같은 서버 다른 캐릭터의 가방·은행을 보기 전용으로 엽니다."),
            ("분류 목록", "누르면 그 분류만 표시, 오른쪽 클릭은 분류 메뉴, 아이템을 끌어 놓으면 사용자 분류에 넣기."),
            ("분류 머리글", "누르면 접기/펼치기. 오른쪽 클릭: 고정·숨김·끄기, 은행·우편·거래·상인으로 옮기기. ≈ 시세 합계."),
            ("아이템", "용도 표시(비귀속·퀘·책·전문 기술), 장비 레벨, 새 아이템 초록 점. 오른쪽 클릭으로 사용(전투 중 포함)."),
            ("가방 아이콘·빈 칸", "열쇠고리 → 가방 4·3·2·1 → 배낭. 빈 칸 수, 아이템을 끌어 놓으면 그 가방에 넣기. 골드와 빈 칸 합계."),
            ("툴팁", "쓰이는 전문 기술, 경매장 단가와 수집 시각, 캐릭터별 가방·은행 보유 수."),
        ],
        # settings
        "sTitle": "설정창", "sHead": "/ezbags settings · 언어, 표시 항목, 보기·정렬, 크기, 분류 관리",
        "sec": ["일반", "아이콘 표시", "보기", "분류·창"],
        "language": "언어", "langValue": "자동 (게임 언어)",
        "checks1": ["기본 가방 대체", "묶음 합계 표시"], "checks2": ["아이템 용도", "장비 레벨", "빈 칸 개별 표시", "새 아이템 분류"],
        "choices": [("보기", "분류"), ("아이템 정렬", "이름"), ("분류 정렬", "이름")],
        "numbers": [("줄당 칸 수 (전체)", "12 (6+6)"), ("분류 열 수", "2"), ("아이콘 크기", "30"), ("창 크기", "1"), ("불투명도", "0.96")],
        "restore": "숨김·꺼진 분류 복원", "reset": "창 위치 초기화", "catName": "분류 이름", "catQuery": "검색식",
        "catNameValue": "물약", "catQueryValue": "물약 OR 비약",
        "hint": "검색식을 비우면 아이템을 끌어 놓아 지정합니다.",
        "sNotes": [
            ("일반", "언어(자동 + 8개 언어, 목록에서 선택), 기본 가방 대체(B 키·가방 버튼), 같은 아이템 묶음 합계."),
            ("아이콘 표시", "아이템 용도, 장비 레벨, 빈 칸 개별 표시, 새 아이템을 별도 분류로."),
            ("보기·정렬", "분류 · 전체 · 목록 보기, 아이템 정렬(이름·등급), 분류 정렬(이름·크기)."),
            ("크기", "줄당 칸 수 6~20, 분류 열 1~3, 아이콘 28~56, 창 크기 0.65~1.4, 불투명도 0.4~1."),
            ("분류·창", "숨긴·끈 분류 복원, 창 위치 초기화, 이름 + 검색식으로 사용자 분류 만들기."),
        ],
        "note": "애드온 코드의 창 크기·좌표·색상·문구로 재현한 예시 화면입니다. 아이템 그림은 단순화했습니다.",
    },
    "en": {
        "subtitle": "Bags and bank by category, alt storage and auction prices.",
        "head": "Categorized bags, item purpose labels, alt bags and banks, auction prices",
        "bags": "Bags", "bank": "Bank", "prices": "Prices", "settings": "Settings",
        "char": "Bagkeeper - Forever", "status": "Bags · 10-21 20:40", "allGrid": "Show · Grid",
        "groups": {"equipment": "Equipment", "consumable": "Consumables", "materials": "Materials", "quest": "Quest",
                   "recipe": "Recipes", "junk": "Junk"},
        "free": "Free slots: 13 (General 13) · Keyring 29", "new": "New ✓", "search": "",
        "items": {
            "harness": "Brawler's Harness", "boots": "Rough Leather Boots", "shield": "Sturdy Buckler",
            "potion": "Minor Healing Potion", "ribs": "Roasted Boar Ribs", "hearth": "Hearthstone",
            "linen": "Linen Cloth", "peace": "Peacebloom", "copper": "Copper Ore", "leather": "Light Leather", "dust": "Strange Dust",
            "docs": "Marshal McBride's Documents", "recipe": "Recipe: Minor Healing Potion", "watch": "Small Pocket Watch",
        },
        "tags": {"boe": "BoE", "q": "Q", "book": "Recipe", "tl": "Tailo…", "al": "Alch…", "mi": "Mini…", "lw": "Leat…", "en": "Ench…"},
        "tip": ["Linen Cloth", "Materials: Engineering, Smithing, First Aid, Tailoring", ("Prices / 1", "45s 20c"),
                "Cached: 10-21 20:35", ("Bagkeeper", "Bags 27 · Bank 20"), ("Bankkeeper", "Bags 0 · Bank 60")],
        "notes": [
            ("Tabs", "Switch Bags · Bank · Prices. The Prices tab runs a full scan or scans your bag items."),
            ("Search", "Name, type or purpose. ilvl>=50, rarity=rare, AND·OR·NOT, brackets."),
            ("Character", "Open another character's bags and bank on the realm, read only."),
            ("Category list", "Click to show only that category, right-click for its menu, drop an item into a custom category."),
            ("Category header", "Click to collapse. Right-click: pin · hide · disable, move to bank · mail · trade · vendor. ≈ price total."),
            ("Items", "Purpose labels (BoE · Q · Recipe · professions), item level, green dot for new items. Right-click uses, also in combat."),
            ("Bag icons · free slots", "Keyring → bags 4·3·2·1 → backpack with free slots; drop an item to put it in that bag. Gold and free slot totals."),
            ("Tooltip", "Professions that use the item, auction unit price and age, per-character bag and bank counts."),
        ],
        "sTitle": "Settings", "sHead": "/ezbags settings · language, icon labels, view and sorting, sizes, categories",
        "sec": ["General", "Item icons", "View", "Categories & window"],
        "language": "Language", "langValue": "Auto (game language)",
        "checks1": ["Replace default bags", "Combine stacks"], "checks2": ["Purpose labels", "Equipment levels", "Individual free slots", "New item category"],
        "choices": [("View", "Sections"), ("Item sorting", "Name"), ("Category sorting", "Name")],
        "numbers": [("Items per row (total)", "12 (6+6)"), ("Category columns", "2"), ("Icon size", "30"), ("Window scale", "1"), ("Opacity", "0.96")],
        "restore": "Restore categories", "reset": "Reset position", "catName": "Category name", "catQuery": "Search expression",
        "catNameValue": "Potions", "catQueryValue": "potion OR elixir",
        "hint": "Leave the query empty to assign items by dragging.",
        "sNotes": [
            ("General", "Language (automatic + 8 languages, picked from a list), replace default bags (B key, bag buttons), combine stacks."),
            ("Item icons", "Purpose labels, item levels, individual free slots, a separate category for new items."),
            ("View · sorting", "Sections · Grid · List, item sorting (name, quality), category sorting (name, size)."),
            ("Sizes", "Items per row 6–20, category columns 1–3, icons 28–56, window scale 0.65–1.4, opacity 0.4–1."),
            ("Categories & window", "Restore hidden/disabled categories, reset position, create a custom category from a name and search."),
        ],
        "note": "Mock-ups rebuilt from the window sizes, coordinates, colours and strings in the addon code. Item art is simplified.",
    },
}

# icon art: (base colour, accent colour, shape)
ART = {
    "harness": ("#5b3b22", "#a0703f", "chest"), "boots": ("#4a3524", "#8a6440", "boot"), "shield": ("#3a3f48", "#9aa6b5", "shield"),
    "potion": ("#3a1414", "#e04848", "potion"), "ribs": ("#4a2a18", "#c97b45", "meat"), "hearth": ("#2a2f38", "#7fa7c9", "stone"),
    "linen": ("#4b4434", "#d8cfb2", "cloth"), "peace": ("#20381f", "#8fd16a", "leaf"), "copper": ("#3b2a22", "#c47d4e", "ore"),
    "leather": ("#3d2a1b", "#b88552", "hide"), "dust": ("#2c2440", "#b08ae0", "dust"), "docs": ("#3d3624", "#e2cf91", "scroll"),
    "recipe": ("#2f3a46", "#e2cf91", "scroll"), "watch": ("#333333", "#b5b5b5", "watch"),
}


def art_svg(kind, size):
    base, acc, shape = ART[kind]
    shapes = {
        "chest": f'<path d="M30 22 L42 18 L50 24 L58 18 L70 22 L74 40 L66 42 L66 80 L34 80 L34 42 L26 40 Z" fill="{acc}"/>',
        "boot": f'<path d="M36 18 H58 V60 L78 66 V80 H30 Z" fill="{acc}"/>',
        "shield": f'<path d="M50 14 L80 24 C80 56 68 74 50 86 C32 74 20 56 20 24 Z" fill="{acc}"/>',
        "potion": f'<rect x="42" y="14" width="16" height="16" fill="#ccc"/><circle cx="50" cy="58" r="26" fill="{acc}"/>',
        "meat": f'<ellipse cx="52" cy="52" rx="28" ry="22" fill="{acc}"/><rect x="18" y="60" width="26" height="8" fill="#eee"/>',
        "stone": f'<ellipse cx="50" cy="52" rx="30" ry="34" fill="{acc}"/><circle cx="50" cy="52" r="10" fill="#e0f0ff"/>',
        "cloth": f'<rect x="20" y="26" width="60" height="48" rx="6" fill="{acc}"/><path d="M20 40 H80 M20 54 H80" stroke="{base}" stroke-width="5"/>',
        "leaf": f'<path d="M50 84 C20 60 22 30 50 14 C78 30 80 60 50 84 Z" fill="{acc}"/>',
        "ore": f'<path d="M22 64 L34 30 L60 22 L80 46 L70 76 L36 80 Z" fill="{acc}"/>',
        "hide": f'<path d="M24 24 L76 24 L70 50 L78 78 L22 78 L30 50 Z" fill="{acc}"/>',
        "dust": f'<circle cx="38" cy="44" r="14" fill="{acc}"/><circle cx="62" cy="58" r="16" fill="{acc}"/><circle cx="56" cy="30" r="8" fill="{acc}"/>',
        "scroll": f'<rect x="24" y="20" width="52" height="60" rx="5" fill="{acc}"/><path d="M34 36 H66 M34 48 H66 M34 60 H58" stroke="{base}" stroke-width="5"/>',
        "watch": f'<circle cx="50" cy="54" r="28" fill="{acc}"/><circle cx="50" cy="54" r="20" fill="#eee"/><path d="M50 54 V40 M50 54 H60" stroke="#333" stroke-width="4"/>',
    }
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 100 100"><rect width="100" height="100" fill="{base}"/>'
            f'{shapes[shape]}<rect width="100" height="100" fill="url(#shade)"/></svg>')


def px(v):
    return f"{v * SCALE:.1f}px"


CSS = f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ width: 1600px; background: radial-gradient(ellipse at 30% 0%, #1d2a33 0%, #10171d 60%, #0b1014 100%);
  font-family: 'Noto Sans CJK KR', 'Noto Sans', sans-serif; color: {TEXT}; }}
.page {{ position: relative; padding: 34px 50px 40px; }}
h1 {{ color: {ACCENT}; font-size: 40px; font-weight: 700; letter-spacing: .3px; display: flex; align-items: center; gap: 14px; }}
h1 .badge {{ font-size: 15px; background: {ACCENT}; color: #1a1206; padding: 2px 9px; border-radius: 5px; }}
.lead {{ color: #d5dde2; font-size: 19px; margin-top: 6px; }}
.abs {{ position: absolute; }}
.win {{ position: absolute; background: {BG}; border: 1px solid {BORDER}; }}
.hdr {{ position: absolute; left: 1px; right: 1px; top: 1px; height: {px(56)}; background: {PANEL}; }}
.hline {{ position: absolute; left: 1px; right: 1px; top: {px(55)}; height: {px(2)}; background: {ACCENT}; }}
.title {{ position: absolute; left: {px(48)}; top: {px(9)}; font-size: {px(15)}; color: {ACCENT}; }}
.sub {{ position: absolute; left: {px(48)}; top: {px(31)}; font-size: {px(10)}; color: {MUTED}; white-space: nowrap; }}
.btn {{ position: absolute; background: {PANEL}; border: 1px solid {BORDER}; color: {MUTED}; font-size: {px(10.5)};
  display: flex; align-items: center; justify-content: center; white-space: nowrap; overflow: hidden; }}
.btn.left {{ justify-content: flex-start; padding-left: {px(7)}; }}
.btn.sel {{ background: #4f3922; border-color: {ACCENT}; color: #ffe0a6; }}
.btn.sel::after {{ content: ''; position: absolute; left: 1px; right: 1px; bottom: 1px; height: {px(3)}; background: {ACCENT}; }}
.btn .ic {{ width: {px(16)}; height: {px(16)}; border-radius: 2px; margin-right: {px(6)}; flex: none; }}
.close {{ position: absolute; width: {px(24)}; height: {px(24)}; background: {BG}; border: 1px solid {BORDER}; color: {MUTED};
  font-size: {px(12)}; display: flex; align-items: center; justify-content: center; }}
.edit {{ position: absolute; background: {INPUT}; border: 1px solid {BORDER}; color: {TEXT}; font-size: {px(10.5)};
  display: flex; align-items: center; padding-left: {px(8)}; }}
.lbl {{ position: absolute; font-size: {px(10.5)}; color: {TEXT}; white-space: nowrap; }}
.muted {{ color: {MUTED}; }}
.item {{ position: absolute; width: {px(30)}; height: {px(30)}; border: 1px solid; background: #141c24; }}
.item svg {{ position: absolute; left: {px(2)}; top: {px(2)}; }}
.item .tag {{ position: absolute; left: {px(3)}; top: {px(2)}; font-size: {px(8.4)}; color: #4dffa6; text-shadow: 0 0 2px #000, 1px 1px 1px #000; white-space: nowrap; max-width: {px(26)}; overflow: hidden; }}
.item .cnt {{ position: absolute; right: {px(3)}; bottom: {px(2)}; font-size: {px(10)}; color: #fff; text-shadow: 1px 1px 1px #000, 0 0 2px #000; }}
.item .lvl {{ position: absolute; left: {px(3)}; bottom: {px(2)}; font-size: {px(8.4)}; text-shadow: 1px 1px 1px #000, 0 0 2px #000; }}
.item .dot {{ position: absolute; right: {px(2)}; top: {px(1)}; font-size: {px(8)}; color: #59ffa6; }}
.call {{ position: absolute; width: 30px; height: 30px; border-radius: 50%; background: {CALL}; color: #1d1405; font-weight: 700;
  font-size: 16px; display: flex; align-items: center; justify-content: center; border: 2px solid #1a1206; box-shadow: 0 0 0 2px {CALL}55; }}
.notes {{ position: absolute; }}
.note {{ display: flex; gap: 12px; margin-bottom: 11px; font-size: 16.5px; line-height: 1.5; color: #dfe6ea; }}
.note .n {{ flex: none; width: 28px; height: 28px; border-radius: 50%; background: {CALL}; color: #1d1405; font-weight: 700;
  font-size: 15px; display: flex; align-items: center; justify-content: center; margin-top: 1px; }}
.note b {{ color: #fff; }}
.foot {{ color: #7d8d98; font-size: 13.5px; }}
.tip {{ position: absolute; background: rgba(4,8,14,.94); border: 2px solid #5d6d7a; border-radius: 4px; padding: 10px 12px; font-size: 14px; line-height: 1.55; }}
.tip .row {{ display: flex; justify-content: space-between; gap: 22px; }}
.money i {{ display: inline-block; width: 11px; height: 11px; border-radius: 50%; margin: 0 4px 0 2px; vertical-align: -1px; }}
.check {{ position: absolute; width: {px(18)}; height: {px(18)}; border: 1px solid #6d6a5d; background: #191919; border-radius: 2px; }}
.check::after {{ content: '✔'; position: absolute; left: {px(1)}; top: {px(-5)}; font-size: {px(18)}; color: #ffd200; text-shadow: 0 0 1px #000; }}
.check.off::after {{ content: ''; }}
.secline {{ position: absolute; height: 1px; background: rgba(52,76,91,.85); }}
"""

SHADE = ('<svg width="0" height="0" style="position:absolute"><defs><linearGradient id="shade" x1="0" y1="0" x2="1" y2="1">'
         '<stop offset="0" stop-color="#fff" stop-opacity=".18"/><stop offset=".55" stop-color="#000" stop-opacity="0"/>'
         '<stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient></defs></svg>')

GROUP_ICON = {"equipment": "#a0703f", "consumable": "#c94a4a", "materials": "#d8cfb2", "quest": "#8a6f3c",
              "recipe": "#e2cf91", "junk": "#9d9d9d", "all": "#6d8798"}


def money(g, s, c):
    out = ""
    if g:
        out += f'{g}<i style="background:#e8c34a"></i> '
    out += f'{s}<i style="background:#c7cfd6"></i> {c}<i style="background:#c27a45"></i>'
    return f'<span class="money">{out}</span>'


def ui_page(lang, icon_uri):
    t = T[lang]
    I, TG = t["items"], t["tags"]
    W = 586
    ox, oy = 72, 160            # window position on the page (page px)
    parts = []

    def at(x, y):              # game px inside the window -> css
        return f"left:{px(x)};top:{px(y)};"

    # sections: (key, value>0, items[(art, quality, tag, lvl, count, new)])
    sections = [
        ("equipment", True, [("harness", 2, "boe", 12, 1, True), ("shield", 3, "boe", 18, 1, False), ("boots", 1, None, 9, 1, False)]),
        ("materials", True, [("linen", 1, "tl", None, 27, False), ("peace", 1, "al", None, 3, False), ("copper", 1, "mi", None, 10, False),
                             ("leather", 1, "lw", None, 6, False), ("dust", 1, "en", None, 4, False)]),
        ("consumable", True, [("potion", 1, None, None, 5, True), ("ribs", 1, None, None, 8, False), ("hearth", 1, None, None, 1, False)]),
        ("quest", False, [("docs", 1, "q", None, 1, False)]),
        ("recipe", True, [("recipe", 2, "book", None, 1, False)]),
        ("junk", True, [("watch", 0, None, None, 1, False)]),
    ]
    values = {"equipment": (0, 95, 40), "materials": (1, 62, 30), "consumable": (0, 18, 75), "recipe": (0, 85, 0), "junk": (0, 25, 0)}
    counts = {k: sum(i[4] for i in items) for k, _, items in sections}
    # sort by name like the addon (name order of the shown language)
    order = sorted(sections, key=lambda s: t["groups"][s[0]])
    lanes = [0, 0]
    offsets, laneW = [0, 210], 200
    content = []
    for key, has_value, items in order:
        lane = 0 if lanes[0] <= lanes[1] else 1
        x, y = offsets[lane], lanes[lane]
        compact = has_value
        hh = 40 if compact else 23
        name = f'− {t["groups"][key]} · {counts[key]}'
        content.append(f'<div class="btn left" style="{at(148 + x, 159 + y)}width:{px(laneW)};height:{px(hh)};align-items:flex-start;padding-top:{px(4 if compact else 0)};{"" if compact else "align-items:center;"}">'
                       f'<span class="ic" style="background:{GROUP_ICON[key]}"></span><span style="color:{MUTED}">{name}</span></div>')
        if compact:
            g, s, c = values[key]
            content.append(f'<div class="lbl" style="{at(148 + x + 29, 159 + y + 22)}font-size:{px(8.6)};color:{ACCENT}">≈ {money(g, s, c)}</div>')
        y += hh + 5
        for i, (art, q, tag, lvl, cnt, new) in enumerate(items):
            ix, iy = 148 + x + (i % 6) * 34, 159 + y + (i // 6) * 34
            col = QUALITY[q] if q != 1 else "#5c6b75"
            inner = art_svg(art, round(26 * SCALE))
            inner += f'<span class="tag">{TG[tag]}</span>' if tag else ""
            inner += f'<span class="cnt">{cnt}</span>' if cnt > 1 else ""
            inner += f'<span class="lvl" style="color:{QUALITY[q]}">{lvl}</span>' if lvl else ""
            inner += '<span class="dot">●</span>' if new else ""
            content.append(f'<div class="item" style="{at(ix, iy)}border-color:{col}">{inner}</div>')
        y += ((len(items) + 5) // 6) * 34
        lanes[lane] = y + 12
    h = max(lanes)
    side = [("all", t["allGrid"], None)] + [(k, t["groups"][k], counts[k]) for k, _, _ in order]
    side_h = len(side) * 27 + 12
    H = max(399, min(669, max(h + 270, side_h + 265)))

    parts.append(f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">')
    parts.append('<div class="hdr"></div><div class="hline"></div>')
    parts.append(f'<img class="abs" src="{icon_uri}" style="{at(14, 14)}width:{px(28)};height:{px(28)}">')
    parts.append(f'<div class="title">EzWoW - Bags</div><div class="sub" style="max-width:{px(W - 200)};overflow:hidden">{t["subtitle"]}</div>')
    parts.append(f'<div class="close" style="{at(W - 14 - 24, 16)}">X</div>')
    parts.append(f'<div class="btn" style="{at(W - 14 - 24 - 6 - 80, 16)}width:{px(80)};height:{px(24)};"><span class="ic" style="background:#7d8a93;border-radius:50%"></span>{t["settings"]}</div>')
    for i, (key, label) in enumerate([("bags", t["bags"]), ("bank", t["bank"]), ("prices", t["prices"])]):
        sel = i == 0
        colr = {"bags": "#c8955a", "bank": "#3f6fb0", "prices": "#e0b84a"}[key]
        parts.append(f'<div class="btn left {"sel" if sel else ""}" style="{at(16 + i * 111, 65)}width:{px(104)};height:{px(28)}">'
                     f'<span class="ic" style="background:{colr}"></span>{"✓ " if sel else ""}{label}</div>')
    parts.append(f'<div class="edit" style="{at(W - 16 - (W - 374), 66)}width:{px(W - 374)};height:{px(25)}"></div>')
    parts.append(f'<div class="btn left" style="{at(16, 101)}width:{px(W - 32)};height:{px(24)}">'
                 f'<span class="ic" style="background:#8b6a3b"></span><span class="ic" style="background:#b98a6a;border-radius:50%"></span>'
                 f'<span style="color:{TEXT}">{t["char"]} ▾</span></div>')
    parts.append(f'<div class="lbl" style="{at(16, 137)}">{t["status"]}</div>')
    parts.append(f'<div class="abs" style="{at(12, 158)}width:{px(130)};height:{px(H - 258)};background:#121c24;border:1px solid {BORDER}"></div>')
    for i, (key, label, cnt) in enumerate(side):
        sel = i == 0
        parts.append(f'<div class="btn left {"sel" if sel else ""}" style="{at(18, 164 + i * 27)}width:{px(118)};height:{px(24)}">'
                     f'<span class="ic" style="background:{GROUP_ICON[key]}"></span>{label}{("&nbsp;&nbsp;" + str(cnt)) if cnt else ""}</div>')
    parts.extend(content)
    parts.append(f'<div class="lbl" style="{at(16, H - 73 - 14)}">{money(15, 42, 7)}&nbsp;&nbsp;&nbsp; {t["free"]}</div>')
    bag_cols = ["#8a8a8a", "#6b4b2b", "#6b4b2b", "#7a5530", "#7a5530", "#a8743d"]
    frees = ["", "0", "2", "3", "4", "(13)"]
    for i in range(6):
        inner = '<svg width="100%" height="100%" viewBox="0 0 100 100"><rect width="100" height="100" fill="{0}"/>'.format(bag_cols[i])
        inner += ('<circle cx="40" cy="45" r="16" fill="#ddd"/><rect x="50" y="40" width="34" height="10" fill="#ddd"/></svg>' if i == 0
                  else '<rect x="22" y="34" width="56" height="48" rx="8" fill="#d9a45c"/><path d="M38 34 C38 18 62 18 62 34" stroke="#d9a45c" stroke-width="7" fill="none"/></svg>')
        parts.append(f'<div class="abs" style="{at(16 + i * 41, H - 10 - 36)}width:{px(36)};height:{px(36)};border:1px solid {ACCENT};background:{PANEL};padding:{px(3)}">{inner}'
                     f'<span class="abs" style="right:{px(4)};bottom:{px(2)};font-size:{px(10)};color:#fff;text-shadow:1px 1px 1px #000">{frees[i]}</span></div>')
    parts.append(f'<div class="btn" style="{at(W - 16 - 130, H - 10 - 24)}width:{px(130)};height:{px(24)}"><span class="ic" style="background:#6b8f5a"></span>{t["new"]}</div>')
    parts.append('</div>')

    # tooltip next to the window
    tip = t["tip"]
    tx, ty = ox + W * SCALE + 40, oy + 300
    rows = [f'<div style="color:#fff;font-size:16px">{tip[0]}</div>', f'<div style="color:{ACCENT}">{tip[1]}</div>',
            f'<div class="row"><span style="color:{ACCENT}">{tip[2][0]}</span><span style="color:#ffd166">{money(0, 45, 20)}</span></div>',
            f'<div style="color:{MUTED}">{tip[3]}</div>',
            f'<div class="row"><span style="color:{MUTED}">{tip[4][0]}</span><span>{tip[4][1]}</span></div>',
            f'<div class="row"><span style="color:{MUTED}">{tip[5][0]}</span><span>{tip[5][1]}</span></div>']
    parts.append(f'<div class="tip" style="left:{tx}px;top:{ty}px;width:440px">{"".join(rows)}</div>')

    # callouts (page px)
    def cx(x): return ox + x * SCALE
    def cy(y): return oy + y * SCALE
    calls = [(cx(-14), cy(64)), (cx(W - 4), cy(68)), (cx(W - 4), cy(102)), (cx(-14), cy(190)),
             (cx(148 + 200 - 2), cy(150)), (cx(148 + 34 * 3 - 4), cy(206)), (cx(-14), cy(H - 50)), (tx - 16, ty - 16)]
    for i, (x, y) in enumerate(calls, 1):
        parts.append(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>')

    notes_top = oy + H * SCALE + 36
    left = t["notes"][:4]
    right = t["notes"][4:]
    def note_html(start, lst):
        return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{a}</b> — {b}</div></div>' for i, (a, b) in enumerate(lst))
    parts.append(f'<div class="notes" style="left:50px;top:{notes_top:.0f}px;width:720px">{note_html(1, left)}</div>')
    parts.append(f'<div class="notes" style="left:820px;top:{notes_top:.0f}px;width:730px">{note_html(5, right)}</div>')
    page_h = notes_top + 4 * 62 + 60
    parts.append(f'<div class="abs foot" style="left:50px;top:{page_h - 44:.0f}px">{t["note"]}</div>')
    body = (f'<div class="page" style="height:{page_h:.0f}px"><h1>EzWoW - Bags</h1><div class="lead">{t["head"]}</div></div>'
            + "".join(parts))
    return body, page_h


def settings_page(lang, icon_uri):
    t = T[lang]
    W = 420
    ox, oy = 72, 160
    p = []

    def at(x, y): return f"left:{px(x)};top:{px(y)};"
    y = 70
    secs = []
    def section(name):
        nonlocal y
        p.append(f'<div class="lbl" style="{at(20, y)}font-size:{px(12)};color:{ACCENT}">{name}</div>')
        p.append(f'<div class="secline" style="{at(20, y + 18)}width:{px(W - 40)}"></div>')
        secs.append(y)
        y += 26
    section(t["sec"][0])
    p.append(f'<div class="lbl" style="{at(20, y + 6)}">{t["language"]}</div>')
    p.append(f'<div class="btn" style="{at(218, y)}width:{px(182)};height:{px(24)}">{t["langValue"]}  ▾</div>')
    y += 30
    def checks(lst, off=()):
        nonlocal y
        for i, name in enumerate(lst):
            x = 18 if i % 2 == 0 else 216
            p.append(f'<div class="check{" off" if i in off else ""}" style="{at(x + 3, y + 3)}"></div><div class="lbl" style="{at(x + 28, y + 5)}">{name}</div>')
            if i % 2 == 1 or i == len(lst) - 1:
                y += 26
        y += 8
    checks(t["checks1"])
    section(t["sec"][1])
    checks(t["checks2"], off=(2, 3))  # free slots / new item category are off by default
    section(t["sec"][2])
    for name, value in t["choices"]:
        p.append(f'<div class="lbl" style="{at(20, y + 6)}">{name}</div>')
        p.append(f'<div class="btn" style="{at(218, y)}width:{px(182)};height:{px(24)}">{value}  ▾</div>')
        y += 28
    y += 2
    for name, value in t["numbers"]:
        p.append(f'<div class="lbl" style="{at(20, y + 5)}">{name}</div>')
        p.append(f'<div class="btn" style="{at(218, y)}width:{px(22)};height:{px(20)}">-</div>')
        p.append(f'<div class="lbl" style="{at(244, y + 4)}width:{px(130)};text-align:center">{value}</div>')
        p.append(f'<div class="btn" style="{at(378, y)}width:{px(22)};height:{px(20)}">+</div>')
        y += 24
    y += 8
    section(t["sec"][3])
    p.append(f'<div class="btn" style="{at(20, y)}width:{px(186)};height:{px(24)}">{t["restore"]}</div>')
    p.append(f'<div class="btn" style="{at(214, y)}width:{px(186)};height:{px(24)}">{t["reset"]}</div>')
    y += 34
    p.append(f'<div class="lbl" style="{at(20, y)}">{t["catName"]}</div><div class="lbl" style="{at(146, y)}">{t["catQuery"]}</div>')
    y += 16
    p.append(f'<div class="edit" style="{at(20, y)}width:{px(120)};height:{px(25)}">{t["catNameValue"]}</div>')
    p.append(f'<div class="edit" style="{at(146, y)}width:{px(216)};height:{px(25)}">{t["catQueryValue"]}</div>')
    p.append(f'<div class="btn" style="{at(372, y)}width:{px(28)};height:{px(24)}">+</div>')
    y += 32
    p.append(f'<div class="lbl muted" style="{at(20, y)}">{t["hint"]}</div>')
    H = y + 40
    head = ['<div class="hdr"></div><div class="hline"></div>',
            f'<img class="abs" src="{icon_uri}" style="{at(14, 14)}width:{px(28)};height:{px(28)}">',
            f'<div class="title">EzWoW - Bags</div><div class="sub" style="max-width:{px(W - 70)};overflow:hidden">{t["settings"]} · {t["subtitle"]}</div>',
            f'<div class="close" style="{at(W - 14 - 24, 16)}">X</div>']
    win = f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">' + "".join(head + p) + '</div>'
    # callouts on the right edge of each section
    spans = [(secs[0], secs[1]), (secs[1], secs[2]), (secs[2], secs[2] + 26 + 3 * 28), (secs[2] + 26 + 3 * 28, secs[3]), (secs[3], H)]
    calls = "".join(f'<div class="call" style="left:{ox + W * SCALE + 18:.0f}px;top:{oy + (a + b) / 2 * SCALE - 15:.0f}px">{i}</div>'
                    for i, (a, b) in enumerate(spans, 1))
    notes = "".join(f'<div class="note"><span class="n">{i}</span><div><b>{a}</b> — {b}</div></div>' for i, (a, b) in enumerate(t["sNotes"], 1))
    page_h = max(oy + H * SCALE + 70, 700)
    body = (f'<div class="page" style="height:{page_h:.0f}px"><h1>EzWoW - Bags <span class="badge">{t["sTitle"]}</span></h1>'
            f'<div class="lead">{t["sHead"]}</div></div>' + win + calls
            + f'<div class="notes" style="left:{ox + W * SCALE + 80:.0f}px;top:{oy + 10}px;width:{1600 - ox - W * SCALE - 130:.0f}px">{notes}</div>'
            + f'<div class="abs foot" style="left:50px;top:{page_h - 44:.0f}px">{t["note"]}</div>')
    return body, page_h


def main(root: Path):
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    import base64
    icon_uri = "data:image/png;base64," + base64.b64encode((root / "Media" / "Icon.png").read_bytes()).decode()
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 1600, "height": 1000}, device_scale_factor=1)
        for lang in ("ko", "en"):
            for name, fn in (("ui", ui_page), ("settings", settings_page)):
                body, h = fn(lang, icon_uri)
                html = f'<html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{SHADE}{body}</body></html>'
                page.set_viewport_size({"width": 1600, "height": int(h)})
                page.set_content(html)
                page.wait_for_timeout(200)
                page.screenshot(path=str(out / f"{name}_{lang}.png"), full_page=False)
                print("wrote", out / f"{name}_{lang}.png", int(h))
        browser.close()


if __name__ == "__main__":
    main(Path(sys.argv[1]))
