# Vainglory（最終榮耀 v4.13.4 / Build 147219）原始檔案逆向工程筆記

> **解析範圍說明**：本筆記直接針對本機原始遊戲封裝檔（`VaingloryCE-1b-4.13.4-147219.original.apk`、`main.147219.original.obb`、`libGameKindred.arm64.original.so`，工作區總計 `3.17 GB` / `2.95 GiB`）進行唯讀二進位與結構解析；**地圖維度聚焦於經典 3v3「海希安峽谷（Halcyon Fold）」**，略過其他模式地圖。公開倉庫僅保存自製解析／修補腳本、OpenCC 轉換字典與雜湊驗證 JSON，**嚴格排除所有原始包體與解包資產**。

---

## 1. 地圖設計逆向解析：3v3 海希安峽谷（Halcyon Fold）

### 1.1 原始檔案容器與精確物理尺度
在 `main.147219.original.obb` 的 `CFF0` 場景區塊與 ASCII 探針網格中，3v3 海希安峽谷由三組核心資源定義：
- **關卡玩法拓樸容器**：`DD/DDC774FD5795DCE8ADBCFB7681446733`（內部符號 `*HalcyonFoldLevel_Base*`，`30,384 B`），掛載雙方出生祭壇、防禦塔序列、礦工／海怪刷新點、野區商店與草叢觸發器。
- **視覺場景圖容器**：`AC/ACE46221510D6CEA18EBB9D8217153E9`（內部符號 `*HalcyonFoldVisuals*`，`171,072 B`），管理靜態烘焙場景網格、礦脈光源與環境特效節點。
- **全圖光照探針與物理邊界網格**：`4C/4C4CC7477231BA630E24828C7A1B8093`（`604,037 B`，共 `4,004` 行），檔頭前兩行直接揭露海希安峽谷的精確世界座標範圍：
  - **X 軸跨度**：`[-100.00, +100.00]` → 全寬 **200.0 公尺**（左右鏡像展開雙陣營聖소與單一水平對線道）。
  - **Z 軸跨度**：`[-25.00, +55.00]` → 全深 **80.0 公尺**（長寬比精確為 **`2.5 : 1`**；`Z ∈ [-25, 0]` 為上方水平兵線走廊，`Z ∈ [0, +55]` 為向南縱深展開的對稱雙側野區）。
  - **網格解析度**：`100 × 40 = 4,000` 個採樣格，每格尺寸 **`2.0 m × 2.0 m`**。

### 1.2 「單兵線 + 下半縱深野區」垂直壓力拓樸
海希安峽谷之所以能以 6 名玩家創造極高戰術密度，關鍵在於**將傳統三線壓縮為單一水平上半線，並把所有資源爭奪與繞後動線集中在下半部扇形野區**：
1. **上半部水平單線（Single Horizontal Lane）與五層防禦塔縱深**：
   - 左右兩端為溫泉聖所（Sanctuary）與虛榮水晶（`Ability__VainCrystal__Home_Die` / `Away_Die`）。
   - 每方配置 **5 座 `CFF0` 獨立防禦塔預製體**（各約 `14.1 ~ 14.3 KB`）：外塔 `*HF_OuterTurret*`（`7C/7C2D84...`）→ 中塔 `*HF_MiddleTurret*`（`CD/CDB3BE...`）→ 高地塔 `*HF_BaseTurret*`（`CB/CB7C14...`）→ 基地雙門牙塔 `*HF_VainTurret*`（`28/28DED4...`）。
   - 單線設計消除了「邊線農兵無人交戰」的空白期；對線英雄一旦回城補裝，敵方即可迅速推線磨塔，迫使打野與輔助頻繁上下支援。
2. **下半部野區經濟鏈與三階段戰略目標**：
   - **治療與控制型野怪**：野區配置樹精營地 `*HF_Treant*`（`49/49C06D...`）與長老樹精 `*HF_ElderTreant*`（`1D/1D445E...`），具備根鬚定身領域 `*JungleMinion_TreeEnt_RootField*`，使反野追擊帶有地形風險。
   - **雙側水晶礦工（`*HF_CrystalMiner*`，`5E/5EC683...`）**：鎮守雙方後野區，提供防禦與野區守護 Buff（`Buff_JungleMinion_CrystalMiner_Defense` / `Empowerment`），防止前期被無腦入侵滾雪球。
   - **中央黃金礦工與 15 分鐘海怪轉換（`*HF_GoldMiner*` → `*HF_Kraken_Jungle*`）**：地圖正中央戰略咽喉前期由黃金礦工持續累積團隊經濟獎勵；15 分鐘後轉化為史詩級 Boss `*HF_Kraken_Jungle*`（`F3/F30335...`），擊破並捕獲後變為攻城巨獸 `*HF_Kraken_Captured*`（`95/95C3C1...`）沿單一兵線強推敵方防禦塔，成為 20 分鐘內終結比賽的明確計時器。
   - **最底部中央野區商店（`*HF_CenterBottom*` / `*Neutral_JungleMinion_Store*`）**：位於 `Z` 軸最南端雙草叢之間，讓雙方英雄無須回城即可直接將野區金幣轉化為裝備戰力——但買裝瞬間也是全圖最危險的遭遇戰爆發點。
