# SenseNova-Loop-9B-ggml-gfx1201-windows-rocm

在 **原生 Windows** 上用 AMD RX 9070 系列顯卡跑 SenseNova-Loop-9B（GGUF）的免安裝 llama.cpp 執行環境。不需要 WSL、Linux、ROCm／HIP SDK、Visual Studio，也不用自己編譯：解壓縮後就能用。

- 內附完整 ROCm 10.0.0rc4 執行庫（AMD TheRock）、HIP 7.15、clang 23 編出的 `ggml-hip.dll`。
- 融合版核心（[dgalli1](https://github.com/dgalli1/llama.cpp) `sensenova-loop-rdna2` @ `1280f20`）已針對 `gfx1201` 預先編譯。
- 上游 `24ea7bb` 在本機只有 6.95 tok/s，因為 mHC router 靜默掉 CPU、每 token 五萬多個計算節點。這版把 mHC 融合成三個 GGML op，**快 7.73 倍**。
- 推薦搭配 **GGUFRun** 使用：在圖形介面選模型、調參數、一鍵啟動。
- 自帶 `llama-server`、`llama-cli`、`llama-bench`、`llama-perplexity`、`test-backend-ops`。

`ggml-hip.dll` 是針對 `gfx1201` 預先編譯的。啟動時偵測到其他架構不會警告，直接跑，能不能用以實際載入結果為準：

| 顯卡 | 架構 | 狀態 |
|---|---|---|
| Radeon RX 9070 XT／RX 9070 | gfx1201 | ✅（實測：RX 9070 16 GB） |
| Radeon AI PRO R9700（32 GB） | gfx1201 | ✅（同架構，未實測） |
| Radeon RX 9060 XT／RX 9060 | gfx1200 | ❌ 別用，核心不相容 |
| RX 7000 系列（gfx110x） | gfx110x | ❌ 別用 |

同為 gfx1201 的不同品牌板卡（華碩、技嘉、撼訊…）都能用，不需要重新編譯。

## 需求

- Windows 10／11 64 位元。
- AMD Adrenalin 顯示卡驅動：使用近期版本（實測驅動 `32.0.32015.2008`）。runtime 只用系統裝好的驅動，其他 ROCm 元件都自帶。
- 系統 RAM：**8 GB 以上就夠**。權重 4.9 GiB 在顯卡上，host 端只留約 546 MiB（tensor 對齊用的零碎部分）與 mmap 頁面快取。RAM 大小不影響速度。
- 硬碟：runtime 解壓後約 508 MB；Q4_K_M 模型 5.42 GiB。
- 顯存：Q4_K_M 權重佔 4.9 GiB，KV 另外算。16 GB 卡跑 64K context 三路約用 8.6 GiB，還有一半空間。

## 下載

到本倉庫的 **Releases** 下載 `ggml-gfx1201-windows-rocm.zip`（約 287 MB），**解壓到任意資料夾**，路徑有空白或中文都可以。

```
ggml-gfx1201-windows-rocm/
├── llama-cli.exe / llama-server.exe / llama-bench.exe / llama-perplexity.exe
├── test-backend-ops.exe
├── ggml-hip.dll              74.8 MB  ← 只有這顆含 gfx1201 機器碼
├── ggml-base.dll             848 KB   ← 新的 ggml_op enum 編在這一顆
├── ggml.dll / ggml-cpu.dll / llama.dll / llama-common.dll / mtmd.dll
├── *-impl.dll
├── amdhip64_7.dll / amd_comgr.dll / rocm_kpack.dll
├── hipblas.dll / rocblas.dll / rocsolver.dll / libhipblaslt.dll / origami.dll
├── hiprtc0715.dll / hiprtc-builtins0715.dll
├── rocblas\library\          ← gfx1201 Tensile 核心
├── hipblaslt\library\gfx1201\
└── .kpack\                   ← blas_lib_gfx1201.kpack 40.9 MB
```

目錄結構不要動。`rocblas\`、`hipblaslt\`、`.kpack\` 必須和 DLL 同層——`.kpack` 是相對 `amdhip64_7.dll` 解析的。

## 取得模型

[sensenova/SenseNova-Loop-9B-GGUF](https://huggingface.co/sensenova/SenseNova-Loop-9B-GGUF)，取 **Q4_K_M**：

| 項目 | 值 |
|---|---|
| 檔案 | `SenseNova-Loop-9B-Q4_K_M.gguf` |
| 大小 | 5,818,631,072 bytes（5.42 GiB） |
| sha256 | `5528b06c41a92d0a2413e827ab08531be56b10f881606c6659361b5da507eeed` |

用 Hugging Face CLI 下載（`pip install -U huggingface_hub` 後有 `hf` 指令）：

```bat
hf download sensenova/SenseNova-Loop-9B-GGUF SenseNova-Loop-9B-Q4_K_M.gguf --local-dir LLM-MODELS
```

注意用 release 那個 repo，不是 `SenseNova-Loop-9B-Preview`。另有 `mmproj-...-F16.gguf` 多模態投影檔，本版未測。

## 驗證

解壓後在資料夾內執行：

```bat
verify.cmd
```

看到 `BACKEND_OK` 和 `GPU AMD Radeon RX 9070` 就是好了。

手動檢查的話：

```bat
llama-cli.exe --version
```

應該輸出 `built with Clang 23.0.0 for Windows AMD64`、`commit 1280f2097`。

```bat
llama-cli.exe --list-devices
```

應該列出 `ROCm0: AMD Radeon RX 9070 (16304 MiB, 16152 MiB free)`。

```bat
test-backend-ops.exe support -o GATED_DELTA_NET
```

應該所有變體都是 `SUPPORTED`、`Backend ROCm0: OK`。**這顆模型 56 層執行中有 48 層是 GDN，這個 op 不在 GPU 上，後面全部沒意義。**

模型放好後跑一次 bench：

```bat
llama-bench.exe -m SenseNova-Loop-9B-Q4_K_M.gguf -ngl 99 -fa on -p 128 -n 128 -r 3
```

RX 9070 上應該是 `pp128 約 1423`、`tg128 約 53.7`。

## 啟動

命令列：

```bat
llama-cli.exe -m SenseNova-Loop-9B-Q4_K_M.gguf -ngl 99 -fa on -c 8192
```

API 伺服器：

```bat
llama-server.exe -m SenseNova-Loop-9B-Q4_K_M.gguf -ngl 99 -fa on -c 16384 --port 8080
```

日誌出現 `server is listening on http://127.0.0.1:8080` 後，瀏覽器開 `http://127.0.0.1:8080/` 就是聊天網頁；OpenAI 相容 API 在 `http://127.0.0.1:8080/v1/chat/completions`。

## GGUFRun

GGUFRun 是 Windows 本機 LLM 控制台，會自動偵測這份 runtime。資料夾這樣放：

```
GGUFRun/
  gguf-ui.py、start-ui.bat …
  RUNTIMES/
    sensenova-loop-gfx1201/     ← 本 zip 解壓到這裡
  LLM-MODELS/
    SenseNova-Loop-9B-Q4_K_M.gguf
```

開啟 GGUFRun 後：

1. 主模型下拉選單選 `SenseNova-Loop-9B-Q4_K_M`。
2. 模式選「一般」（**不要選投機解碼**，原因見下節）。
3. 「更多設定」可調 Context、KV 型別、取樣參數。
4. 按啟動，等日誌出現 `server is listening` 後開網頁。

實測的顯存佔用（`-np 3 -c 65536`、q4_0 KV）：

| 項目 | 用量 |
|---|---|
| 權重 | 4,861 MiB（GPU）+ 546 MiB（RAM） |
| KV cache | 3,024 MiB |
| compute buffer | 920 MiB |
| **合計** | **8,806 / 16,152 MiB** |

單人使用時 `-np 3` 用不到三路，改 `-np 1 -c 65536` 可以省約 2 GB KV。

## 參數

| 參數 | 說明 |
|---|---|
| `-m` | 模型檔路徑 |
| `-ngl 99` | 全部層上 GPU。**不要留空靠 auto-fit**，它會保守留幾層在 CPU，那幾層就是拖速主因 |
| `-fa on` | FlashAttention。關掉會慢 1 tok/s（52.67 vs 53.71），沒有理由關 |
| `-c` | context 長度（token） |
| `-np` | 並行路數，每路各有自己的 `-c` |
| `-ctk` / `-ctv` | KV 型別，預設 f16。q4_0 更省但本版未實測差異 |
| `-t` | CPU 執行緒。模型全在 GPU 上，建議 4，給 8 幫不上忙 |
| `--spec-type ngram-mod` | 從前文找重複片段當草稿。改程式碼、複述文件時有效，零驗證成本 |
| `--temp` `--top-p` `--top-k` `--min-p` | 取樣參數 |
| `--repeat-penalty` | 重複懲罰。**保持 1.0**，對 reasoning 模型有害 |

啟動時會看到 15 行這種警告：

```
[warning] model has unused tensor blk.56.attn_q.weight -- ignoring
```

`blk.56` 是 GGUF 內建的 MTP / NextN 投機層（131.6 MiB），沒開 `--spec-type draft-mtp` 就跳過。無害，不影響速度或輸出。

## 效能

RX 9070 16 GB、Q4_K_M、`-ngl 99 -fa on -r 3`：

| build | `-fa` | pp128 (tok/s) | tg128 (tok/s) |
|---|---|---|---|
| 上游 `24ea7bb` | on | 426.11 ± 16.25 | 6.95 ± 0.03 |
| **本版 `1280f20`** | **on** | **1423.33 ± 3.30** | **53.71 ± 0.05** |
| 本版 `1280f20` | off | 1409.25 ± 3.32 | 52.67 ± 0.05 |

對照其他平台（同為 Q4_K_M）：

| 平台 | 卡 | tok/s |
|---|---|---|
| **本版** | **RX 9070（gfx1201）** | **53.71** |
| dgalli1 原始 | RX 6900 XT（gfx1030） | 40.5 |
| 上游 `24ea7bb` | RX 7900 XTX（gfx1100） | 6.5 |
| 展開成 56 獨立層的版本 | 未融合 | 6～12 |

本機比 6900 XT 快 32.6%，與官方 scoreboard 上 9070 對 6900 XT 的 29.4% 差距一致。

理論上限：Q4_K_M 5.82 GB × 1.62 ≈ 9.43 GB，除以 640 GB/s 頻寬 = 14.7 ms，即 68 tok/s。53.71 相當於 65% 頻寬達成率。

載入時間：約 13 秒（含 shader 編譯快取建立）。第一次執行會建立 `rocblas` 快取，稍慢是正常的。

## 已知問題

### 不要開 MTP 投機解碼

`--spec-type draft-mtp` 預設 `n_max=3`，實測 **48 → 27 tok/s**，慢 44%。

原因是結構性的：這顆模型 56 層執行中有 48 層是 GDN（gated delta net）線性注意力，state 更新無法跨 token 平行。驗證一批 4 個 token 的成本約等於單 token 的 3.6 倍，草稿接受率要 85% 以上才打平。

同一顆模型的姊妹版 Qwen3.5-9B-MTP 在上游有一樣的報告：[#26750](https://github.com/ggml-org/llama.cpp/issues/26750)，CUDA 接受率 35.8% 時 −32%，Vulkan 92% 時 +128%，後端差異極大，該 issue 已被 `closed as not planned` 關掉沒有修。

**留著 `ngram-mod` 就好**，那個對重複性內容有效且沒有驗證成本。

### 思考可能失控

上游 [#14](https://huggingface.co/sensenova/SenseNova-Loop-9B/discussions/14) 回報：某次生成 130,373 個 token **全部卡在 thinking 區塊內**，一個答案字都沒輸出，被 context 上限截斷才停。另一輪 thinking 與答案字數比是 80:1。

同一個題目換 Qwen3.8-27B 只要 9,000 token、47 秒。官方只回「we'll investigate」，至今沒有修正。

那位回報者用的是 `temperature 1.0`——也就是官方 `generation_config.json` 裡的值。如果你遇到，把溫度調低並限制輸出長度。

### 取樣參數

官方只欽定了兩項：`temperature 1.0`、`top_p 0.95`。他們在 discussion #14 明確說 `top_k` 和 `presence_penalty` 是回報者自己客戶端設的，不是 checkpoint 的設定。

llama.cpp 內建預設（`temp 0.80 / top_p 0.95 / top_k 40 / min_p 0.05 / repeat 1.00`）是合理起點：

| 場景 | temp | top_p | top_k | min_p | repeat |
|---|---|---|---|---|---|
| 一般使用（llama.cpp 預設） | 0.80 | 0.95 | 40 | 0.05 | 1.00 |
| 要更穩 | 0.6 | 0.95 | 20 | 0.0 | 1.00 |
| 要完全確定 | 0 | — | — | — | — |

`repeat_penalty` 務必保持 1.0。

### 深 context 的 prefill 會掉 40～50%

`head_dim` 是 256，RDNA4 的 MMA kernel 在 `DKQ > 128` 時直接 bail，全注意力層退回 `flash_attn_tile`。decode 不受影響，所以 `tg128 53.71` 是真的；但 `pp128 1423` 是淺 context 數字，長提示詞會慢不少。

### KV 量化未實測

預設 f16。`-ctk q4_0 -ctv q4_0` 有人說對 head_dim 256 較慢，本版沒有實測對照，要不要用請自己量。

### 未測項目

- 對參考實作的 KLD／perplexity 對照（只需 `wiki.test.raw`）
- 多模態（要 `mmproj-...-F16.gguf`）
- `GGML_HIP_GRAPHS=ON`（刻意關掉求穩，gfx1201 有 HIP graphs 崩潰前例 [#24961](https://github.com/ggml-org/llama.cpp/issues/24961)）

## 常見問題

- **速度只有 6～7 tok/s**：這是上游沒融合的數字。確認 `ggml-hip.dll` 是 74.8 MB 那顆，`llama-cli --version` 要顯示 `commit 1280f2097`。
- **速度正常但 GPU 使用率 0%、CPU 吃滿**：`GGML_HIP_NO_VMM` 沒開。詳見 `BUILD.md`。本版已開。
- **一開始就 `invalid device function` 或 `no kernel image`**：你的卡不是 gfx1201。9060 XT 是 gfx1200，不能用。
- **`ggml-backend` 載入失敗**：`amdhip64_7.dll` 被 System32 裡驅動附的那顆搶走。確認 zip 完整解壓、沒有只挑 exe 出來。
- **改了 `ggml-hip.dll` 就崩潰**：這版加了三個新 `ggml_op`。`ggml-base.dll`、`ggml.dll`、`llama.dll`、`ggml-hip.dll` 是配套的，不能只換一顆。
- **防毒軟體攔截**：DLL 都是 ROCm/TheRock 官方套件原檔，可將資料夾加入例外。
- **沒有答案、一直輸出思考**：見「思考可能失控」，降低溫度並限制 `-n`。
- **顯存不夠**：降 `-c`，或改 `-np 1`。權重 4.9 GiB 是固定的。

## 資料夾結構

| 位置 | 用途 |
|---|---|
| `ggml-hip.dll` | HIP 後端，含 gfx1201 機器碼與三個融合 op |
| `ggml-base.dll` | ggml 核心，新的 `ggml_op` enum 在這一顆 |
| `llama.dll` / `llama-common.dll` | llama 模型層 |
| `*-impl.dll` | 各執行檔的實作 |
| `rocblas\library\` | gfx1201 的 rocBLAS Tensile 核心 |
| `hipblaslt\library\gfx1201\` | gfx1201 的 hipBLASLt 核心 |
| `.kpack\` | rocBLAS lazy-load 套件 |
| `verify.cmd` | 環境驗證腳本 |
| `BUILD.md` | 自己重編的完整步驟與踩過的坑 |

runtime 完全自包含，不讀系統的 ROCm／HIP 環境變數，也不會改動系統設定。刪除資料夾即解除安裝。

## 授權

- llama.cpp：https://github.com/ggml-org/llama.cpp（MIT）
- `sensenova_loop` 支援：[dgalli1/llama.cpp](https://github.com/dgalli1/llama.cpp)（MIT，與上游相同）
- ROCm runtime 二進位（`amdhip64_7.dll`、`amd_comgr.dll`、`rocblas`、`hipblaslt`、`.kpack`）：取自 ROCm/TheRock 的 `_rocm_sdk_core` + `_rocm_sdk_libraries` wheel（MIT），原檔未修改轉散佈
- 模型權重：不包含在本 runtime 內，授權依 [模型頁面](https://huggingface.co/sensenova/SenseNova-Loop-9B-GGUF)（Apache 2.0）

本版為非官方建置，與商湯科技、AMD 無關。
