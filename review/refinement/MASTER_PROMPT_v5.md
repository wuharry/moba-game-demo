# 場景美術主 Prompt v5

用途是讓製作 Agent 在已有 Godot 專案做一張可以走動、用近地面視角和 MOBA 視角檢驗的原創環境。開工前輸入風格分支、地形、主要路線、地標功能、參考畫面與兩台固定相機。

## 共通製作指令

1. 以連續地面先畫主路、側路、通行淨空和地標視線。預先放好近景與 MOBA 相機。建立至少四個步行檢查點。
2. 先完成近、中、遠三種尺度的輪廓。在近景選一至兩處能提供遮擋和尺度的構件。把地標放在中景，以局部色相、形狀或亮度區隔。背景降低紋理反差，把主路轉折留在玩家鏡頭看得到的地方。
3. 把場景造型分成三個尺度。大尺度看地形和建築剪影。中尺度補護岸、平台、截水溝、植物群落和破損。小尺度只集中在入口、轉角、裂隙和設備接點。
4. 地標給出它為什麼在這裡的視覺線索。至少安排兩個與功能相連的中尺度輔件，例如導管、護岸和控流；雨園可安排集水槽、階地和沉水植物。地標腳底要看得到接地影和結構接點。
5. 地面用筆觸、尺度不同的隨機取樣、邊緣遮罩和低頻色差做過渡。把「乾燥路面→濕邊→泥苔」做成有寬度且有起伏的帶狀區域。控制大區域圖樣，避免在俯視出現鏡像十字或硬邊。
6. 植被只在有理由的地方集簇。依潮線、岩縫、護牆背風面或路邊分配高、中、低三種形狀。近鏡避開規律的十字卡感，以真葉片、分支或多面葉片改善輪廓。
7. 水面區分水深色、流線和岸邊反應。大面藍色只作輔色，泡沫與水花集中在落差與碰撞點。前景亮斑應在固定相機檢查，必要時調粗糙度和主光方向。保留足夠亮度讓路線可讀。
8. 主要地標優先使用有 UV、倒角和可編修結構的 3D 資產。進 Godot 檢查模型比例、實際渲染、材質、碰撞和步行，保存近景與俯視截圖。
9. 每輪先指出一個畫面問題，寫下 Prompt 變更和實際修改，再用同畫面重渲染。保留回退或無改善的版本。使用 100 分分項表評估近景和俯視。兩個鏡位都至少 85 才標達標，逐項保留剩餘缺口。物理測試另外記錄。

## 分支 A　日照與手繪自然環境

- 用可辨識的草地、淺石與偏暖的建築，保留柔和的冷色陰影和遠景色階。
- 大葉形、枝幹和花簇應看得出植物種類。樹冠與地形形成視覺框景，避免蓋住主路或地標輪廓。
- 明亮環境仍須看得到材質。先處理高光過曝與遠山對比，再加局部花草和磨損。
- 日藤庭院以日輪門、引水、砂岩和矮廢墟組成。硃萼雨庭以半月泉池、階地與雨時計組成。

## 分支 B　冷濕工業遺跡

- 用冷色岩面、霧和深色濕地把遠近拉開，以低比例銅鏽和冷青光標記仍存在功能的設備。
- 岩壁先立不同傾角的大片石層，再做底部碎落和縫隙積水。工業部件沿水路、維修區和關鍵接點分組。
- 保留足夠冷暖與亮暗區隔。只在設備、路線訊號和受光濕面出現窄高光。
- 北盆地壓力站以調節器和截流渠組成。潮鎖棧岸以濱海蓄水、取水機構、堤岸和通行甲板組成。

## v5 從實機紀錄保留下來的製作指令

- **固定先交剪影。** 遠山做成連續谷坡與交疊稜線。三棵主樹要能靠主枝、有空隙的樹冠或不同偏心方向辨識。用黑剪影看一遍，再上對比和貼圖。
- **地標各接至少一處可理解的支撐與流程。** 先擺低護牆、支柱、台座、階地、集水位置或輸送管。確認從俯視能辨識與主路、岸線或高差接在哪裡。
- **地面材質的接縫要過渡。** 以高度、實際岸線、路徑和濕區共同控制。改地表或水時，特別檢查俯視的鏡像紋、硬邊、長條反光和高頻波紋。水深與泡沫留到確定有位置依據後才畫。
- **尺寸與亮度都從密度分工。** 大輪廓用少量不對稱的形體，中尺度交代地點用途，微細節集中在水腳、凸角、根部和操作點。讓青光、暖破光和花簇輪流工作。從近景和俯視查找白草、硬亮地坪或亮色裝飾搶走主景。
- **逐版重跑並可回退。** 比較時固定相機、種子、解析度。若攝影機有改動，另記原因，畫質分數不直接歸功資產。除了引擎錯誤，還目視查有沒有白料、遮擋、穿透或地圖邊界露縫。把效果較差的圖和原因一起保存，下一輪只帶回可驗證的部分。

## 每輪記錄欄

`場景／版本｜畫面問題與鏡位｜從 Prompt 移除或改寫什麼｜實際幾何、材質或擺景變更｜渲染檔｜分數或檢視結果｜保留／回退｜下一個仍可見的缺口`

## 地面貼圖生成 Prompt 原文

> Generate an ORIGINAL technical base-color atlas, 2 by 2 image, no render scene. The four rectangular panels must meet exactly at the center horizontal and vertical line, no dividers, no fonts, no border or watermark. Each is a continuous flat material, viewed straight down orthographically, high quality illustrated environment game painting for fantasy 3D. Upper left: painted mossy earth, dark mottled bluish gray brown mud below very irregular seafoam green and olive creeping ground moss islands, quiet sparse natural grit, muted hue. Upper right: dense painted sunlit sage and fern green alpine grass ground material, irregular soft streaks of ochre ocher clay and broad leafy texture, natural large scale painterly variation, no individual outlined plants or flowers. Lower left: weathered dark cool-gray sealed aggregate concrete, gritty and faded teal, subtle mild dark water stains and orange mineral specs, NO large outlines, no tiles or text. Lower right: light warm subtle washed sandstone masonry albedo with dusty aggregate, subtle soft beige and olive variation and intermittent fine grain, no mortar, tiles, casting or objects. No directional lighting, shadows, painted light reflections, no cast leaves, no visible horizon. All four clean reusable painterly texture data. Rich detail at multiple scales but damp restrained contrast, for a high end anime fantasy game art direction. Exact square overall atlas.