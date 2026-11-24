# 硃萼雨庭｜迭代與 Prompt 歷史

環境使用原創銅製雨時計、石階和併合枝冠。參考明亮插畫式奇幻場景常見的層次、色感和地景閱讀性。沒有引入原神場景或遊戲資產。所有畫面均由 RTX 4080 Laptop 上的 Godot 4.7.2 Forward+ 實機渲染，1120 × 630 像素，每輪留兩張。

| 版本 | 近景 | 俯視 | 驗收後確認 |
| --- | --- | --- | --- |
| R00 | [近景](grove/r00_ground.png) | [俯視](grove/r00_overview.png) | 能讀出草地、池塘、路和雨時計。中景缺乏層次、池色過亮、配色斑駁的圓形樹冠像測試量體。 |
| R01 | [近景](grove/r01_ground.png) | [俯視](grove/r01_overview.png) | 景深和水色明顯改善。樹冠仍有塊狀重疊，路肩太空。 |
| R02 | [近景](grove/r02_ground.png) | [俯視](grove/r02_overview.png) | 細葉能被看見，樹冠色系較統一。草地與沙路邊界和輪廓更自然。池緣和地標接地仍光滑單薄。 |
| R03 | [近景](grove/r03_ground.png) | [俯視](grove/r03_overview.png) | 局部植群和沿線石燈改善視覺節奏。水色仍缺真實的岸深、濕線、沉積與不規則反射，大量樹形和遠山語彙尚未手工變體。 |
| R04 | [近景](grove/r04_ground.png) | [俯視](grove/r04_overview.png) | 三種樹形與實際根、枝、葉的開口更清楚，消除了近景上方的丸形遮擋。池面仍是鮮亮的平面。 |
| R05 | [近景](grove/r05_ground.png) | [俯視](grove/r05_overview.png) | 深水、泥岸薄層、小片岸石和實際地表接觸更可信。俯視的淺岸緣仍偏亮，池尾和土坡形狀也值得再精修。 |
| R06 | [近景](grove/r06_ground.png) | [俯視](grove/r06_overview.png) | 遠山分成較淺的近層岩丘和降對比的遠脊，西坡可見接地的短石階、矮牆與蕨叢。暖岩仍過於均勻，留有大塊岩面可加入層理變化。 |
| R07 | [近景](grove/r07_ground.png) | [俯視](grove/r07_overview.png) | 製成辨得出功能的蓄水筒、支撐和指針轉軸。舊銅的色與霧亮面不同，近景的轉軸亮點變小。 |
| R08 | [近景](grove/r08_ground.png) | [俯視](grove/r08_overview.png) | 測試更碎的濕土與沉積岸緣。連續淺亮邊退掉，但水面過於均勻。保留沉積與濕地演算，R09 回補水面的低強度變化。 |
| R09 | [近景](grove/r09_ground.png) | [俯視](grove/r09_overview.png) | 採用。東岸有可辨識的落水階與趾端石，西坡岩片依地形半埋。池心深淺與斷續水光較易讀，通行 5/5。 |

## R00 建立識別特徵

Prompt（中）「明亮插畫風的原創階坡雨園。路從前景繞過池塘左岸，水中的銅製雨時計是地標。暖砂岩、朱橘與青綠葉色分層。一條可通行路線使用實際地形碰撞。」

Prompt (EN) “Build a bright, painterly hillside rain garden with a winding left-bank route, an original brass water clock in the pond, golden sandstone and red-orange versus sage-green foliage; keep the route physically walkable.”

實作完整地形三角網格及同源碰撞、地標、野花、石牆、池面、第一層遠山。初始鏡頭由 (-7.9, 3.45, 11.8) 朝 (1.3, 2.3, -6.2)，視角 56°，俯視 53°。

## R01 修正畫面壓迫與水色

Prompt（中）「前景樹冠只做框景，留出主要通行路和雨時計輪廓。以兩層錯位遠山承接草坡，池中央較暗、岸側較淺並有柔和不規則的反射。控制曝光，保留暖色強調。」

Prompt (EN) “Frame the camera with foliage clear of both path and clock, layer two offset ridgelines, and make the pond cooler and darker with mild shallows rather than an even bright cyan fill. Lower the exposure while retaining warm accents.”

