#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Bags (docs/images/ui_*.png, settings_*.png).

The windows are rebuilt from the sizes, positions, colours and texts in UI/Window.lua,
UI/Widgets.lua, UI/PriceGraph.lua, UI/Options.lua, Modules/AuctionTrade.lua and
Modules/AuctionSellList.lua (game pixels x SCALE). Item art is simplified.
usage: python scripts/make_readme_images.py .
Renders with a local headless Chrome (set CHROME=<path> if it is not found); standard library only.
"""
import base64
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCALE = 1.36
ACCENT = "#f0b86b"          # UI.Theme.accent .94 .72 .42
BG = "rgba(18,24,31,.97)"   # UI.Theme.bg
PANEL = "#1d2831"           # UI.Theme.panel
INPUT = "#0c1116"
BORDER = "#344c5b"
TEXT = "#edf4f7"
MUTED = "#a7b9c5"
HINT = "#8398a6"
UP, DOWN = "#7ddc8a", "#e87c70"
SELBG = "#4f3922"           # selected / primary button .31 .225 .135
QUALITY = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee"}
CALL = "#f0b86b"

T = {
    "ko": {
        "subtitle": "가방·은행을 분류별로 보고 부캐 보관함과 경매장 시세를 확인합니다.",
        "head": "분류별 통합 가방, 아이템 용도·잠금 표시, 부캐 가방·은행, 경매장 시세·그래프·구매·판매 도우미",
        "bags": "가방", "bank": "은행", "prices": "시세", "settings": "설정", "sort": "정리",
        "char": "가방지기 바람결 - 포에버", "status": "가방 · 11-08 20:40", "allGrid": "표시 · 전체",
        "groups": {"equipment": "장비", "consumable": "소모품", "materials": "재료", "quest": "퀘스트",
                   "recipe": "제조법", "junk": "잡동사니"},
        "free": "빈 칸: 13 (일반 13) · 열쇠고리 29", "new": "새 아이템 ✓",
        "items": {
            "harness": "싸움꾼의 갑옷", "boots": "거친 가죽 장화", "shield": "단단한 버클러",
            "potion": "하급 치유 물약", "ribs": "구운 멧돼지 갈비", "hearth": "귀환석",
            "linen": "리넨 옷감", "peace": "평온초", "copper": "구리 광석", "leather": "얇은 가죽", "dust": "이상한 가루",
            "docs": "보안관의 서류", "recipe": "제조법: 하급 치유 물약", "watch": "작은 회중시계",
        },
        "tags": {"boe": "비귀속", "q": "퀘", "book": "책", "tl": "재봉", "al": "연금", "mi": "채광", "lw": "가죽", "en": "마부"},
        "tip": {"name": "리넨 옷감", "mat": "재료: 기공, 대장, 응급, 재봉", "price": "시세 / 1", "days": "(7일)",
                "cached": "저장된 정보: 11-08 20:35",
                "chars": [("가방지기 바람결", "가방 27 · 은행 20"), ("은행지기 돌담", "가방 0 · 은행 60")]},
        "secB": "시세 탭 · 경매장 구매 창",
        "pStatus": "포에버 · 저장된 정보 · 11-08 20:30",
        "classes": ["무기", "방어구", "가방", "소모품", "직업용품", "제조법", "투사체", "화살통", "보석", "퀘스트", "기타"],
        "graphTitle": "최근 30일 최저가", "scan": "전체 시세 수집", "bagScan": "가방 아이템 조회", "stop": "중지",
        "pFooter": "시세 · 5 · 포에버:Alliance", "pHint": "클릭: 그래프 · 오른쪽 클릭: 경매장에서 찾기",
        "buyTitle": "경매장 구매", "sellList": "판매 목록", "search": "검색", "back": "← 목록", "qty": "수량",
        "cheapest": "최저가부터 사기", "unit": "단가", "seller": "판매자", "own": "내 경매",
        "sellers": ["가방장수", None, "리넨장인", "천조각상점 +2", "실타래", "모험가가게", "가방장수 +1", "바늘방"],
        "estimate": "최저가부터 20개 · 예상 합계",
        "notes": [
            ("탭", "가방 · 은행 · 시세 화면 전환."),
            ("검색", "이름·종류·용도로 찾기. ilvl>=50, rarity=rare, AND·OR·NOT, 괄호."),
            ("캐릭터 선택", "같은 서버 다른 캐릭터의 가방·은행을 보기 전용으로 엽니다."),
            ("분류 목록", "누르면 그 분류만 표시, 오른쪽 클릭은 분류 메뉴, 아이템을 끌어 놓으면 사용자 분류에 넣기."),
            ("분류 머리글", "누르면 접기/펼치기. 오른쪽 클릭: 고정·숨김·끄기, 은행·우편·거래·상인으로 옮기기. ≈ 시세 합계."),
            ("아이템", "용도(비귀속·퀘·책·전문 기술), 장비 레벨, 새 아이템 초록 점, 잠금 자물쇠. 오른쪽 클릭 사용(전투 중 포함), Ctrl+Alt+클릭 잠금."),
            ("가방 아이콘·정리", "열쇠고리 → 가방 4·3·2·1 → 배낭과 빈 칸 수. [정리]는 게임의 가방 정리, [새 아이템 ✓]는 초록 점 지우기."),
            ("툴팁", "쓰이는 전문 기술, 경매장 단가와 7일 평균 대비 변화(▲/▼), 캐릭터별 가방·은행 보유 수."),
            ("시세 그래프", "시세 목록에서 아이템을 누르면 최근 30일 최저가(선)와 등록 수량(막대)을 봅니다."),
            ("시세 목록", "경매장이 열려 있을 때 전체 시세 수집 또는 가방 아이템 조회. 오른쪽 클릭하면 구매 창에서 찾습니다."),
            ("경매장 구매 창", "경매장 옆에 열립니다. 최저가부터 보여 주고 수량만큼 최저가부터 삽니다. 구매마다 확인 창이 뜹니다."),
            ("판매 목록", "체크한 가방 물건을 하나씩 판매 창에 최저가보다 조금 낮게 올립니다. 가방 아이템 Alt+클릭은 한 개씩."),
        ],
        # settings
        "sTitle": "설정창", "sHead": "/ezbags settings · 언어, 상인 자동 판매·수리, 아이콘 표시, 보기·크기, 분류, 경매장 도우미, 아이템 잠금",
        "sec": ["일반", "상인", "아이콘 표시", "보기", "분류·창"],
        "language": "언어", "langValue": "자동 (게임 언어)",
        "checks1": ["기본 가방 대체", "묶음 합계 표시"], "checksM": ["회색 잡템 자동 판매", "장비 자동 수리"], "checks2": ["아이템 용도", "장비 레벨", "빈 칸 개별 표시", "새 아이템 분류"],
        "choices": [("보기", "분류"), ("아이템 정렬", "이름"), ("분류 정렬", "이름")],
        "numbers": [("줄당 칸 수 (전체)", "12 (6+6)"), ("분류 열 수", "2"), ("아이콘 크기", "30"), ("창 크기", "1"), ("불투명도", "0.96")],
        "restore": "숨김·꺼진 분류 복원", "reset": "창 위치 초기화", "catName": "분류 이름", "catQuery": "검색식",
        "catNameValue": "물약", "catQueryValue": "물약 OR 비약",
        "hint": "검색식을 비우면 아이템을 끌어 놓아 지정합니다.",
        "sec2": ["경매장", "아이템 잠금"],
        "ahChecks": ["판매 도우미 (Alt+클릭)", "경매장 옆 구매 창", "툴팁에 시세 추세"],
        "undercut": "가격 낮추기", "copper": "동", "history": "시세 기록 보관 (일)",
        "lockCheck": "아이템 잠금 사용", "unlockAll": "모든 잠금 해제 (2)",
        "help": ["가방 아이템 클릭:", "Ctrl+Alt+클릭 – 잠금/해제 (이 캐릭터)", "Ctrl+Alt+오른쪽 클릭 – 계정 전체 잠금/해제",
                 "경매장에서 Alt+클릭 – 판매 창에 올리기", "경매장에서 Alt+오른쪽 클릭 – 구매 창에서 찾기",
                 "시세 탭: 클릭 – 그래프, 오른쪽 클릭 – 경매장에서 찾기"],
        "sNotes": [
            ("일반", "언어(자동 + 8개 언어, 목록에서 선택), 기본 가방 대체(B 키·가방 버튼), 같은 아이템 묶음 합계."),
            ("상인", "상점을 열면 회색 잡템을 팔고 장비를 수리한 뒤 금액을 알려 줍니다. Shift를 누른 채 열면 건너뜁니다."),
            ("아이콘 표시", "아이템 용도, 장비 레벨, 빈 칸 개별 표시, 새 아이템을 별도 분류로."),
            ("보기·크기", "분류 · 전체 · 목록, 아이템·분류 정렬, 줄당 칸 수 6~20, 분류 열 1~3, 아이콘 28~56, 창 크기 0.65~1.4, 불투명도 0.4~1."),
            ("분류·창", "숨긴·끈 분류 복원, 창 위치 초기화, 이름 + 검색식으로 사용자 분류 만들기."),
            ("경매장", "Alt+클릭 판매 도우미, 경매장 옆 구매 창, 툴팁 시세 추세. 가격 낮추기는 동 또는 %, 시세 기록 30~120일 보관."),
            ("아이템 잠금", "잠근 아이템은 자동 판매·분류 이동·경매 등록에서 빠집니다. 캐릭터별 또는 계정 전체로 잠급니다."),
        ],
        "note": "애드온 코드의 창 크기·좌표·색상·문구로 재현한 예시 화면입니다. 아이템 그림은 단순화했고, 이름과 시세는 지어낸 예시입니다.",
    },
    "en": {
        "subtitle": "Bags and bank by category, alt storage and auction prices.",
        "head": "Categorized bags, purpose and lock marks, alt bags and banks, auction prices, graph, buy and sell helpers",
        "bags": "Bags", "bank": "Bank", "prices": "Prices", "settings": "Settings", "sort": "Sort",
        "char": "Bagkeeper Windale - Forever", "status": "Bags · 11-08 20:40", "allGrid": "Show · Grid",
        "groups": {"equipment": "Equipment", "consumable": "Consumables", "materials": "Materials", "quest": "Quest",
                   "recipe": "Recipes", "junk": "Junk"},
        "free": "Free slots: 13 (General 13) · Keyring 29", "new": "New ✓",
        "items": {
            "harness": "Brawler's Harness", "boots": "Rough Leather Boots", "shield": "Sturdy Buckler",
            "potion": "Minor Healing Potion", "ribs": "Roasted Boar Ribs", "hearth": "Hearthstone",
            "linen": "Linen Cloth", "peace": "Peacebloom", "copper": "Copper Ore", "leather": "Light Leather", "dust": "Strange Dust",
            "docs": "Marshal's Papers", "recipe": "Recipe: Minor Healing Potion", "watch": "Small Pocket Watch",
        },
        "tags": {"boe": "BoE", "q": "Q", "book": "Recipe", "tl": "Tailoring", "al": "Alchemy", "mi": "Mining", "lw": "Leatherworking", "en": "Enchanting"},
        "tip": {"name": "Linen Cloth", "mat": "Materials: Engineering, Smithing, First Aid, Tailoring", "price": "Prices / 1", "days": "(7d)",
                "cached": "Cached: 11-08 20:35",
                "chars": [("Bagkeeper Windale", "Bags 27 · Bank 20"), ("Bankkeeper Stonewall", "Bags 0 · Bank 60")]},
        "secB": "Prices tab · auction buy panel",
        "pStatus": "Forever · Cached · 11-08 20:30",
        "classes": ["Weapon", "Armor", "Container", "Consumable", "Trade Goods", "Recipe", "Projectile", "Quiver", "Gem", "Quest", "Miscellaneous"],
        "graphTitle": "Lowest price, last 30 days", "scan": "Full scan", "bagScan": "Scan bag items", "stop": "Stop",
        "pFooter": "Prices · 5 · Forever:Alliance", "pHint": "Click: graph · Right-click: find at the auction house",
        "buyTitle": "Auction buy", "sellList": "Sell list", "search": "Search", "back": "← List", "qty": "Quantity",
        "cheapest": "Buy cheapest first", "unit": "Unit price", "seller": "Seller", "own": "Yours",
        "sellers": ["Bagmonger", None, "Linenwright", "Clothpatch +2", "Spoolie", "Wayfarer Goods", "Bagmonger +1", "Needlehouse"],
        "estimate": "Cheapest 20 · about",
        "notes": [
            ("Tabs", "Switch Bags · Bank · Prices."),
            ("Search", "Name, type or purpose. ilvl>=50, rarity=rare, AND·OR·NOT, brackets."),
            ("Character", "Open another character's bags and bank on the realm, read only."),
            ("Category list", "Click to show only that category, right-click for its menu, drop an item into a custom category."),
            ("Category header", "Click to collapse. Right-click: pin · hide · disable, move to bank · mail · trade · vendor. ≈ price total."),
            ("Items", "Purpose labels (BoE · Q · Recipe · professions), item level, green dot for new items, padlock for locked items. Right-click uses (also in combat), Ctrl+Alt+click locks."),
            ("Bag icons · Sort", "Keyring → bags 4·3·2·1 → backpack with free slots. Sort uses the game's own bag sort; New ✓ clears the green dots."),
            ("Tooltip", "Professions that use the item, auction unit price with the change against the 7-day average (▲/▼), per-character counts."),
            ("Price graph", "Click an item in the price list to see its lowest price of the last 30 days (line) and the listed quantity (bars)."),
            ("Price list", "Full scan or scan of your bag items while the auction house is open. Right-click a row to find it in the buy panel."),
            ("Auction buy panel", "Opens beside the auction house, cheapest offers first; buy a quantity cheapest first. Every purchase asks for confirmation."),
            ("Sell list", "Puts the checked bag items into the sell frame one by one, priced just under the lowest. Alt+click a bag item for a single one."),
        ],
        "sTitle": "Settings", "sHead": "/ezbags settings · language, vendor auto-sell and repair, icons, view and sizes, categories, auction helpers, item lock",
        "sec": ["General", "Merchant", "Item icons", "View", "Categories & window"],
        "language": "Language", "langValue": "Auto (game language)",
        "checks1": ["Replace default bags", "Combine stacks"], "checksM": ["Auto-sell grey junk", "Auto-repair gear"], "checks2": ["Purpose labels", "Equipment levels", "Individual free slots", "New item category"],
        "choices": [("View", "Sections"), ("Item sorting", "Name"), ("Category sorting", "Name")],
        "numbers": [("Items per row (total)", "12 (6+6)"), ("Category columns", "2"), ("Icon size", "30"), ("Window scale", "1"), ("Opacity", "0.96")],
        "restore": "Restore categories", "reset": "Reset position", "catName": "Category name", "catQuery": "Search expression",
        "catNameValue": "Potions", "catQueryValue": "potion OR elixir",
        "hint": "Leave the query empty to assign items by dragging.",
        "sec2": ["Auction house", "Item lock"],
        "ahChecks": ["Sell helper (Alt+click)", "Buy panel next to the auction house", "Price trend on tooltips"],
        "undercut": "Undercut", "copper": "Copper", "history": "Keep price history (days)",
        "lockCheck": "Use item lock", "unlockAll": "Unlock all (2)",
        "help": ["Bag item clicks:", "Ctrl+Alt+click – lock/unlock (this character)", "Ctrl+Alt+right-click – lock/unlock for all characters",
                 "At the auction house, Alt+click – put into the sell frame", "At the auction house, Alt+right-click – find in the buy panel",
                 "Price tab: click – graph, right-click – search the auction house"],
        "sNotes": [
            ("General", "Language (automatic + 8 languages, picked from a list), replace default bags (B key, bag buttons), combine stacks."),
            ("Merchant", "When a vendor opens, sells grey items and repairs your gear, then reports the gold. Hold Shift while opening to skip."),
            ("Item icons", "Purpose labels, item levels, individual free slots, a separate category for new items."),
            ("View · sizes", "Sections · Grid · List, item and category sorting, items per row 6–20, category columns 1–3, icons 28–56, scale 0.65–1.4, opacity 0.4–1."),
            ("Categories & window", "Restore hidden/disabled categories, reset position, create a custom category from a name and search."),
            ("Auction house", "Alt+click sell helper, buy panel beside the auction house, price trend on tooltips. Undercut in copper or %, keep 30–120 days of history."),
            ("Item lock", "Locked items are skipped by auto-sell, category moves and auction posting. Lock per character or for all characters."),
        ],
        "note": "Mock-ups rebuilt from the window sizes, coordinates, colours and strings in the addon code. Item art is simplified; names and prices are made up.",
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


LOCK_SVG = ('<svg width="100%" height="100%" viewBox="0 0 24 24"><path d="M7 11 V8 a5 5 0 0 1 10 0 V11" stroke="#d9c58a" stroke-width="3" fill="none"/>'
            '<rect x="4" y="11" width="16" height="11" rx="2" fill="#e8c34a" stroke="#4a3a10" stroke-width="1.5"/><circle cx="12" cy="16.5" r="2" fill="#4a3a10"/></svg>')


def px(v):
    return f"{v * SCALE:.1f}px"


CSS = f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ width: 1600px; background: radial-gradient(ellipse at 30% 0%, #1d2a33 0%, #10171d 60%, #0b1014 100%);
  font-family: 'Noto Sans CJK KR', 'Malgun Gothic', 'Noto Sans', sans-serif; color: {TEXT}; }}
.page {{ position: relative; padding: 34px 50px 40px; }}
h1 {{ color: {ACCENT}; font-size: 40px; font-weight: 700; letter-spacing: .3px; display: flex; align-items: center; gap: 14px; }}
h1 .badge {{ font-size: 15px; background: {ACCENT}; color: #1a1206; padding: 2px 9px; border-radius: 5px; }}
.lead {{ color: #d5dde2; font-size: 19px; margin-top: 6px; }}
.h2 {{ position: absolute; color: {ACCENT}; font-size: 24px; font-weight: 700; }}
.abs {{ position: absolute; }}
.win {{ position: absolute; background: {BG}; border: 1px solid {BORDER}; }}
.hdr {{ position: absolute; left: 1px; right: 1px; top: 1px; height: {px(56)}; background: {PANEL}; }}
.hline {{ position: absolute; left: 1px; right: 1px; top: {px(55)}; height: {px(2)}; background: {ACCENT}; }}
.title {{ position: absolute; left: {px(48)}; top: {px(9)}; font-size: {px(15)}; color: {ACCENT}; }}
.sub {{ position: absolute; left: {px(48)}; top: {px(31)}; font-size: {px(10)}; color: {MUTED}; white-space: nowrap; }}
.btn {{ position: absolute; background: {PANEL}; border: 1px solid {BORDER}; color: {MUTED}; font-size: {px(10.5)};
  display: flex; align-items: center; justify-content: center; white-space: nowrap; overflow: hidden; }}
.btn.left {{ justify-content: flex-start; padding-left: {px(7)}; }}
.btn.sel {{ background: {SELBG}; border-color: {ACCENT}; color: #ffe0a6; }}
.btn.sel::after {{ content: ''; position: absolute; left: 1px; right: 1px; bottom: 1px; height: {px(3)}; background: {ACCENT}; }}
.btn.primary {{ background: {SELBG}; border-color: {ACCENT}; color: #ffe0a6; }}
.btn.dim {{ opacity: .45; }}
.btn .ic {{ width: {px(16)}; height: {px(16)}; border-radius: 2px; margin-right: {px(6)}; flex: none; }}
.close {{ position: absolute; width: {px(24)}; height: {px(24)}; background: {BG}; border: 1px solid {BORDER}; color: {MUTED};
  font-size: {px(12)}; display: flex; align-items: center; justify-content: center; }}
.edit {{ position: absolute; background: {INPUT}; border: 1px solid {BORDER}; color: {TEXT}; font-size: {px(10.5)};
  display: flex; align-items: center; padding-left: {px(8)}; white-space: nowrap; overflow: hidden; }}
.lbl {{ position: absolute; font-size: {px(10.5)}; color: {TEXT}; white-space: nowrap; }}
.muted {{ color: {MUTED}; }}
.item {{ position: absolute; width: {px(30)}; height: {px(30)}; border: 1px solid; background: #141c24; }}
.item svg {{ position: absolute; left: {px(2)}; top: {px(2)}; }}
.item .tag {{ position: absolute; left: {px(3)}; top: {px(2)}; font-size: {px(9.5)}; color: #4dffa6; text-shadow: 0 0 2px #000, 1px 1px 1px #000;
  white-space: nowrap; max-width: {px(25)}; overflow: hidden; text-overflow: ellipsis; }}
.item .cnt {{ position: absolute; right: {px(3)}; bottom: {px(2)}; font-size: {px(11)}; color: #fff; text-shadow: 1px 1px 1px #000, 0 0 2px #000; }}
.item .lvl {{ position: absolute; right: {px(3)}; top: {px(2)}; font-size: {px(9.5)}; text-shadow: 1px 1px 1px #000, 0 0 2px #000; }}
.item .dot {{ position: absolute; left: {px(3)}; bottom: {px(1)}; font-size: {px(9)}; color: #59ffa6; }}
.item .lock {{ position: absolute; left: {px(2)}; bottom: {px(2)}; width: {px(12)}; height: {px(12)}; }}
.item .lock svg {{ position: static; }}
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
.tick {{ position: absolute; width: {px(14)}; height: {px(14)}; border: 1px solid {BORDER}; background: {INPUT}; }}
.secline {{ position: absolute; height: 1px; background: rgba(52,76,91,.85); }}
"""