3. **草叢伏擊與視野控制（Brush & Vision）**：
   - 兵線下緣雙草叢（俗稱八字鬍草叢）、野區三岔路口與底部商店雙草叢皆由 `Brush**` 與 `IdleBrushShadow` 控制隱身判定，搭配偵察圖騰／地雷（`*Item_VisionTotem*`）與信號彈構成完整的「埋伏 → 探草 → 反蹲」閉環。

---

## 2. 場景設計逆向解析：E.V.I.L. 引擎渲染管線與視覺層級

解析 `libGameKindred.arm64.original.so`（`42.97 MiB`）與 OBB 內 **513 支 `RSC0` 編譯 GLSL ES Shader**，可完整還原 Super Evil Megacorp 在行動端達成主機級畫質與 60/120 FPS 的場景技術組合：

### 2.1 靜態烘焙 Lightmap + 4,000 點 19-Float 動態光照探針
- **零即時 GI 開銷**：所有地表石磚、遺跡牆體與懸崖藤蔓皆使用離線烘焙高解析度多級 Mipmap 貼圖（`2048×2048` 級別），將柔和環境遮蔽（AO）、火炬暖光與礦脈青光直接烤入底圖。
- **動態單位無縫受光**：`4C/4C4CC7477231BA630E24828C7A1B8093` 儲存 `100 × 40` 組、每組 **19 個浮點數** 的空間光照探針（涵蓋球諧環境光 RGB 係數、主光方向權重與局部陰影衰減）。英雄、小兵與海怪移動時僅需依 `(x, z)` 做 `O(1)` 網格雙線性插值，即可在踏入幽暗野區時自然壓暗並染上冷青環境色，回到兵線石路時恢復暖陽受光。

### 2.2 動態漂移雲影（`CloudShadows`）與非同步戰爭迷霧（`FogOfWar`）
- **雲影系統**：引擎內建 `CloudShadows.Texture`、`CloudShadows.Scale`、`CloudShadows.Velocity` 與 `CloudShadows.Params`，在烘焙地表之上投射緩慢流動的大尺度柔和雲影，以極低貼圖採樣成本消除靜態烘焙場景的「死板塑膠感」。
- **硬體加速戰爭迷霧**：由獨立工作佇列 `DispatchQueue_FogOfWar` 結合地形視線遮擋器 `FogOfWarOccluder` 計算可見度，寫入低解析度平滑貼圖 `FogOfWar.Texture`，再於場景與角色 Shader（如 `61/61880B14BB10C615F1F69B8E89794309`）透過 `FogOfWar.TranslateAndScale` 與 `_Object2WorldMatrix` 直接調變迷霧區像素明度與彩度。
- **PCF 即時陰影**：方向光與局部聚光燈分別由 `ShadowGeneratorDirPCF` 與 `ShadowGeneratorSpotPCF`（矩陣 `Shadowing.mViewProjRow0..3`、`Shadowing.mMap`）渲染英雄腳下俐落的接觸軟陰影。

### 2.3 MOBA 戰場可讀性（Readability）色彩與明度鐵律
- **明度三分法**：`[最高明度]` 英雄血條、技能範圍指示器、發光海希安水晶礦點 ＞ `[中高明度／低彩度]` 上方單線雕刻石板路 ＞ `[中低明度／低對比冷綠灰]` 野區地面與外圍懸崖深淵。
- **陣營方向色溫錨點**：左側聖所以暖橘火炬光為主調，右側聖所以冷青工業／水晶光為主調，玩家在鏡頭平移瞬間不看小地圖也能直覺判斷推進方向。

---

## 3. 資源分配逆向解析：APK + OBB 雙軌封裝與容量配比

### 3.1 MD5 虛擬路徑雜湊檔案系統
- **原始檔案組成**：
  - 單一完整包 `VaingloryCE-1b-4.13.4-147219.original.apk`：`1,363.95 MiB`（內含 `assets/` 48,192 檔 + `lib/` 4 個 `.so` 解壓 `72.94 MiB`）。
  - 手機端 Split 結構：基礎 `phone-original.apk`（`29.08 MiB`）+ 擴充包 `main.147219.original.obb`（壓縮 **`1,329.57 MiB`**，共 **48,443 個條目**，解壓總容量 **`2,229.67 MiB`**）。