- 近鏡頭換為 (-4.8, 3.7, 12.9) 看向 (1.15, 2.07, -6.0)，51°。俯視為 (-5.2, 22.1, 19.0) 看向 (0.4, 0.45, -3.35)，48°。這兩鏡位從 R01 起固定。R00 到 R01 有鏡位變更，不能單靠這組圖推論材質或光照的獨立效果。
- 地形擴至 91 × 84 格，每格 0.79 公尺。遠山用兩排、相距約 20 公尺，天空使用程序雲。曝光 1.02 降至 0.97，環境光 0.82 降至 0.73。
- 水體深色從 RGB 線性 (.024,.235,.231) 改為 (.015,.091,.114)。增加淺深漸層與 SSR 反射，再確認水面和道路容易區分。

## R02 修正樹冠尺度與路肩

Prompt（中）「保留每棵樹一個主葉色。用立體小葉疊在可辨識的枝冠團塊上，避免零碎幾何團之間的高色差。路肩安排疏密不同的自然石、蕨叢和潮濕緩坡。樹、草、道路的尺度要各自可讀。」

Prompt (EN) “Give each tree a dominant pigment and add genuine small leaf shapes to a few coherent branch masses. Support the route with uneven edge stones, fern clusters and a sage turf texture while leaving the travel strip open.”

- 每棵樹新增約 1,480 片雙面幾何葉，加上枝冠專用色塊著色器。樹冠配色固定主色和小幅輔色，避免分散注意力。
- 導入新生成地圖集右上象限草紋。以材質混色加亮暗擾動，減少全場平滑。蕨叢每個分布中心 13 增至 19 次布置嘗試。
- 石塊與蕨叢放在路肩和池邊，半徑留出主動線。用 R01 的兩個固定鏡頭比較。

## R03 加強材質年代感與近中景連接

Prompt（中）「近看水邊，要看到散落的小片莎草、水色破碎的邊緣和收水結構。雨時計使用低飽和舊銅綠、刻度、拉桿與基座嵌石。路側三盞矮石燈讓路線在遮蔽較多時仍可讀。」

Prompt (EN) “Along the pond, add local patches of sedge and interrupted shoal highlights. Give the clock quieter verdigris with visible rim fasteners, braces and dark inset stones. Place three low stone lanterns at supporting trail turns.”

- 銅綠從 `#418f86` 改為 `#347368`，金屬度 0.18 改至 0.23。基座加 16 件嵌石、10 個拉桿和 3 條細水線。
- 莎草集中於 10 處濕地，有深根和較淺葉尖。補三盞路側矮燈。池面高光以低頻雜訊打斷，取代過於規律的亮點。
- 新增地標細節先保存亂數狀態，完成後復原，避免背景山、樹和石塊跟著變。例如在這一輪對照中，地標幾何改動可只移動地標細部，其他地物位置保持可追溯。
- Godot 實走測試以 1.76 公尺高、0.30 公尺半徑的角色碰撞膠囊完成 6 個檢查點、29.7 公尺。

## R03 審視分數與關鍵點

以下為自評，使用近景和俯視各自 100 分的六項權重。它是畫風與細節的比較尺，沒有把單張畫面轉為客觀相似百分比。

| 鏡位 | 地形 20 | 材質 20 | 物件精修 20 | 擺景 15 | 光水 15 | 玩法閱讀 10 | 合計 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 近景 | 14 | 13 | 13 | 12 | 11 | 9 | 72 |
| 俯視 | 13 | 12 | 12 | 10 | 12 | 9 | 68 |

最有效的變化有三個。先把焦點、路與遠景分開，再集中資產細節。以同一個物件上的多尺度幾何和材料變化支持近景，例如樹冠團塊上增加小葉，效果比提高每棵樹的色差更明顯。最後在資產和地面相接的位置增加岸草、岩塊及陰影線索，能同時改善近看和俯視，散灑細節的效果較弱。尚需補足精修岩層、植群物種變化、半透明岸淺和較細緻的銅件、石基接縫。

## R04 以枝根結構重做樹冠

Prompt 改寫（中）「以真實葉片疊出原創秋樹，逐株指定不同長寬比、傾向和主枝位置。橙樹的展枝向池側伸展，較高的綠樹保留分層和天光開口。使用收尖的彎幹、帶縱向紋理的樹皮和扎入坡面的根，讓近景與俯視都能辨認樹冠的支撐方式。」