SHADE = ('<svg width="0" height="0" style="position:absolute"><defs><linearGradient id="shade" x1="0" y1="0" x2="1" y2="1">'
         '<stop offset="0" stop-color="#fff" stop-opacity=".18"/><stop offset=".55" stop-color="#000" stop-opacity="0"/>'
         '<stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient></defs></svg>')

GROUP_ICON = {"equipment": "#a0703f", "consumable": "#c94a4a", "materials": "#d8cfb2", "quest": "#8a6f3c",
              "recipe": "#e2cf91", "junk": "#9d9d9d", "all": "#6d8798", "bags": "#c8955a", "other": "#7d8a93",
              "prices": "#e0b84a"}
# price catalog classes (Modules/PriceCatalog.lua): icon of each row
CLASS_ICON = ["equipment", "equipment", "bags", "consumable", "materials", "recipe", "other", "bags", "materials", "quest", "other"]

GOLD, SILVER, COPPER = "#e8c34a", "#c7cfd6", "#c27a45"


def money(g, s, c):
    """ns.Money: gold (when > 0), silver and copper."""
    out = ""
    if g:
        out += f'{g}<i style="background:{GOLD}"></i> '
    out += f'{s}<i style="background:{SILVER}"></i> {c}<i style="background:{COPPER}"></i>'
    return f'<span class="money">{out}</span>'


