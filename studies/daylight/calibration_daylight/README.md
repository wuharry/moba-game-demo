# P16-D 日照草坡與連續崖段

使用 Godot 4.7.2 匯入解壓後的 `project.godot`，按 **F5** 開始。開場是清亮午後。按 **Tab** 切至角色眼高，用 **WASD** 步行、滑鼠轉向。**Esc** 釋放滑鼠，**1** 回固定主鏡位。

| 按鍵 | 用途 |
| --- | --- |
| 7、J、6 | 切換日照、午後、薄暮三個美術時段。 |
| [、] | 在 12:00 至 18:30 之間前後移動半小時；光向、補光與天空依本場景的時段參數內插。 |
| F2、F3 | 檢查草群近景、岩石近景。 |
| F1 | 切換岩與樹冠的柔邊分階，觀察受光轉折。 |

先看固定站位的草高、土色、遠山剪影，再到玩家眼高及斜俯站位確認草根、崖腳和林緣。原作參考時刻及天氣未知。[原作與兩版同站位](review/P16/reference_comparison.jpg) · [草與岩](review/P16/material_comparison.jpg) · [玩家與斜俯](review/P16/play_comparison.jpg) · [D 版避開遮擋的崖腳運鏡](review/P16/captures/cliff_walk_safe.mp4) · [歷史固定軌，同一場景](review/P16/captures/cliff_walk.mp4)

[三時段](review/P16/lighting_comparison.jpg) · [14:00、16:00 與 17:00 的同站位](review/P16/hour_comparison.jpg) · [本輪評閱](review/P16/VISUAL_REVIEW.md) · [本輪 prompt](review/P16/PROMPT.md) · [重拍 17 張固定鏡位及兩段運鏡](review/P16/REPLAY.md) · [P15-C 基準](review/P15/VISUAL_REVIEW.md)

本版校準的是《原神》日照草坡。角色、水體、建築以及《鳴潮》的地區畫風各自需要對應素材、原作參考和實機檢驗。私人研究包保留使用者參考圖和歷次評閱。各項可確認的做法見[方法與證據](review/P16/METHOD_SCOPE.md)，新場景接續製作見[主提示](../review/refinement/MASTER_PROMPT.md)。

P16-D 沿用 P16-C 的場景幾何及固定鏡位，另加一條修正機位的崖腳運鏡，用來從連續畫面檢查構圖與遮擋。歷史固定軌仍可用於跨版本對位，兩片都收在包內。

- P17-C 改變草坡與岩台接合，在獨立 MOBA 跟隨相機與原始固定鏡位複評。記錄在 calibration_daylight/review/P17/。

## P18 MOBA 材質比較

執行場景後按 M 進入實際 MOBA 遊戲視角，按 N 比較風格化 A 和較具模型質感的 B。按 1 回固定主鏡。試走站位及重拍請見 [P18 重拍](review/P18/REPLAY.md)。

## P29 左後壁與崖腳

目前可玩檢查點為 P29-C。按 1／M 看固定鏡與正交遊戲鏡，7／J／6 辨別光照。查看[調整記錄](review/P29/PROMPT.md)、[多視角評閱](review/P29/VISUAL_REVIEW.md)及[重拍方式](review/P29/REPLAY.md)。

## P30 光照草坡與左後崖

以 P30-B 為可玩接續點。1／M 切固定鏡與正交跟隨鏡，7／J／6 檢查光照。查看[本輪指令](review/P30/PROMPT.md)、[多視角複評](review/P30/VISUAL_REVIEW.md)及[重拍指令](review/P30/REPLAY.md)。

## P31 林線與近草輪廓

可玩接續點 P31-C。1 為固定鏡、M 為正交遊玩、N 比對材質。7／J／6 為日照、清亮午後、薄暮。另附 [P31 複評](review/P31/VISUAL_REVIEW.md)、[試拍 Prompt](review/P31/PROMPT.md)和[重拍](review/P31/REPLAY.md)。