- **尋址機制**：所有資源虛擬路徑（如 `Fonts/Brandon-Regular-30.font`）經 UTF-8 `MD5` 計算轉大寫十六進位後，以 `前2碼/32碼MD5` 儲存（見 [build_patch.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/build_patch.py)），並允許 `/sdcard/Android/data/com.superevilmegacorp.game/files/Data/` 覆寫同名雜湊槽位以實現免重打包熱更新。

### 3.2 `main.147219.original.obb`（48,443 檔 / 解壓 2,229.67 MiB）精確預算表

| 資源類別（依二進位檔頭魔數分類） | 檔案數量 | OBB 壓縮大小 | 解壓後大小 | 佔比 | 架構用途說明 |
| :--- | ---: | ---: | ---: | ---: | :--- |
| **E.V.I.L. 多級 Mipmap GPU 貼圖** (`0x2aaad4` / `0x0aaaf8` 等) | ~1,650+ | ~455.0 MiB | ~1,230.0 MiB | **55.2%** | `2048²` 228 張（`608.01 MiB`，地圖烘焙與主視覺）、`1024²` 457 張（`304.69 MiB`）、`512²` 540 張（`90.02 MiB`）、`256²` 368 張（`15.35 MiB`） |
| **音訊資源**（`MP3` + `OggS` + `RIFF`） | 16,461 | 399.18 MiB | 418.69 MiB | **18.8%** | MP3 英雄語音與技能音效 16,237 檔（`354.68 MiB`）、Ogg Vorbis 背景音樂 200 檔（`46.47 MiB`）、WAV 低延遲音效 24 檔（`17.54 MiB`） |
| **`RSC0` 引擎編譯資產**（含 513 支 GLSL Shader） | 18,136 | 202.45 MiB | 407.28 MiB | **18.3%** | 3D 角色與場景網格、骨架動畫（`uniform mat4 _Bones[36]`）、粒子材質與 513 支預編譯 GLSL ES Shader |
| **二進位索引／資料區塊**（`u0=1` / `u0=0`） | 9,564 | 63.15 MiB | 95.45 MiB | **4.3%** | 輕量級數值表、碰撞／導航網格片段與動畫曲線區塊 |
| **字型資產**（TTF/OTF 字庫 + `.font` 路由描述檔） | 55+ | 29.33 MiB | 51.56 MiB | **2.3%** | 17 套涵蓋多語系 CJK 之大型 TTF/OTF 字庫 + `52B / 718B / 829B` 複合字型描述表 |
| **`CFF0` 區塊化場景／關卡／UI 節點圖** | 942 | 13.86 MiB | 16.04 MiB | **0.7%** | 以 `INST` / `PTCH` / `SYMB` 區塊描述關卡、防禦塔、野怪、主選單與 HUD 結構，體積精煉極致 |
| **ASCII / Base64 多語系字串與光照探針網格** | 20 | 3.93 MiB | 13.73 MiB | **0.6%** | 15 國語系 Base64 編碼 `.strings`（每語系 `7,329` 鍵值）及 3v3/其他地圖光照探針網格 |

---

## 4. 主選單 UI 設計逆向解析：Kindred 原生 3D/2D 混合架構

1. **無中介層原生 UI 渲染**：VG 捨棄笨重的外部網頁或 Flash 虛擬機，直接用引擎自身的 `CFF0` 節點樹（`*KindredMainMenuEffects*`、`*KindredMenuMarketMesh*`、`*KindredMenuAscensionDialMesh*`、`*KindredMenuRewardsChestLootT3*`）結合專屬 `MenuMeshCamera` 與 `MenuMeshShaderParam` 繪製 UI，達成零卡頓轉場與 3D 寶箱／造型即時展示。
2. **極致減法的視覺焦點階層**：
   - **首頁滿版英雄群像**：左上方壓印品牌標誌，左側僅保留單一「背包（`MAIN_MENU_BAG`）」英雄／造型／天賦收藏入口；右上角收納低調單色圖示列（賽事／公告／教學／設定）與玩家訪客名片；右下角放置全畫面唯一高彩度暗紅主行動按鈕 **「開始遊戲」**。
   - **扁平化 2 步開局動線**：點擊「開始遊戲」彈出深色毛玻璃卡片視窗，標題列右側即時顯示網路延遲（如 `62 ms`），下方橫向並排模式大卡（閃電戰、隨機對線戰、**3V3 `20分・排名`**、練習、單人系統機器人賽），從啟動遊戲到進入選角大廳（`DraftLobby_*`）僅需 2 次點擊。
3. **複合字型（Composite `.font`）多語系排版引擎**：
   - 如 [audit_patch.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/audit_patch.py) 與 [build_patch.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/build_patch.py) 所驗證，複合 `.font` 檔以 `52 B` 檔頭搭配 `6 ~ 7` 筆各 `111 B` 的字面路由紀錄（每筆含字級縮放、基線偏移、32 字元 TTF MD5 引用及 16 組 Unicode 起訖區段），確保英文／傷害數字維持緊湊 Brandon/Avenir 字體，同時將繁體漢字（`U+4E00..U+9FFF`）、全形標點（`U+FF00..U+FFEF`）與罕用字（如 `丟嫋拋淩眾荊闇`）精準導向完整 CJK 字庫而不產生缺字方塊。

