# 場景製作與驗收

- 場景採原創設計，沿用 [場景美術與驗收標準](review/refinement/SCENE_STYLE_STANDARD.md) 和 [主 Prompt](review/refinement/MASTER_PROMPT.md)。新場景先選手繪日照或冷濕遺跡其中一條分支，再決定地標、地形和動線。
- 用既有 Godot 圖庫的 `review_views()` 和步行檢查點驗證場景。新增場景時加入 `refinement_gallery.gd` 的 `LOCATIONS`，固定近景與 MOBA 俯視，再開始逐輪比較。
- 優先塑造大輪廓與中尺度的功能結構，再處理材質、植被、接地和水岸。保持地面連續、路線可讀，並在所有修改後實測碰撞與步行。
- 每輪保存雙鏡位、分項分數、差異、取捨和 Prompt 修改。只有實機證據支持的規則才加入主 Prompt。舊候選與失敗證據保留在逐輪紀錄。
- 場景美術提交與推送前，確認圖庫每一張場景的近景與俯視都各至少 85 分，完成實際渲染及步行測試，並執行 `python tools/check_scene_release.py`。評分建立於人工視覺檢查，程式核對分數、對應影像、來源檔案和步行證據。任何鏡位低於門檻時繼續在工作區調整。
