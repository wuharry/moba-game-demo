# 後續場景美術與驗收標準

建置新場景前，從 [主 Prompt](MASTER_PROMPT.md) 取用對應分支，寫下場景用途、參考畫面、地標功能、主路與側路、預計檢查點及固定雙鏡位。場景地形、建築和角色使用原創或有授權的資產。風格判讀沿用 [逐輪歸納](COMMON_FINDINGS.md) 的有效做法。

## 兩條風格分支

| 分支 | 造型與光色 | 現有場景的功能關係 |
| --- | --- | --- |
| 手繪日照 | 明亮草地、暖淺石、柔冷影。樹枝方向和冠形各有辨識度，遠景以連續山稜與低反差色層表現深度。 | 日藤庭院的日輪門、引水和砂岩階地形成開闊庭院。硃萼雨庭的雨時計、取水階和半月形池岸形成較收束的林間雨園。 |
| 冷濕遺跡 | 冷色沉降岩面、陰影與深色濕區拉開遠近。銅鏽、水痕和青光集中在設備與路線節點。 | 北盆地壓力站的調節器、截水渠與連續岩谷相接。潮鎖棧岸的取水機構、分層潮棚與檢修甲板沿岸線分布。 |

## 共通建置順序

1. 畫出主路、側路、出生點、路線淨空與第一個可見地標。採連續地形、緩坡或淺灘連接通行區。先固定近景與俯視兩台驗收鏡頭，再驗證角色可踩的底面和各路線的接續。
2. 先用大形確立前、中、遠三層。相鄰山體和樹冠各有傾向、高低與間隙。必要時用近處岩面或樹群框景，主路轉折和地標輪廓在兩個鏡位都要讀得到。
3. 依地標用途安排支撐、踏步、進出水或維修面，至少用兩件中尺度部件交代結構如何運作。護岸、石階、柱腳和灌木群沿實際高差與接縫落位。俯視先看區塊分工，近景再查倒角、接地、材質質感與重複節奏。
4. 依高度、岸形和流向繪製乾濕過渡。讓材質的低頻底色維持大塊面，小磨損落在水腳、根部、迎風邊和使用點。植物在岩縫、遮蔭、岸緣或路的轉角集簇。水分深淺，流線跟地形走，泡沫集中於落差和受阻處。
5. 套用專案既有手繪岩石、植被、地表圖集及對應分支的 shader 作起點。新的主地標使用有可編輯結構和 UV 的模型，檢查 Godot 中的材質、比例、碰撞與影子。保留 Blender 作者檔和授權資訊。
6. 每輪以較弱鏡位的可見問題決定改動。修改前記下問題和本輪 Prompt，修改後附同鏡位比較與取捨。每輪欄位沿用主 Prompt，完成後把可在其他場景驗證的共同點寫回 [逐輪歸納](COMMON_FINDINGS.md)。

## 固定鏡位與步行驗證

每張圖在 `refinement_gallery.gd` 的 `LOCATIONS` 有一個固定且唯一的場景 ID。場景需提供 `review_views()` 的近景和俯視，以及完整的步行檢查點。版本比較固定相機位置、視野、種子、光照條件及 1120 × 630 解析度。若鏡位基準必須變更，記錄原因並以新相機補拍基線。近景和俯視皆用實際 Forward+ 渲染，檢查失效材質、穿透、亮度失衡、遮擋及地圖邊界露縫。主路與區域轉接再用角色走測，確認碰撞、寬度和坡度。

在專案根目錄使用 PowerShell。令 `$godot` 指向本機 Godot console 執行檔。每輪選用新的證據目錄，將 `candidate` 換成實際版本識別。

```powershell
$evidence = 'review/refinement/candidate'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
& $godot --path . --windowed --resolution 1120x630 --fixed-fps 60 -- "--gallery-capture=$evidence"
if ($LASTEXITCODE -ne 0) { throw 'Gallery capture failed' }
& $godot --headless --path . --fixed-fps 60 -- --gallery-walk | Tee-Object -FilePath "$evidence/route_verification.txt"
if ($LASTEXITCODE -ne 0) { throw 'Gallery route check failed' }
```

選定版用同一個 Godot 專案的預設值擷取四圖；新增場景後一起渲染、走測和評分。逐輪工作可用 `--gallery-map=0` 等參數選單圖。若有北盆地供電或阻擋行為改動，另跑 `--headless --path . --scene res://station.tscn --fixed-fps 60 -- --station-test`。

## 評分與 Git 門檻

| 評分項 | 滿分 | 檢查內容 |
| --- | ---: | --- |
| 地形 | 20 | 剪影、海岸或池岸、高差、構圖與區域分工 |
| 材質 | 20 | 筆觸、表面尺度、底色、接縫和乾濕過渡 |
| 資產品質 | 20 | 地標及支撐結構、可辨識形體和近距離做工 |
| 擺景 | 15 | 植被與物件的功能位置、疏密、接地與視線 |
| 光影與水 | 15 | 曝光、層次、局部反射、流向和入水結構 |
| 可讀性 | 10 | MOBA 路線、轉折、主要區域和地標辨識 |

每個項目以 0–5 級人工評閱，乘以該項滿分再除以 5。0 級為缺失，1 級為灰模級，2 級為基本可辨但薄弱，3 級為風格和用途初步成立，4 級為大致完成且仍有可見差距，5 級為接近同用途參考的完成度。逐鏡保留分項與改動理由。85 是這份表的完成度門檻。每張圖的近景與俯視各自計分。

`release_review.json` 記錄選定版。`capture_dir` 指向證據目錄，`route_sha256` 為 `route_verification.txt` 的 SHA‑256，`scenes` 依場景 ID 收錄 `version`，以及 `ground`、`overhead` 各自的 `score` 和 PNG `sha256`。影像檔名沿用 `<scene>_ground.png` 和 `<scene>_overhead.png`。證據用 `Get-FileHash` 計算 `SHA256`。完成實機擷取與評閱後，以同一版來源計算 `source_sha256`。

```powershell
python tools/check_scene_release.py --print-source-sha256
python tools/check_scene_release.py
```

檢查器會核對目前 Godot 執行期來源和素材、完整的圖庫場景、雙鏡位分數、對應的 1120 × 630 影像及全數通過的路線。素材、地形、shader 或相機更改後須針對受影響場景重跑，確認相關證據並更新版本記錄。所有場景雙鏡達 85 分以上且檢查器通過後，才提交和推送。