Prompt delta (EN) “Replace the repeated rounded crowns with three whole-tree habits (leaning, upright and spreading) and assign each tree its own bearing, branch reach and rooting points. Build crowns as thin folded leaves attached to offset tapered branches with clear gaps. Ground each base with roots and longitudinal bark variation.”

- R02 的「少數枝冠團塊上疊幾何葉」在 R03 仍保留明顯圓團，本輪整體換成六組主枝和錯位側枝。每棵樹約 2,560 片有折面的幾何葉，五條根依局部坡高接地。加入樹皮的縱向刻紋與根部苔色。本輪只重做植群，保留相同相機、水、地標與通行設計。
- 對照結果採用。近景可透過枝層看到後方坡面，原本畫面左上突出的同色不規則塊消失，俯視可以辨識三種冠形。較薄的樹冠讓葉片較碎，未再加回實體圓冠。
- 獨立實機審視近景 74、俯視 68。

## R05 用地表高度重做水邊

Prompt 改寫（中）「從 R04 原地坪取樣每段池水深度。水線由池面遇到原有地形的位置決定，讓深水變沉、近岸進入泥色再接到濕岸。只有坡面和淺水交會的位置添加小石和弱岸緣反射，避免一圈等粗高亮水色。」

Prompt delta (EN) “Use the collision terrain’s bed heights for water depth. Let the level intersect its existing slopes, cool the deep water and change to warm sediment at the shallows. Add localized wet ground and loose stones only at real intersections, keeping the walking strip clear.”

- 改用 0.39 公尺水面網格，頂點水深取樣同一個地形高度函式。移除 R04 的橢圓 UV 深度，改用頂點深度混合藍綠深水與近岸泥色。沿物理等高水線求交，再將不等量水邊石放在各個坡腳。水體不另加碰撞。
- 採用較深而偏冷的池心和濕岸接地。俯視還可見連續偏亮淺緣及池尾角度，未把水膜做成每一處同樣的反射。
- 獨立實機審視近景 77、俯視 72。近景分項為 14／14／16／12／12／9，俯視為 13／14／15／11／10／9。

## R06 重構遠山與坡側中尺度

Prompt 改寫（中）「讓近山呈現風化淺石與草坡，遠山退成低對比的藍綠大形。手定谷口兩側山體的位置、傾角、高度與疏密。靠近玩家的坡面，用零散矮牆、嵌進地面的舊階和蕨葉交代高度，保留沙路淨空。」

Prompt delta (EN) “Lay out a staggered valley in two depth bands, with off-axis warm eroded foothills and a softer distant blue-green ridge. Rebuild cliff normals from the final geometry. Use steps, grounded wall remnants and fern overlap to introduce a second readable scale between the grass slope and the landmark.”

- 近遠岩帶由 26 件重複徑向變形量體改為 15 件分別配置的地形量體，岩體使用九層不規則截面並重新產生法線。地表由 91 × 84 格加密至 119 × 111 格，格距由 0.79 降至 0.61 公尺。西側補局部兩層矮牆和五個半埋舊階。兩鏡位維持 R01 參數。
- 兩鏡位出圖，保留分層岩帶與近坡細節。畫面仍有大面草坡和暖岩面的重複讀感，尚未達 85 分。留有後續可更換的截面及岩面調色。
- [Godot 通行複驗](grove/route_verification_r06.txt) 通過 5/5 區段，約 29.74 公尺。
- 獨立實機審視近景 77、俯視 74。近景分項 15／14／16／12／11／9，俯視 14／14／15／12／10／9。暖岩色提高遠近分帶，近景分數維持，俯視地形和擺景提高。

## R07 以可讀機構加深地標的辨識

Prompt 改寫（中）「將盤面、讀數指針和蓄水筒做成同一套雨時計機構。圓盤接到兩側三角支架，指針由銅軸固定，蓄水筒看得到加強肋和閥。半亮的擦亮銅接件和舊銅綠外殼使用不同形狀、顏色與粗糙度，鎖定相機再驗證。」

Prompt delta (EN) “Treat the dial, pointer and rain reservoir as one legible machine. Place the dial pivot in copper brackets, attach the ring with eight clamps and two triangular stays, and give the reservoir flutes, fasteners and valves. Use mottled verdigris and polished brass on components according to their wear and use.”