def money_short(value):
    """ns.MoneyShort: two coin units at most, zero parts left out."""
    value = int(round(value))
    g, s, c = value // 10000, value // 100 % 100, value % 100
    parts = []
    if g:
        parts.append((g, GOLD))
        if s:
            parts.append((s, SILVER))
    elif s:
        parts.append((s, SILVER))
        if c:
            parts.append((c, COPPER))
    else:
        parts.append((c, COPPER))
    return '<span class="money">' + " ".join(f'{n}<i style="background:{col}"></i>' for n, col in parts) + '</span>'


def trend_html(pct, days):
    arrow, col = ("▲", UP) if pct > 0 else ("▼", DOWN)
    return f'<span style="color:{col}">{arrow}{abs(pct)}%</span> <span style="color:{HINT}">{days}</span>'


def item_html(at, x, y, art, q, tag, lvl, cnt, new, locked, tags, size=30):
    col = QUALITY[q] if q != 1 else "#5c6b75"
    inner = art_svg(art, round((size - 4) * SCALE))
    inner += f'<span class="tag">{tags[tag]}</span>' if tag else ""
    inner += f'<span class="cnt">{cnt}</span>' if cnt > 1 else ""
    inner += f'<span class="lvl" style="color:{QUALITY[q]}">{lvl}</span>' if lvl else ""
    inner += '<span class="dot">●</span>' if new and not locked else ""
    inner += f'<span class="lock">{LOCK_SVG}</span>' if locked else ""
    return f'<div class="item" style="{at(x, y)}border-color:{col}">{inner}</div>'