---

## 5. 戰鬥介面 UI 設計逆向解析：雙操控相容與零中央遮擋 HUD

1. **原生雙操控架構（點觸 Tap vs 虛擬搖桿 Joystick）**：
   - 引擎同時內建 `HUDJoystickChoice_Tap` 與 `HUDJoystickChoice_Joystick`（含 `DUI::EVENT_VIRTURAL_JOYSTICK_TRIGGERED`、`JoystickBasicAttackReticle`、`JoystickBasicAttackRingIndicator`）。
   - **經典點觸模式（Tap）人體工學**：將雙手拇指最常觸碰的螢幕左右中下區域完全清空，讓玩家食指／拇指直接點選地面走位、拉動技能指向（如 `Effect_Grace_C_TargetIndicator`）：
     - **左上角小地圖**：配合 3v3 橫向 `2.5 : 1` 地圖比例設計為緊湊長方形，以獨立 Actor 節點（`*MinimapIconActor_Kraken*`、`*MinimapIconActor_GoldMiner*`、`*MinimapIconActor_BuffCamp*`、`*MinimapIconActor_SpawnCamp*`）即時標示野區計時與海怪動向，並透過 `CameraMinimapModification` 支援按住小地圖快速平移視角。
     - **左緣垂直主動道具欄**：將鞋子衝刺（`Ability__Item__HalcyonChargers`）、護盾／治療噴泉、藥水與回城垂直收攏於螢幕最左側邊緣，左手拇指微移即可瞬發主動裝備。
     - **底部正中央技能盤（`HUD_AbilityTray`）**：集中擺放 A、B、Ult 三招技能圖示，上方緊貼自身血量／能量條與狀態圖示（`hud_buffs_overlay`）；當升級點數可用時以獨立上方浮動 `+` 籤（`Effect_HUD_AbilityTab_PointReady`）引導加點，避免激戰中誤觸升級。
     - **右上戰況列與戰術 Ping 系統**：右上角整合對局時鐘（`BHUD_MatchClock`）、團隊比分與快捷戰術信號（`Effect_Ping_Danger`、`Effect_Ping_OMW`、`Effect_Ping_Rally`、`Effect_Ping_Questionmark` 及文字短語集 `*HUDQuickMessageSet*`）；右下角配置計分板（`hud_scoreboard_cross_swords`）、鏡頭鎖定切換與商店按鈕（陣亡期間自動亮起預購入口 `hud_shop_while_dead_button`）。
2. **高效率半透明裝備商店（`DHUD_Store`）**：
   - 開啟商店時採用約 80% 不透明度深黑底幕，保留邊緣戰場動態可見度（防止在底部野區商店買裝時遭伏擊卻毫無察覺）。
   - 左側垂直排列 6 大直覺分類（推薦／武器／水晶／防禦／輔助／其他），中間以高辨識圓形紅／藍／綠底圖示分欄展示初階配件（250~300G）至三階大裝（2700~3100G），左下附「快速購買」核取方塊，正下方常駐可拖曳調整主動鍵位順序的 6 格裝備盤（`hud_store_inventory_tray`），右下以醒目金字呈現即時金幣。

---

## 6. 本目錄收錄之自製腳本與驗證檔案索引

- [inspect_vg_3v3_architecture.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/inspect_vg_3v3_architecture.py)：唯讀解析原始 OBB 與 `libGameKindred.so` 之五大維度結構分析腳本。
- [vg-3v3-architecture-summary.json](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/vg-3v3-architecture-summary.json)：上述腳本對本機原始檔案執行產生之結構化驗證摘要。
- [build_patch.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/build_patch.py) / [prepare_translations.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/prepare_translations.py) / [audit_patch.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/audit_patch.py)：繁體中文化補完（312 條新英雄技能／天賦條目）與 38 組 `.font` 複合字型 Fallback 建置及字形覆蓋稽核工具。
- [manage_patch.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/manage_patch.py) / [upgrade_verified_resources.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/upgrade_verified_resources.py) / [check_startup.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/check_startup.py) / [phone.py](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/phone.py)：可逆式雜湊校驗部署與實機啟動檢查工具。
- [patch-manifest.json](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/patch-manifest.json) / [final-resource-audit.json](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/final-resource-audit.json) / [resource-scan.json](file:///E:/hd2d-scene-starter/art-lookdev/references/vainglory/resource-scan.json)：資源 SHA-256 清單、字形路由零缺失報告與 OBB 魔數統計表。