- 用 12 面削尖水箱、12 組加強肋、4 個閥塞和三圈鎖帶取代六層單純圓柱。盤面增加兩組三角撐與 8 個環扣，指針固定於黃銅軸。原亮球換成較小的嵌入發亮零件，保留刻度與光線方向。
- 在相同鏡位保留這輪幾何。下方水筒和盤面兩端在近景更可讀，俯視能辨認銅線條，但材料細節隨遠距減弱。池尾淺色緣、景深分離和草坡的區域變化仍具落差。
- 獨立實機審視近景 78、俯視 75。兩鏡位相對 R06 均在地標精修提高 1 分。
- [Godot 通行複驗](grove/route_verification_r07.txt) 通過 5/5 區段，約 29.74 公尺。

## R08 依實際深度分散濕線與土壤露頭

Prompt 改寫（中）「分段池岸用水深決定沉積帶寬度，再用兩個空間尺度造成局部寬窄與泥色差異。只在少數淺區保留暖色沉積，坡面以高度、斜率與方向性地質塊決定有植被的土和露出的石。讓濕土暗下來並降低粗糙度。」 

Prompt delta (EN) “Tie the width of littoral sediment to basin depth and break up its continuity with two spatial frequencies. Preserve muted ochre at occasional shallow pockets. Link exposed slope stone to elevation, directional strata and slope angle, with localized dark earth at the wet contact.”

- 在水面將原本連續的亮邊改為 0.085 至 0.34 的局部深度分界。地表濕潤遮罩以短區段噪聲調變。植被底色與露岩的混合依向、坡和高度計算，避開通行中心。
- 固定鏡位比較中，俯視不再沿整池出現均勻淺白輪廓。水面反射與波形削弱後另有平面感，R08 保留作對照，下一版保留岸線規則並補回低反差水動。

## R09 用四段落水階與露頭接地

Prompt 改寫（中）「在池東岸引水處安排四段逐級沉入水床的沖刷石階，以偏橄欖的乾石做水平帶、較暗的濕石做出水口，留不整齊的石腳。坡上三群層理石沿實際高度半埋，少量碎石與蕨葉留在遮蔽低處。深水延續藍綠色階，水光限制在短區段與淺岸。」

Prompt delta (EN) “Use four eroded spillway sills descending toward the eastern pond bed. Read the dry stone body, saturated inset crests and submerged toe stones as a single drainage detail. Embed three groups of low strata in actual sloping ground and restore sparse, low-contrast shallow caustics over the interrupted wet line.”

- 東岸增加四道梯級水石、兩側不連續的抱石、趾端埋石與蕨葉。新增西坡及東岸三群地層露頭，每片依地面高度下埋，較低處有碎石接腳。新增場景物件未變更主路或碰撞網格。
- 採用 R09。俯視能分辨坡側接地與池岸次級構造，近景還可讀出雨時計為主景。池面低反差亮斑回來，局部水域仍呈現偏平的反射。維持 R07 近景與俯視相機，兩張 1120 × 630 由 RTX 4080 Forward+ 實際渲染。
- [Godot 通行複驗](grove/route_verification_r09.txt) 通過 5/5 區段，約 29.74 公尺。85 分尚未證實。

## R10 分層池床與磨蝕步道

Prompt 改寫（中）「維持雨時計、秋葉樹冠與蜿蜒步道的焦點關係。依同一片碰撞地形塑造兩階池床，用非均勻岸線、潮濕露岩與露出砂土的碎石鋪面接合池岸和步道。草坡先讀成成片的暗綠和鼠尾草綠，再顯露近處紋理。用視角控制水面倒影，俯視讀出水深。」

Prompt delta (EN) “Keep the water clock, autumn foliage and winding approach in the same hierarchy. Sculpt a two-stage pond bed within the collision terrain and connect uneven wet banks and small sandstone shelves to worn, half-buried paving. Read the hillside in broad sage and deep green first. Use a view-dependent reflection and visible depth toward the shore.”

- 橢圓池底加入兩個深度區段和方向性變化。池側以實際水線布置半埋扁石，步道兩個轉折加入零碎低矮石板。地表減少高頻綠色斑點，依使用痕跡區分通行中心和路肩。水色增加視角反射、泥底與局部淺水亮紋。
- [近景](grove/r10_ground.png) 前景暗部的綠色層次和砂土轉折改善。[俯視](grove/r10_overview.png) 仍能看見池面大面偏單色、北側地表反覆起伏及淺黃石間距較固定。獨立審視近景 82、俯視 80。
- Godot 4.7.2 通行 5/5 區段，約 29.74 公尺。