def window_head(at, W, icon_uri, subtitle, sub_max):
    return ('<div class="hdr"></div><div class="hline"></div>'
            f'<img class="abs" src="{icon_uri}" style="{at(14, 14)}width:{px(28)};height:{px(28)}">'
            f'<div class="title">EzWoW - Bags</div><div class="sub" style="max-width:{px(sub_max)};overflow:hidden">{subtitle}</div>'
            f'<div class="close" style="{at(W - 14 - 24, 16)}">X</div>')


def common_top(at, t, W, mode):
    """Settings button, tabs, search box, character picker (UI/Window.lua CreateWindow)."""
    p = [f'<div class="btn" style="{at(W - 14 - 24 - 6 - 80, 16)}width:{px(80)};height:{px(24)};"><span class="ic" style="background:#7d8a93;border-radius:50%"></span>{t["settings"]}</div>']
    for i, key in enumerate(("bags", "bank", "prices")):
        sel = key == mode
        colr = {"bags": "#c8955a", "bank": "#3f6fb0", "prices": "#e0b84a"}[key]
        p.append(f'<div class="btn left {"sel" if sel else ""}" style="{at(16 + i * 111, 65)}width:{px(104)};height:{px(28)}">'
                 f'<span class="ic" style="background:{colr}"></span>{"✓ " if sel else ""}{t[key]}</div>')
    p.append(f'<div class="edit" style="{at(16 + 374 - 32, 66)}width:{px(W - 374)};height:{px(25)}"></div>')
    p.append(f'<div class="btn left" style="{at(16, 101)}width:{px(W - 32)};height:{px(24)}">'
             f'<span class="ic" style="background:#8b6a3b"></span><span class="ic" style="background:#b98a6a;border-radius:50%"></span>'
             f'<span style="color:{TEXT}">{t["char"]} ▾</span></div>')
    return p


