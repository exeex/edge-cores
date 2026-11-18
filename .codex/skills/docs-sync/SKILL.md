---
name: docs-sync
description: 依 Git 最後提交時間盤點 edge-cores 的 docs 與 skills Markdown，從最舊文件開始，對照最近更新且主題相關的文件與目前實作，修正過時內容。適用於文件同步、老舊文件稽核與逐批維護。
---

# Docs Sync

在 repository 根目錄執行。預設範圍是 `docs/` 與 `.codex/skills/`，包含 skill references；使用者可指定其他範圍。腳本位於根目錄的 `scripts/docs-last-commit.py`，只讀取 Git 與工作目錄，不修改文件。

## 盤點與選擇

```sh
python3 scripts/docs-last-commit.py
python3 scripts/docs-last-commit.py --format json
# 要包含 README 與其他根目錄文件時：
python3 scripts/docs-last-commit.py --paths . --format json
```

輸出所有現存、Git 已追蹤或未忽略的未追蹤 `.md`，按最後一次 commit 的 **committer timestamp** 由舊至新排列；不以檔案 mtime 或 hash 字典序判斷新舊。不遞迴盤點 submodule 內部；需要時對該 repo 另跑 `--repo` 與 `--paths`。

JSON 含完整 `commit`、`date`、`timestamp`、工作目錄 `state`、盤點時 `head`、全部最舊同時間文件 `oldest`，以及 `reference_commits` / `reference_paths`。參考群預設取檔案最後提交中最新的 3 個不同 commit，可用 `--newest-commits N` 調整。這是候選群，不代表同一主題或同一版本。

- `modified` 的日期仍代表已提交版本；先讀取現有 diff，保留使用者修改。
- `uncommitted` 沒有可排序的 Git 年齡，放在最後，另列為待審查；不要當作最舊或最新的證據。
- `shallow=true` 時排序只代表可見歷史，先說明限制，不宣稱找到完整歷史最舊文件。
- 如果只有盤點／流程設計要求，回報結果後停止；要求同步時才執行下面的修改。

預設一次處理一篇最舊、尚未在本輪審查過的文件。同時間並列時按路徑排序。使用者指定批次大小時依其範圍處理。保存本輪已審查路徑及結果，避免尚未 commit 導致同一篇被無限選中；不為了刷新時間製造無意義修改或自動 commit。

## 建立證據並同步

1. 讀完整目標文件、相關規範與現有 diff。先分類用途：目前操作指南、架構說明、skill，或特定版本 release／驗證紀錄。
2. 從最新候選群讀取主題相符的文件，列出採用的來源路徑與完整 commit。若候選群無關，沿連結、關鍵字與相關 skill references 找到主題相符的較新文件；不得強行拿不相關新文件覆蓋舊文件。
3. 檢視目標最後提交之後的相關變更，例如 `git log <last_commit>..HEAD -- <related_paths>` 與 `git diff <last_commit> HEAD -- <related_paths>`。核對目前 scripts、CLI flags、原始碼、測試與 submodule revision；工作目錄尚未提交的內容須標明，不冒充 HEAD 的行為。
4. 先在工作記錄列出「舊敘述 → 新證據（路徑／symbol／commit）→ 修改或保留理由」。文件較新只是線索；若文件與實作衝突，以可驗證的實作／測試判定。證據不足就明確列為未解問題，不編造數據或宣稱測試通過。
5. 只修正可證明過時的路徑、命令、API、架構描述與必要交叉連結，保持原文用途與語言。歷史 release／benchmark／驗證結果保留其版本語境，只修正明確錯誤或補上適用版本／現行指南連結。正確的舊文件記為「已審查，無需修改」。

## 驗證與交付

- 檢查修改涉及的本地連結、路徑與命令參數；需要執行流程驗證時，依該領域現有 skill 選擇適當的最小檢查。不要為文件日期觸發完整 RTL build。
- 修改 skill 時確認 frontmatter、引用與腳本用法仍正確；skill-creator validator 可用時執行它。
- 執行 `git diff --check` 並 review 最終 diff。重新盤點只能反映工作目錄狀態；最後 commit hash 在真正提交前不會更新。
- 回報：目標及原 commit／日期、採用參考及其 commit、實際變更或保留理由、驗證結果、未解問題，以及下一篇待處理文件。完成指定批次即停止，不自行擴大到全庫重寫、commit 或 push。