## R11 將風化岩帶嵌入兩側坡地

Prompt 改寫（中）「用不對稱的斜向層理岩連接樹帶、坡面和池邊擋土基腳。大型岩面承接位置與陰影，較小的落石引向地表。岩縫偏冷，苔色留在朝上的疏散區域。遠處保有霧的分層，近處光從秋樹的枝葉下穿過。」

Prompt delta (EN) “Inset asymmetrical, slanted bedrock bands into both slopes beneath the trees. Lead the ridge shapes into smaller talus and cooler retaining-wall footings. Use interrupted seams and upward-facing lichen. Preserve the atmospheric separation of the far peaks and let the close shade retain contrast.”

- 分別造出西坡、出口和東側的 14 塊岩體，使用七道不等厚的方向性截面，依地形高度埋入。擋土牆下層換成帶舊痕的石材，岩帶下方加少量落石與蕨叢。延後深度霧起點，直射色溫略往中性移動。
- [近景](grove/r11_ground.png) 兩側的岩面具分層接地。[俯視](grove/r11_overview.png) 西側大岩有局部形體改善，左坡接腳與池緣關係仍弱。獨立審視近景 82、俯視 80。這一輪的收益侷限在兩側，下一輪改池的形狀和水中層次。
- Godot 4.7.2 通行 5/5 區段，約 29.74 公尺。

## R12 以灣岬讓東岸進入池中

Prompt 改寫（中）「在東岸溢流階前方，以同一片地形推入一座低矮的濕地岬，讓水與陸交界形成狹灣。沿地形折線排置薄岩層和受遮擋的鳶尾，水中葉盤只留在有足夠水深處。以樹冠方向控制池中的暗反光，保留較遠處清晰的時鐘輪廓。」

Prompt delta (EN) “Extend a low terrace into the southeast basin using the terrain bed itself. Shape an inlet between the iris-covered ledge and the eastern spillway. Reserve floating leaves for deep enough water. Project broken canopy reflections and keep the clock silhouette clear across the pool.”

- 岬角採斜轉橢圓高度曲面，水面和碰撞地形讀同一高度，薄岩層和鳶尾沿岬角配置。修掉池外浮葉，西側矮牆上緣做局部下陷。水材質採相機方向估算三處岸樹倒影，保留較暗池心和局部沉積色。
- [近景](grove/r12_ground.png) 東側地形已與落水階形成一條岸段，陰影變化仍不足。[俯視](grove/r12_overview.png) 確實打破原本平滑輪廓，水深與接腳仍偏硬。獨立審視近景 82、俯視 83。
- [通行](grove/route_verification_r12.txt) 5/5 區段，約 29.74 公尺。

## R13 測試橫脈山形、局部種植與側照

Prompt 改寫（中）「池邊大面積草地先分成受遮蔽的根區、向光的坡腳和積水的苔線。以較窄的側向日光落在轉折處。遠景保留冷色疊山，近山採連續的斜向頁岩階鼻，減少同色圓丘。」

Prompt delta (EN) “Give the plain grass regions rooted shade, light on exposed feet and moisture at the bank. Shift the sun to throw readable oblique shadows across the turns. Test overlapping slanted beds in the middle distance over a quieter gray-green ridge.”

- 沿確定的十個地形區域布置實體小葉與碎石，保留水面、主動線和草坡高低。提高畫面局部色差，改變光向與陰影。遠景位置重新排序，中景測試同基礎截面的方向性頁岩。
- [近景](grove/r13_ground.png) 轉折處有陰影與葉色層次。[俯視](grove/r13_overview.png) 中景岩體更僵硬，右上透出透白空隙。獨立審視近景 82、俯視 79。側照及岸坡草簇留用，岩體需再做自然錯縫、減少亮度及補邊界。
- [通行](grove/route_verification_r13.txt) 5/5 區段，約 29.74 公尺。

## R14 把真實沉積床帶進水邊

Prompt 改寫（中）「池心保留藍綠深度。岸邊的透明度由同一池床高度算出，露出砂土和完全沒入水中的碎石。石與苔地分層，水膜按視角混合柔和倒影。修正右上空白，削去幾塊近山相同的平頂。」