def bag_window(t, icon_uri, ox, oy):
    """Bags tab in the category view (12 per row = 6+6, icon 30): returns html, width, height (game px)."""
    I, TG = t["items"], t["tags"]
    W = 586                     # ns.BagLayout().width for 12 columns of 30 px in 2 lanes
    parts = []

    def at(x, y):
        return f"left:{px(x)};top:{px(y)};"

    # sections: (key, has value, items[(art, quality, tag, lvl, count, new, locked)])
    sections = [
        ("equipment", True, [("harness", 2, "boe", 12, 1, True, False), ("shield", 3, "boe", 18, 1, False, True),
                             ("boots", 1, None, 9, 1, False, False)]),
        ("materials", True, [("linen", 1, "tl", None, 27, False, False), ("peace", 1, "al", None, 3, False, False),
                             ("copper", 1, "mi", None, 10, False, False), ("leather", 1, "lw", None, 6, False, False),
                             ("dust", 1, "en", None, 4, False, False)]),
        ("consumable", True, [("potion", 1, None, None, 5, True, False), ("ribs", 1, None, None, 8, False, False),
                              ("hearth", 1, None, None, 1, False, False)]),
        ("quest", False, [("docs", 1, "q", None, 1, False, False)]),
        ("recipe", True, [("recipe", 2, "book", None, 1, False, False)]),
        ("junk", True, [("watch", 0, None, None, 1, False, False)]),
    ]
    values = {"equipment": (0, 95, 40), "materials": (1, 62, 30), "consumable": (0, 18, 75), "recipe": (0, 85, 0), "junk": (0, 25, 0)}
    counts = {k: sum(i[4] for i in items) for k, _, items in sections}
    order = sorted(sections, key=lambda s: t["groups"][s[0]])    # category sorting: name
    lanes = [0, 0]
    offsets, laneW = [0, 210], 200
    content = []
    for key, has_value, items in order:
        lane = 0 if lanes[0] <= lanes[1] else 1
        x, y = offsets[lane], lanes[lane]
        compact = has_value
        hh = 40 if compact else 23
        name = f'− {t["groups"][key]} · {counts[key]}'
        content.append(f'<div class="btn left" style="{at(148 + x, 159 + y)}width:{px(laneW)};height:{px(hh)};'
                       f'{"align-items:flex-start;padding-top:" + px(4) + ";" if compact else ""}">'
                       f'<span class="ic" style="background:{GROUP_ICON[key]}"></span><span style="color:{MUTED}">{name}</span></div>')
        if compact:
            g, s, c = values[key]
            content.append(f'<div class="lbl" style="{at(148 + x + 29, 159 + y + 22)}font-size:{px(9)};color:{ACCENT}">≈ {money(g, s, c)}</div>')
        y += hh + 5
        for i, (art, q, tag, lvl, cnt, new, locked) in enumerate(items):
            content.append(item_html(at, 148 + x + (i % 6) * 34, 159 + y + (i // 6) * 34, art, q, tag, lvl, cnt, new, locked, TG))
        y += ((len(items) + 5) // 6) * 34
        lanes[lane] = y + 12
    h = max(lanes)
    side = [("all", t["allGrid"], None)] + [(k, t["groups"][k], counts[k]) for k, _, _ in order]
    side_h = len(side) * 27 + 12
    H = max(399, min(669, max(h + 270, side_h + 265)))

    parts.append(f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">')
    parts.append(window_head(at, W, icon_uri, t["subtitle"], W - 200))
    parts.extend(common_top(at, t, W, "bags"))
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
                     f'<span class="abs" style="right:{px(4)};bottom:{px(2)};font-size:{px(11)};color:#fff;text-shadow:1px 1px 1px #000">{frees[i]}</span></div>')
    parts.append(f'<div class="btn" style="{at(W - 152 - 90, H - 10 - 24)}width:{px(90)};height:{px(24)}"><span class="ic" style="background:#c8955a"></span>{t["sort"]}</div>')
    parts.append(f'<div class="btn" style="{at(W - 16 - 130, H - 10 - 24)}width:{px(130)};height:{px(24)}"><span class="ic" style="background:#6b8f5a"></span>{t["new"]}</div>')
    parts.append('</div>')
    return "".join(parts), W, H


def graph_svg(w, h, points, lo, hi):
    """PriceGraph plot area: price line with dots, listed quantity bars (a third of the height at most)."""
    days = 30
    step = w / (days - 1)
    maxq = max(q for _, _, q in points)
    out = [f'<svg width="{w * SCALE:.0f}" height="{h * SCALE:.0f}" viewBox="0 0 {w} {h}" style="position:absolute;left:0;top:0;overflow:visible">']
    for i in range(3):
        y = h - (i / 2) * h
        out.append(f'<line x1="0" x2="{w}" y1="{y:.1f}" y2="{y:.1f}" stroke="rgba(52,76,91,.45)" stroke-width="1"/>')
    out.append(f'<line x1="0" x2="{w}" y1="{h - .5}" y2="{h - .5}" stroke="{BORDER}" stroke-width="1"/>')
    bw = max(2, step * .45)
    for d, _, q in points:
        bh = max(1, q / maxq * h * .33)
        out.append(f'<rect x="{d * step - bw / 2:.1f}" y="{h - 1 - bh:.1f}" width="{bw:.1f}" height="{bh:.1f}" fill="rgba(74,115,140,.55)"/>')

    def Y(v):
        return h - (v - lo) / (hi - lo) * h
    line = " ".join(f"{d * step:.1f},{Y(p):.1f}" for d, p, _ in points)
    out.append(f'<polyline points="{line}" fill="none" stroke="rgba(240,184,107,.9)" stroke-width="2"/>')
    for d, p, _ in points:
        out.append(f'<rect x="{d * step - 2.5:.1f}" y="{Y(p) - 2.5:.1f}" width="5" height="5" fill="#ffdb99"/>')
    out.append('</svg>')
    return "".join(out)


def prices_window(t, icon_uri, ox, oy):
    """Prices tab with the 30-day graph of the selected item (UI/Window.lua Render, UI/PriceGraph.lua)."""
    W = 586
    I = t["items"]

    def at(x, y):
        return f"left:{px(x)};top:{px(y)};"
    side = [("prices", t["allGrid"])] + list(zip(CLASS_ICON, t["classes"]))
    side_h = len(side) * 27 + 12
    graph_h = 178 + 8
    rows = [("linen", "tl", 4520), ("copper", "mi", 1850), ("leather", "lw", 2200), ("peace", "al", 975), ("dust", "en", 3140)]
    rows.sort(key=lambda r: I[r[0]])
    h = len(rows) * 42
    H = max(399, min(669 + graph_h, max(h + 270 + graph_h, side_h + 265)))
    p = [f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">',
         window_head(at, W, icon_uri, t["subtitle"], W - 200)]
    p.extend(common_top(at, t, W, "prices"))
    p.append(f'<div class="lbl" style="{at(16, 137)}">{t["pStatus"]}</div>')
    p.append(f'<div class="abs" style="{at(12, 158)}width:{px(130)};height:{px(H - 258)};background:#121c24;border:1px solid {BORDER}"></div>')
    for i, (icon, label) in enumerate(side):
        sel = i == 0
        p.append(f'<div class="btn left {"sel" if sel else ""}" style="{at(18, 164 + i * 27)}width:{px(118)};height:{px(24)}">'
                 f'<span class="ic" style="background:{GROUP_ICON[icon]}"></span>{label}</div>')
    # graph frame: TOPLEFT 148,-159 to TOPRIGHT -16,-159, height 178
    gx, gy, gw, gh = 148, 159, W - 16 - 148, 178
    PAD_L, PAD_R, PAD_T, PAD_B = 74, 14, 36, 22
    pw, ph = gw - PAD_L - PAD_R, gh - PAD_T - PAD_B
    # 30 days of daily lowest prices (copper) and listed quantities; the last day is today
    prices = [4310, 4290, 4350, 4400, 4380, 4250, 4180, 4200, 4260, 4330, 4410, 4460, 4390, 4300, 4220,
              4150, 4120, 4180, 4240, 4210, 4160, 4100, 4080, 4120, 4170, 4230, 4300, 4380, 4450, 4520]
    qty = [210, 180, 160, 240, 300, 280, 260, 190, 170, 220, 260, 310, 290, 250, 230,
           200, 180, 260, 330, 310, 280, 240, 220, 200, 230, 260, 240, 210, 230, 252]
    pts = [(d, prices[d], qty[d]) for d in range(30) if d not in (5, 12, 19)]   # a few days without a scan
    lo, hi = min(prices), max(prices)
    span = hi - lo
    lo, hi = max(0, lo - span * .12), hi + span * .12
    p.append(f'<div class="abs" style="{at(gx, gy)}width:{px(gw)};height:{px(gh)};background:rgba(15,22,28,.98);border:1px solid {BORDER}">')
    p.append(f'<div class="abs" style="{at(8, 7)}width:{px(20)};height:{px(20)}">{art_svg("linen", round(20 * SCALE))}</div>')
    p.append(f'<div class="lbl" style="{at(34, 9)}font-size:{px(12)}">{I["linen"]}&nbsp;&nbsp;<span style="color:{HINT}">{t["graphTitle"]}</span></div>')
    p.append(f'<div class="lbl" style="right:{px(36)};top:{px(10)};font-size:{px(11)}">{money_short(4520)}&nbsp;&nbsp;{trend_html(8, t["tip"]["days"])}</div>')
    p.append(f'<div class="btn" style="right:{px(6)};top:{px(6)};width:{px(22)};height:{px(20)}">×</div>')
    p.append(f'<div class="abs" style="{at(PAD_L, PAD_T)}width:{px(pw)};height:{px(ph)}">{graph_svg(pw, ph, pts, lo, hi)}</div>')
    for i in range(3):
        v = lo + (hi - lo) * i / 2
        y = PAD_T + ph - ph * i / 2
        p.append(f'<div class="lbl" style="left:0;width:{px(PAD_L - 6)};top:{px(y - 7)};text-align:right;font-size:{px(9)};color:{MUTED}">{money_short(v)}</div>')
    for i, label in ((0, "10/10"), (15, "10/25"), (29, "11/08")):
        x = PAD_L + pw * i / 29
        p.append(f'<div class="lbl" style="left:{px(x - 25)};width:{px(50)};top:{px(gh - PAD_B + 4)};text-align:center;font-size:{px(9)};color:{MUTED}">{label}</div>')
    p.append('</div>')
    # price rows: 38 px high every 42 px, from y = 159 + graph height
    width = W - 176 - 4
    for i, (art, tag, unit) in enumerate(rows):
        y = 159 + graph_h + i * 42
        sel = art == "linen"
        border = ACCENT if sel else "#5c6b75"
        p.append(f'<div class="abs" style="{at(148, y)}width:{px(width)};height:{px(38)};background:#141c24;border:1px solid {border}">'
                 f'<div class="abs" style="{at(2, 2)}">{art_svg(art, round(34 * SCALE))}</div>'
                 f'<span class="abs" style="{at(3, 2)}font-size:{px(9.5)};color:#4dffa6;text-shadow:0 0 2px #000;max-width:{px(36)};overflow:hidden;white-space:nowrap;text-overflow:ellipsis">{t["tags"][tag]}</span>'
                 f'<span class="lbl" style="{at(44, 4)}">{I[art]}</span>'
                 f'<span class="lbl" style="{at(44, 22)}font-size:{px(9)};color:{MUTED}">11-08 20:{30 - i}</span>'
                 f'<span class="lbl" style="right:{px(10)};top:{px(11)};font-size:{px(11)}">{money(unit // 10000, unit // 100 % 100, unit % 100)}</span></div>')
    p.append(f'<div class="lbl" style="{at(16, H - 73 - 14)}">{t["pFooter"]}&nbsp;&nbsp;&nbsp;<span style="color:{HINT}">{t["pHint"]}</span></div>')
    p.append(f'<div class="btn left" style="{at(16, H - 40 - 24)}width:{px(155)};height:{px(24)}"><span class="ic" style="background:#e0b84a"></span>{t["scan"]}</div>')
    p.append(f'<div class="btn left" style="{at(177, H - 40 - 24)}width:{px(155)};height:{px(24)}"><span class="ic" style="background:#c8955a"></span>{t["bagScan"]}</div>')
    p.append(f'<div class="btn left" style="{at(338, H - 40 - 24)}width:{px(70)};height:{px(24)}"><span class="ic" style="background:#b04a4a"></span>{t["stop"]}</div>')
    p.append('</div>')
    return "".join(p), W, H, (gx, gy, gw), 159 + graph_h


def buy_panel(t, icon_uri, ox, oy):
    """Auction buy panel docked beside the auction house (Modules/AuctionTrade.lua CreatePanel), detail view."""
    W, H = 310, 520

    def at(x, y):
        return f"left:{px(x)};top:{px(y)};"
    I = t["items"]
    p = [f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">',
         f'<img class="abs" src="{icon_uri}" style="{at(10, 7)}width:{px(20)};height:{px(20)}">',
         f'<div class="lbl" style="{at(36, 9)}font-size:{px(13)};color:{ACCENT}">{t["buyTitle"]}</div>',
         f'<div class="abs" style="left:1px;right:1px;top:{px(33)};height:{px(2)};background:{ACCENT}"></div>',
         f'<div class="btn" style="right:{px(32)};top:{px(6)};width:{px(76)};height:{px(22)}">{t["sellList"]}</div>',
         f'<div class="close" style="right:{px(6)};top:{px(5)};width:{px(22)};height:{px(22)}">X</div>',
         f'<div class="edit" style="{at(12, 42)}width:{px(200)};height:{px(25)}">{I["linen"]}</div>',
         f'<div class="btn" style="{at(218, 42)}width:{px(76)};height:{px(24)}">{t["search"]}</div>',
         f'<div class="btn" style="{at(12, 72)}width:{px(74)};height:{px(22)}">{t["back"]}</div>',
         f'<div class="lbl" style="{at(94, 75)}font-size:{px(12)}">{I["linen"]}&nbsp;&nbsp;<span style="color:{MUTED}">×352</span></div>',
         f'<div class="lbl" style="{at(14, 104)}font-size:{px(11)}">{t["qty"]}</div>',
         f'<div class="edit" style="{at(64, 100)}width:{px(56)};height:{px(22)}">20</div>',
         f'<div class="btn primary" style="{at(128, 100)}width:{px(150)};height:{px(22)}">{t["cheapest"]}</div>',
         f'<div class="abs" style="{at(12, 127)}width:{px(W - 24)};height:{px(20)};background:rgba(29,40,49,.9);border-bottom:1px solid rgba(240,184,107,.45)"></div>',
         f'<div class="lbl" style="{at(18, 130)}font-size:{px(10)};color:{MUTED}">{t["unit"]}</div>',
         f'<div class="lbl" style="left:{px(150)};width:{px(52)};top:{px(130)};text-align:right;font-size:{px(10)};color:{MUTED}">{t["qty"]}</div>',
         f'<div class="lbl" style="right:{px(18)};top:{px(130)};font-size:{px(10)};color:{MUTED}">{t["seller"]}</div>']
    offers = [(4490, 20), (4520, 40), (4550, 12), (4600, 60), (4710, 20), (4800, 100), (4850, 35), (4990, 65)]
    for i, ((unit, q), seller) in enumerate(zip(offers, t["sellers"])):
        y = 148 + i * 24
        shade = PANEL if (i + 1) % 2 == 0 else BG
        right = f'<span style="color:{UP}">{t["own"]}</span>' if seller is None else seller
        p.append(f'<div class="abs" style="{at(12, y)}width:{px(W - 24)};height:{px(22)};background:{shade};border:1px solid {BORDER}">'
                 f'<span class="lbl" style="{at(6, 3)}font-size:{px(11)}">{money_short(unit)}</span>'
                 f'<span class="lbl" style="left:{px(150 - 12)};width:{px(40)};top:{px(4)};text-align:right;font-size:{px(10)}">{q}</span>'
                 f'<span class="lbl" style="right:{px(8)};top:{px(3)};font-size:{px(11)};color:{TEXT}">{right}</span></div>')
    p.append(f'<div class="lbl" style="{at(12, H - 10 - 16)}font-size:{px(11)};color:{MUTED}">{t["estimate"]} {money_short(20 * 4490)}</div>')
    p.append('</div>')
    return "".join(p), W, H


def tooltip_html(t, x, y):
    tip = t["tip"]
    rows = [f'<div style="color:#fff;font-size:16px">{tip["name"]}</div>', f'<div style="color:{ACCENT}">{tip["mat"]}</div>',
            f'<div class="row"><span style="color:{ACCENT}">{tip["price"]}&nbsp;&nbsp;{trend_html(8, tip["days"])}</span>'
            f'<span style="color:#ffd166">{money(0, 45, 20)}</span></div>',
            f'<div style="color:{MUTED}">{tip["cached"]}</div>']
    for name, value in tip["chars"]:
        rows.append(f'<div class="row"><span style="color:{MUTED}">{name}</span><span>{value}</span></div>')
    rows.append('<div class="row"><span></span><span style="color:#808080;font-size:12.5px">EzWoW - Bags</span></div>')
    return f'<div class="tip" style="left:{x}px;top:{y}px;width:470px">{"".join(rows)}</div>'


def note_html(start, lst):
    return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{a}</b> — {b}</div></div>' for i, (a, b) in enumerate(lst))


def ui_page(lang, icon_uri):
    t = T[lang]
    parts = []
    # --- bag window, tooltip and notes 1-8 ---
    ox, oy = 72, 160
    win, W, H = bag_window(t, icon_uri, ox, oy)
    parts.append(win)
    right_x = ox + W * SCALE + 50
    tx, ty = right_x, oy + 10
    parts.append(tooltip_html(t, tx, ty))

    def cx(x): return ox + x * SCALE
    def cy(y): return oy + y * SCALE
    calls = [(cx(-14), cy(64)), (cx(W - 4), cy(68)), (cx(W - 4), cy(102)), (cx(-14), cy(190)),
             (cx(148 + 200 - 2), cy(150)), (cx(148 + 34 * 3 - 4), cy(206)), (cx(-14), cy(H - 50)), (tx - 16, ty - 12)]
    for i, (x, y) in enumerate(calls, 1):
        parts.append(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>')
    notes_a_top = ty + 285
    parts.append(f'<div class="notes" style="left:{right_x:.0f}px;top:{notes_a_top:.0f}px;width:{1600 - right_x - 40:.0f}px">{note_html(1, t["notes"][:8])}</div>')
    bottom_a = max(oy + H * SCALE, notes_a_top + 8 * 54)

    # --- prices tab, buy panel and notes 9-12 ---
    head_b = bottom_a + 50
    parts.append(f'<div class="h2" style="left:50px;top:{head_b:.0f}px">{t["secB"]}</div>')
    oy2 = head_b + 60
    pwin, PW, PH, (gx, gy, gw), rows_y = prices_window(t, icon_uri, ox, oy2)
    parts.append(pwin)
    bx = right_x
    bwin, BW, BH = buy_panel(t, icon_uri, bx, oy2)
    parts.append(bwin)
    calls_b = [(ox + (gx + gw * .55) * SCALE, oy2 + (gy - 10) * SCALE), (ox + (PW - 14) * SCALE, oy2 + (rows_y + 61) * SCALE),
               (bx - 16, oy2 + 4), (bx + (BW - 70) * SCALE, oy2 - 16)]
    for i, (x, y) in enumerate(calls_b, 9):
        parts.append(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>')
    notes_b_top = oy2 + BH * SCALE + 30
    parts.append(f'<div class="notes" style="left:{right_x:.0f}px;top:{notes_b_top:.0f}px;width:{1600 - right_x - 40:.0f}px">{note_html(9, t["notes"][8:])}</div>')
    page_h = max(oy2 + PH * SCALE, notes_b_top + 4 * 66) + 80
    parts.append(f'<div class="abs foot" style="left:50px;top:{page_h - 44:.0f}px">{t["note"]}</div>')
    body = (f'<div class="page" style="height:{page_h:.0f}px"><h1>EzWoW - Bags</h1><div class="lead">{t["head"]}</div></div>'
            + "".join(parts))
    return body, page_h


def settings_page(lang, icon_uri):
    t = T[lang]
    W = 840                     # f:SetWidth(840): two columns, the second one at X = 440
    ox, oy = 72, 160
    p = []

    def at(x, y): return f"left:{px(x)};top:{px(y)};"
    y = 70
    secs = []

    def section(name, x=20, yy=None, right=20, line_w=None):
        p.append(f'<div class="lbl" style="{at(x, yy)}font-size:{px(12)};color:{ACCENT}">{name}</div>')
        p.append(f'<div class="secline" style="{at(x, yy + 18)}width:{px(line_w or (W - right - x))}"></div>')

    def lsection(name):
        nonlocal y
        section(name, 20, y, line_w=400)
        secs.append(y)
        y += 26
    lsection(t["sec"][0])
    p.append(f'<div class="lbl" style="{at(20, y + 6)}">{t["language"]}</div>')
    p.append(f'<div class="btn" style="{at(218, y)}width:{px(182)};height:{px(24)}">{t["langValue"]}  ▾</div>')
    y += 30

    def checks(lst, off=()):
        nonlocal y
        for i, name in enumerate(lst):
            x = 18 if i % 2 == 0 else 216
            p.append(f'<div class="check{" off" if i in off else ""}" style="{at(x + 3, y + 3)}"></div>'
                     f'<div class="lbl" style="{at(x + 28, y + 5)}max-width:{px(166)};overflow:hidden;text-overflow:ellipsis">{name}</div>')
            if i % 2 == 1 or i == len(lst) - 1:
                y += 26
        y += 8
    checks(t["checks1"])
    lsection(t["sec"][1])
    checks(t["checksM"])              # autoSellJunk / autoRepair are on by default
    lsection(t["sec"][2])
    checks(t["checks2"], off=(2, 3))  # free slots / new item category are off by default
    lsection(t["sec"][3])
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
    lsection(t["sec"][4])
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
    y += 40
    # second column: auction house helpers and item lock
    X, y2 = 440, 70
    secs2 = []

    def rsection(name):
        nonlocal y2
        section(name, X, y2)
        secs2.append(y2)
        y2 += 26

    def check2(name):
        nonlocal y2
        p.append(f'<div class="check" style="{at(X - 2 + 3, y2 + 3)}"></div><div class="lbl" style="{at(X - 2 + 28, y2 + 5)}">{name}</div>')
        y2 += 26
    rsection(t["sec2"][0])
    for name in t["ahChecks"]:
        check2(name)
    p.append(f'<div class="lbl" style="{at(X, y2 + 6)}">{t["undercut"]}</div>')
    p.append(f'<div class="btn" style="{at(X + 196, y2)}width:{px(90)};height:{px(24)}">{t["copper"]}  ⇄</div>')
    p.append(f'<div class="edit" style="{at(X + 292, y2)}width:{px(70)};height:{px(24)}">1</div>')
    p.append(f'<div class="lbl" style="{at(X + 368, y2 + 6)}">{t["copper"]}</div>')
    y2 += 30
    p.append(f'<div class="lbl" style="{at(X, y2 + 5)}">{t["history"]}</div>')
    p.append(f'<div class="btn" style="{at(X + 196, y2)}width:{px(22)};height:{px(20)}">-</div>')
    p.append(f'<div class="lbl" style="{at(X + 220, y2 + 4)}width:{px(110)};text-align:center">60</div>')
    p.append(f'<div class="btn" style="{at(X + 334, y2)}width:{px(22)};height:{px(20)}">+</div>')
    y2 += 34
    rsection(t["sec2"][1])
    check2(t["lockCheck"])
    p.append(f'<div class="btn" style="{at(X, y2)}width:{px(186)};height:{px(24)}">{t["unlockAll"]}</div>')
    y2 += 34
    p.append(f'<div class="lbl muted" style="{at(X, y2)}line-height:{px(15)};white-space:normal;width:{px(380)}">{"<br>".join(t["help"])}</div>')
    y2 += 108
    H = max(y, y2) + 10
    head = window_head(at, W, icon_uri, f'{t["settings"]} · {t["subtitle"]}', W - 200)
    win = f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">' + head + "".join(p) + '</div>'
    # callouts: left column on the left edge, right column on the right edge
    left_spans = [(secs[0], secs[1]), (secs[1], secs[2]), (secs[2], secs[3]), (secs[3], secs[4]), (secs[4], y - 30)]
    right_spans = [(secs2[0], secs2[1]), (secs2[1], y2 - 108)]
    calls = ""
    for i, (a, b) in enumerate(left_spans, 1):
        calls += f'<div class="call" style="left:{ox - 34:.0f}px;top:{oy + (a + b) / 2 * SCALE - 15:.0f}px">{i}</div>'
    for i, (a, b) in enumerate(right_spans, len(left_spans) + 1):
        calls += f'<div class="call" style="left:{ox + W * SCALE + 10:.0f}px;top:{oy + (a + b) / 2 * SCALE - 15:.0f}px">{i}</div>'
    notes_top = oy + H * SCALE + 36
    n = t["sNotes"]
    notes = (f'<div class="notes" style="left:50px;top:{notes_top:.0f}px;width:720px">{note_html(1, n[:4])}</div>'
             f'<div class="notes" style="left:820px;top:{notes_top:.0f}px;width:730px">{note_html(5, n[4:])}</div>')
    page_h = notes_top + 4 * 66 + 70
    body = (f'<div class="page" style="height:{page_h:.0f}px"><h1>EzWoW - Bags <span class="badge">{t["sTitle"]}</span></h1>'
            f'<div class="lead">{t["sHead"]}</div></div>' + win + calls + notes
            + f'<div class="abs foot" style="left:50px;top:{page_h - 44:.0f}px">{t["note"]}</div>')
    return body, page_h


def find_chrome():
    cands = [os.environ.get("CHROME"), r"C:\Program Files\Google\Chrome\Application\chrome.exe",
             r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
             "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
             shutil.which("chrome"), shutil.which("google-chrome"), shutil.which("chromium")]
    for cand in cands:
        if cand and Path(cand).exists():
            return cand
    sys.exit("Chrome not found (set CHROME=<path to chrome>)")


def main(root: Path):
    root = root.resolve()
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    icon_uri = "data:image/png;base64," + base64.b64encode((root / "Media" / "Icon.png").read_bytes()).decode()
    chrome = find_chrome()
    work = Path(tempfile.mkdtemp(prefix="ezbags_readme_"))
    try:
        for lang in ("ko", "en"):
            for name, fn in (("ui", ui_page), ("settings", settings_page)):
                body, h = fn(lang, icon_uri)
                html = f'<html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{SHADE}{body}</body></html>'
                html_file = work / f"{name}_{lang}.html"
                html_file.write_text(html, encoding="utf-8")
                png = out / f"{name}_{lang}.png"
                subprocess.run([chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                                f"--user-data-dir={work / 'chrome_profile'}", f"--window-size=1600,{int(h)}",
                                f"--screenshot={png}", html_file.as_uri()],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
                print("wrote", png, int(h))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "."))
