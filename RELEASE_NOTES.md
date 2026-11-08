# v0.1.24

### 한국어
- 경매장 판매 목록의 "최근 시세"는 마지막으로 조회했을 때의 최저가를 보여 줍니다. 며칠 평균 때문에 시세가 크게 높아 보이던 문제를 고쳤습니다.
- 시세 그래프는 하루에 한 점이 아니라 조회할 때마다의 최저가를 점으로 보여 줍니다.
- 경매장 구매 창에 "시세" 버튼을 추가했습니다. 구매 창이나 판매 목록에서 고른 아이템의 시세 그래프를 옆에 보여 주며, 경매장을 열면 기본으로 펼쳐집니다.
- 시세 창에 "시세 갱신" 버튼을 추가했습니다. 경매장이 조회를 받지 않으면 잠시 후 다시 시도하라고 알려 줍니다.
- 시세 그래프에 가격이 있는 높이마다 가로선을 그립니다.
- 게임 경매장 목록에서 아이템을 고르면 구매 창과 시세 그래프도 그 아이템으로 바뀝니다.
- 여러 개가 묶인 경매의 개당 가격이 실제보다 낮게 나오던 문제를 고쳤습니다.
- 판매 목록의 체크는 체크박스를 누를 때만 바뀌고, 줄의 나머지를 누르면 그 아이템의 시세가 나옵니다.

### English
- "Recent price" in the auction sell list now shows the lowest price of the latest lookup instead of a multi-day average.
- The price graph now shows the lowest price at every lookup instead of one point per day.
- Added a "Prices" button to the auction buy panel: it shows the price graph of the item picked in the buy panel or the sell list, beside the panel, and opens with the auction house by default.
- Added a "Refresh prices" button to the price window; when the auction house refuses the query, it asks you to try again shortly.
- The price graph draws a guide line at every price level that has a point.
- Picking an item in the game's auction list now opens it in the buy panel and the price graph too.
- Fixed the unit price of auctions holding several items showing lower than it really is.
- In the sell list only the check box ticks an item; clicking the rest of the row shows its prices.