Prompt delta (EN) “Keep the teal basin deep. Derive water transparency from the same bed height so the submerged cove shows sediment and stones. Mix surface reflection by view angle. Close the upper-right background gap and erode the repetitive cliff crowns.”

- 為地表著色器傳入水面高度，增加淹水泥地的色階。調整淺水混合由水深和反射角共同決定，灣岬下方放入高度可見的全淹碎石。補右側背景邊界，拉出岩頂高差。
- [近景](grove/r14_ground.png) 池岬下方露出褐綠淺水。[俯視](grove/r14_overview.png) 背景已連續，池心仍缺乏方向性的水光。岩崖大面仍有相似折線。獨立審視近景 82、俯視 83，材質可保留，尚未達成雙鏡門檻。
- [通行](grove/route_verification_r14.txt) 5/5 區段，約 29.74 公尺。

## R15 回復自然山形，測試下游水紋

Prompt 改寫（中）「上方山形改成較大、彼此掩疊的自然岩丘，斜向層理留在低矮坡腳。用較冷的岩色收起背景。步道露出啞光壓實砂土，地面樹影細緻但不抖動。池景有深處水色、樹冠倒影和受保護的淺緣。以出水方向帶起落水階下游的水紋。」

Prompt delta (EN) “Restore overlapping broad hill masses and confine slanted exposed beds to lower feet. Cool the distant stone. Use compacted sand and clearer branch shadows along the path. Keep actual sediment visible in the shallows, while adding darker pool zones and an intentional direction for ripples below the stepped outlet.”

- 重新分配較高岩丘、低坡岩層及更後方的冷色遠景，補上西側埋入的接腳。路面取樣砂土，降低光源角直徑，讓影邊更清楚。加入隨出水方向展寬的局部水紋、池床深度與樹影遮蔽。
- 地景先單獨檢查，近景 82、俯視 83，光影與岸邊定位改善。整合後的 [近景](grove/r15_ground.png) 和 [俯視](grove/r15_overview.png) 顯示成列白色波紋過多，與雨時計爭焦。保留中遠地景、透明淺層和局部反射，下一輪專修波紋。
- [通行](grove/route_verification_r15.txt) 5/5 區段，約 29.74 公尺。

## R16 壓低落水反光，採用

Prompt 改寫（中）「雨時計優先。池底及樹冠倒影先交代大面的冷暖與深淺。落水階下只留兩三組破碎短紋，離開階口便變暗、變疏，保留岬角砂底與岸草的實際接觸。用相同相機檢查時鐘和步道影色。」

Prompt delta (EN) “Keep the water clock first in the composition. Let the visible bed and canopy reflection describe broad depth and temperature. Use only a few short, interrupted ripples beside the step outlet, fading into weaker, sparser marks downstream. Preserve the cove sediment and the physical shoreline contact. Review at the same cameras.”

- 降低落水弧強度、圈數與長距離佔比，同時保留兩段深度、透明度、池中方向性反射和原有效果。局部反光回到溢流階周邊。[近景](grove/r16_ground.png) 和 [俯視](grove/r16_overview.png) 均為 Godot 4.7.2 Forward+ 實際渲染，1120 × 630。
- 獨立目視審視近景 **85**、俯視 **86**。按地形 20、材質 20、物件 20、擺景 15、光水 15、可讀性 10 分計，近景為 16／16／16／12／15／10，俯視為 16／16／16／15／15／8。從 R09 的 80／77 改善。俯視水面仍見局部角狀影色，中遠景的岩面色相差異可再拉開。
- [通行](grove/route_verification_r16.txt) 5/5 區段，29.74 公尺。沿用 R01 固定鏡位與既有路線。

### 這組 Prompt 改寫留下的規則

- 先讓樹根、坡腳、留白和地標支撐動線。近景靠枝影與地面材質引路，俯視要看得見路形、岸形與支撐結構。R11 增加岩塊時分數持平，R12 把低岬接入實體池床才改變俯視的整體關係。
- 從同一個高度來源決定地形、碰撞、水深、濕土和放置植物的位置。岬角由實際池床長出，薄石、濕地、砂底與水的相對高度在兩個鏡位都讀得通。
- 把高反差聚在用途明確的位置。R13 整齊亮崖和 R15 成排亮波都從雨時計搶走視線。R16 保留背山、側光與水床在大面的作用，只在落水階附近留下衰減短紋。
