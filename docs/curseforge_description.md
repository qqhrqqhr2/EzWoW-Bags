<!--
CurseForge summary (EN): All-in-one bag window by category with item purpose labels, alt bags and banks, auction prices, and automatic junk selling and repair at vendors.
CurseForge summary (KO): 분류별 통합 가방, 아이템 용도 표시, 부캐 가방·은행 보기, 경매장 시세, 상점 회색 잡템 자동 판매·자동 수리.
-->

# EzWoW - Bags

**English** · [한국어](#한국어)

A bag addon for WoW Forever that shows your bags and bank in one window, grouped by category. Icons carry a short purpose label, you can look into your other characters' bags and banks, saved auction prices appear in tooltips and category totals, and grey junk is sold and gear repaired as soon as you open a vendor.

![Bag window](https://raw.githubusercontent.com/qqhrqqhr2/EzWoW-Bags/master/docs/images/ui_en.png)

![Settings window](https://raw.githubusercontent.com/qqhrqqhr2/EzWoW-Bags/master/docs/images/settings_en.png)

*Mock-ups rebuilt from the window sizes, coordinates, colours and strings in the addon code. Item art is simplified; names and prices are made up.*

## Features

### One bag window
- Bags (and the bank) in one window, grouped into categories: equipment, consumables, materials, quest items, recipes, junk and your own custom categories.
- Three views: **Sections**, **Grid** and **List**; sort items by name or quality and categories by name or size.
- Category list on the left: click to show one category, right-click for its menu, drop an item on a custom category to put it there.
- Category headers fold and unfold; right-click to pin, hide or disable, or to move the whole category to the bank, mail, trade or a vendor one stack at a time.
- Bag icons with free slot counts (keyring, bags 4·3·2·1, backpack); drop an item on a bag to put it there.
- Opens with **B** and the bag buttons (can be turned off).

### Item icons
- Purpose labels on the icon: **BoE**, **Q** (quest), **Recipe**, and the professions that use a reagent.
- Item level on equipment, a green dot on new items, cooldowns.
- **Right-click uses** potions, food and the Hearthstone without blocked-action errors, also in combat.

### Search
- Search by name, type or purpose. Supports `ilvl>=50`, `rarity=rare`, `AND / OR / NOT`, brackets and quotes.
- Save a search as a custom category.

### Alts and auction prices
- Open another character's bags and bank on the same realm, read only.
- **Prices** tab: full auction house scan or a scan of just your bag items. Prices show in tooltips and as a total (≈) on each category.
- Tooltips list the professions that use the item and how many each character holds in bags and bank.

### Vendor (on by default)
- **Auto-sell grey junk**: every grey item in your bags is sold when a vendor opens, and the gold is reported in chat.
- **Auto-repair gear**: all worn and carried gear is repaired at a vendor who can repair (skipped when you do not have enough gold).
- **Hold Shift** while opening the vendor to skip both this time.

## Settings (`/ezbags settings`)
- **General**: language (automatic + 8 languages), replace default bags, combine stacks.
- **Merchant**: auto-sell grey junk, auto-repair gear.
- **Item icons**: purpose labels, equipment levels, individual free slots, new item category.
- **View**: view, item sorting, category sorting, items per row, category columns, icon size, window scale, opacity.
- **Categories & window**: restore hidden categories, reset position, create a custom category from a name and a search.

## Working with other EzWoW addons
- Auto-sell and auto-repair moved here from **EzWoW - Tooltip**. Your choices there are carried over once; while Bags is enabled, Tooltip leaves these to Bags.
- With **EzWoW - Tooltip** enabled, Tooltip collects the auction prices and Bags shares them.

## Commands
- `/ezbags` or `/ezb` — open or close the window
- `/ezbags bank` — show the saved bank
- `/ezbags settings` — settings
- `/ezbags scan` — full price scan while the auction house is open

Languages: English, 한국어, Deutsch, Français, Español, Русский, 简体中文, 繁體中文.

---

## 한국어

WoW Forever용 가방 애드온입니다. 가방·은행을 하나의 창에서 분류별로 보여 주고, 아이콘 위에 아이템 용도를 표시하며, 다른 캐릭터의 가방·은행을 볼 수 있습니다. 저장한 경매장 시세를 툴팁과 분류 합계에 보여 주고, 상점을 열면 회색 잡템을 팔고 장비를 수리해 줍니다.

![통합 가방 창](https://raw.githubusercontent.com/qqhrqqhr2/EzWoW-Bags/master/docs/images/ui_ko.png)

![설정창](https://raw.githubusercontent.com/qqhrqqhr2/EzWoW-Bags/master/docs/images/settings_ko.png)

*애드온 코드의 창 크기·좌표·색상·문구로 재현한 예시 화면입니다. 아이템 그림은 단순화했고, 이름과 시세는 지어낸 예시입니다.*

## 기능

### 통합 가방 창
- 가방(과 은행)을 한 창에서 장비·소모품·재료·퀘스트·제조법·잡동사니와 사용자 분류로 나눠 보여 줍니다.
- **분류 · 전체 · 목록** 세 가지 보기, 아이템 정렬(이름·등급)과 분류 정렬(이름·크기).
- 왼쪽 분류 목록: 누르면 그 분류만 표시, 오른쪽 클릭은 분류 메뉴, 아이템을 끌어 놓으면 사용자 분류에 넣기.
- 분류 머리글은 접고 펼칠 수 있고, 오른쪽 클릭으로 고정·숨김·끄기, 은행·우편·거래·상인으로 한 묶음씩 옮기기.
- 가방 아이콘과 빈 칸 수(열쇠고리, 가방 4·3·2·1, 배낭). 아이템을 가방 아이콘에 끌어 놓으면 그 가방에 넣습니다.
- **B 키**와 가방 버튼으로 열립니다(끌 수 있음).

### 아이콘 표시
- 아이콘 위에 용도 표시: **비귀속**, **퀘**, **책**, 재료를 쓰는 전문 기술.
- 장비 레벨, 새 아이템 초록 점, 재사용 대기시간.
- **오른쪽 클릭으로 사용**: 물약·음식·귀환석을 애드온 차단 오류 없이, 전투 중에도 씁니다.

### 검색
- 이름·종류·용도로 찾습니다. `ilvl>=50`, `rarity=rare`, `AND / OR / NOT`, 괄호, 따옴표.
- 검색식을 사용자 분류로 저장할 수 있습니다.

### 부캐와 경매장 시세
- 같은 서버 다른 캐릭터의 가방·은행을 보기 전용으로 엽니다.
- **시세** 탭: 경매장 전체 수집 또는 가방 아이템만 조회. 시세는 툴팁과 분류 합계(≈)에 나옵니다.
- 툴팁에 쓰이는 전문 기술과 캐릭터별 가방·은행 보유 수를 보여 줍니다.

### 상인 (처음부터 켜짐)
- **회색 잡템 자동 판매**: 상점을 열면 가방의 회색 아이템을 모두 팔고 받은 금액을 채팅창에 알려 줍니다.
- **장비 자동 수리**: 수리할 수 있는 상인이면 착용·가방의 모든 장비를 수리합니다(골드가 모자라면 건너뜀).
- 상점을 열 때 **Shift**를 누르고 있으면 이번에는 둘 다 건너뜁니다.

## 설정 (`/ezbags settings`)
- **일반**: 언어(자동 + 8개 언어), 기본 가방 대체, 묶음 합계 표시.
- **상인**: 회색 잡템 자동 판매, 장비 자동 수리.
- **아이콘 표시**: 아이템 용도, 장비 레벨, 빈 칸 개별 표시, 새 아이템 분류.
- **보기**: 보기 방식, 아이템 정렬, 분류 정렬, 줄당 칸 수, 분류 열 수, 아이콘 크기, 창 크기, 불투명도.
- **분류·창**: 숨김·꺼진 분류 복원, 창 위치 초기화, 이름 + 검색식으로 사용자 분류 만들기.

## 다른 EzWoW 애드온과 함께 쓰기
- 자동 판매·수리는 **EzWoW - Tooltip**에서 이 애드온으로 옮겨 왔습니다. Tooltip에서 고른 설정을 한 번 가져오고, Bags가 켜져 있으면 Tooltip은 이 기능을 쓰지 않습니다.
- **EzWoW - Tooltip**이 켜져 있으면 시세 수집은 Tooltip이 맡고 Bags는 그 가격을 함께 씁니다.

## 명령어
- `/ezbags` 또는 `/ezb` — 창 열기/닫기
- `/ezbags bank` — 저장된 은행 보기
- `/ezbags settings` — 설정창
- `/ezbags scan` — 경매장이 열린 상태에서 전체 시세 수집

지원 언어: English, 한국어, Deutsch, Français, Español, Русский, 简体中文, 繁體中文.
