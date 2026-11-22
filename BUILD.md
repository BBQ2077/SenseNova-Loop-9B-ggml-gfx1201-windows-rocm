# 自己編譯

實測環境：Windows 11、RX 9070（gfx1201）、MSVC 14.44（VS 2022）、ROCm 10.0.0rc4（TheRock）。

16 核機器上的耗時：**configure 7 秒，build 6 分 7 秒**。

## 一、工具鏈

需要 ROCm 的 **devel** 樹，不只是執行期 DLL。這裡用的是 ROCm 10.0.0rc4（TheRock）的 pip wheel `_rocm_sdk_devel` / `_rocm_sdk_core`：

```
HIP 7.15.26333-6b0e43f341
clang 23.0.0git
ROCm 10.0.0rc4
```

如果已經有那些 wheel，就不需要下載任何東西——它們只是個目錄樹，裡面有 `bin\`、`lib\llvm\`、`lib\llvm\amdgcn\bitcode\`。

### 一定要放在純 ASCII 路徑

**這不是建議，是必要條件。** ROCm 樹若放在含中文的路徑底下，會得到：

```
ninja: error: FindFirstFileExA(E:/AI/?..?案???容/.../lib/llvm/lib/clang/23/lib/windows):
The filename, directory name, or volume label syntax is incorrect.
```

`subst X:` **沒用**。clang 回報自己的 resource dir 時走 `realpath`，會把替代磁碟展開回真實路徑，再用 ANSI code page 傳出去，中文就變成 `?`。唯一解法是實體複製到 ASCII 路徑：

```bat
robocopy "E:\...\_rocm_sdk_devel" "D:\rocm-sdk" /E /NFL /NDL /NJH /NJS
```

4.45 GiB、7,738 檔、約 31 秒。

### cmake 與 ninja

VS 2022 內建的 cmake（3.31）在偵測 clang 23 ABI 時**會崩潰**：

```
exit code -1073740791  (0xC0000409 STATUS_STACK_BUFFER_OVERRUN)
```

改用獨立的 4.x。WinLibs 的可用：

```
%LOCALAPPDATA%\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_*\mingw64\bin
```

## 二、取得原始碼

```bat
git clone --filter=blob:none --no-checkout https://github.com/OpenSenseNova/llama.cpp src
cd src
git fetch --depth=1 origin 24ea7bb78410e0f0f7bbb362e37c60cd9ecfc761
git remote add dgalli1 https://github.com/dgalli1/llama.cpp
git fetch dgalli1 sensenova-loop-rdna2
git worktree add ../src-fused 1280f2097e5fba3d2d78dde29ff742972e6c09ab
```

`src\` 是上游基準（6.95 tok/s），`src-fused\` 是融合版（53.71 tok/s）。

## 三、Configure

```bat
set "SDK=D:\rocm-sdk"

set "HIP_PATH=%SDK%"
set "ROCM_PATH=%SDK%"
set "HIP_DEVICE_LIB_PATH=%SDK%\lib\llvm\amdgcn\bitcode"
set "HIP_PLATFORM=amd"
set "LLVM_PATH=%SDK%\lib\llvm"
set "PATH=%SDK%\bin;%SDK%\lib\llvm\bin;%PATH%"

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

cmake -S src-fused -B build-fused ^
  -G "Ninja Multi-Config" ^
  -DCMAKE_PREFIX_PATH="%SDK%" ^
  -DCMAKE_C_COMPILER="%SDK%\lib\llvm\bin\clang.exe" ^
  -DCMAKE_CXX_COMPILER="%SDK%\lib\llvm\bin\clang++.exe" ^
  -DCMAKE_HIP_COMPILER="%SDK%\lib\llvm\bin\clang.exe" ^
  -DCMAKE_C_FLAGS="-Wno-error=incompatible-pointer-types" ^
  -DGGML_HIP=ON ^
  -DGGML_HIP_NO_VMM=ON ^
  -DGGML_HIP_GRAPHS=OFF ^
  -DGGML_HIP_MMQ_MFMA=OFF ^
  -DGGML_BACKEND_DL=ON ^
  -DGGML_NATIVE=OFF ^
  -DGPU_TARGETS=gfx1201 ^
  -DLLAMA_CURL=OFF ^
  -DLLAMA_OPENSSL=OFF ^
  -DLLAMA_BUILD_TESTS=ON ^
  -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_APP=OFF
```

各項理由：

| 旗標 | 為什麼 |
|---|---|
| `-DGGML_HIP_NO_VMM=ON` | **必須。** 不開的話 model buffer 顯示 0.00 MiB，全部在 CPU 上跑。詳見下節 |
| `-DGPU_TARGETS=gfx1201` | 會在 ninja 檔裡寫入 `--offload-arch=gfx1201` |
| `-DCMAKE_HIP_COMPILER` 指 `clang.exe` | 不是 `hipcc.bat`，也不是 `clang-cl.exe`。指定這顆 CMake 才會把 `.cu` 當 HIP 編 |
| `-DGGML_HIP_GRAPHS=OFF` | gfx1201 有 HIP graphs 崩潰前例（#24961），求穩關掉 |
| `-DGGML_HIP_MMQ_MFMA=OFF` | RDNA 沒有 MFMA 單元 |
| `-DLLAMA_BUILD_TESTS=ON` | `test-backend-ops` 是唯一能驗證新 op 有沒有上 GPU 的工具。**不要照抄 dgalli1 的 `-DLLAMA_BUILD_TESTS=OFF`**，抄了會編不出來也驗不了 |

驗證 configure 真的鎖定你的顯示卡：

```bat
findstr /C:"offload-arch=gfx1201" build-fused\CMakeFiles\impl-Release.ninja
```

## 四、Build

```bat
cmake --build build-fused --config Release -j 16
```

355 個 target，6 分 7 秒。產出在 `build-fused\bin\Release\`（Ninja Multi-Config 會放在這裡，不是 `build-fused\bin\`）。

## 五、部署 ROCm 執行期

`ggml-hip.dll` 在載入時就要找 `amdhip64_7.dll`。不做這步，Windows 會去 System32 找到驅動附的那顆，版本不同就掛掉或行為異常。

從 `%SDK%\bin\` 複製到 `build-fused\bin\Release\`：

```
amdhip64_7.dll  rocm_kpack.dll  amd_comgr.dll
hipblas.dll  rocblas.dll  rocsolver.dll  libhipblaslt.dll  origami.dll
hiprtc0715.dll  hiprtc-builtins0715.dll
rocblas\      （整棵樹，含 gfx1201 hsaco + Tensile）
hipblaslt\    （整棵樹）
.kpack\blas_lib_gfx1201.kpack  （fft、rand 也一起）
```

`.kpack\` 必須是 `bin\` 的同層，也就是 `bin\Release\.kpack\` 和 DLL 放一起。合計約 508 MB。

## 六、驗證

```bat
cd build-fused\bin\Release
llama-cli.exe --version
```

應輸出 `built with Clang 23.0.0 for Windows AMD64`。

```bat
test-backend-ops.exe support -o GATED_DELTA_NET
```

應在 `ROCm0` 顯示 `SUPPORTED`。這顆模型 56 層執行中 48 層是 GDN，這個 op 不在 GPU 上，其他都不用談。

```bat
test-backend-ops.exe support -o MHC_ROUTE
```

會回 `no test case matches the filters`——dgalli1 沒有為三個新 op 加測試案例，所以驗不了。那三個 op 有效的證據是 7.73 倍加速。

```bat
llama-bench.exe -m <model.gguf> -ngl 99 -fa on -p 128 -n 128 -r 3
```

RX 9070 上應是 `pp128 約 1423`、`tg128 約 53.7`。

- 拿到 6.95 tok/s → 你編到 `src\` 而不是 `src-fused\`
- 拿到 0 GPU 使用率、CPU 吃滿 → 見下面第一項

## 七、踩到的坑

### NO_VMM 不開會拿到假結果

這是最大的陷阱，目前沒有任何官方文件提到。VMM 開著時這個 ROCm 版本會回報：

```
Device 0: AMD Radeon RX 9070, gfx1201, VMM: yes, Wave Size: 32, VRAM: 16304 MiB
load_tensors:   ROCm0 model buffer size =     0.00 MiB
llama_kv_cache: ROCm0 KV buffer size =      0.00 MiB
```

buffer 是 0。權重留在 mmap 的 host memory，全部在 CPU 上算，GPU 使用率一直是 0%，一個 128 token 的 bench 該 13 秒跑完，實際跑 5 分 44 秒還沒結束。

它看起來像「AMD 就是慢」，而不是編譯錯誤。加上 `-DGGML_HIP_NO_VMM=ON` 後會印 `VMM: no`，一切正常。

### 只換 ggml-hip.dll 會崩潰

dgalli1 新增了三個 `ggml_op` 值（`MHC_ROUTE`、`MHC_SINKHORN`、`MHC_MERGE`）與 `DSV4_HC_*`。這個 enum 編在 `ggml-base.dll` 裡，不在 `ggml-hip.dll`。

把 `ggml-hip.dll` 單獨丟進官方 llama.cpp release 會讓 op id 對不上，直接崩潰。`ggml-base.dll` + `ggml-hip.dll` + `ggml.dll` + `llama.dll` 是配套的一組。

### 不要拿官方 Windows ROCm zip 當底

官方 `llama-bXXXXX-bin-win-rocm-*.zip` 不含 `sensenova_loop`，而且從 ROCm 7.14 起還缺 `hipblas.dll` / `rocblas.dll` / `rocsolver.dll`（[#26996](https://github.com/ggml-org/llama.cpp/issues/26996)）。所以本版自己帶整套執行期。

## 八、`ROCm0` 上的 op 支援（實測）

| Op | 結果 |
|---|---|
| `GATED_DELTA_NET` | SUPPORTED（head_count=32、head_size=128，所有變體） |
| `DSV4_HC_COMB` / `DSV4_HC_PRE` / `DSV4_HC_POST` | SUPPORTED |
| `MUL_MAT_PREC_SRC1_F32` | NOT SUPPORTED — 全後端都缺，不是 AMD 專屬 |
| `MHC_ROUTE` / `MHC_SINKHORN` / `MHC_MERGE` | 上游沒有測試案例 |

`MUL_MAT_PREC_SRC1_F32` 不影響本版：dgalli1 的做法是不讓 router 請求 `GGML_PREC_F32`，而不是依賴那個 op。router 本來就是 F32×F32，累加也在 F32。

## 九、與上游的差異

dgalli1 的七項改動，按影響排序：

1. `GGML_OP_MHC_ROUTE`、`GGML_OP_MHC_SINKHORN`、`GGML_OP_MHC_MERGE` — 融合本體。這項把每 token 的節點數從五萬多降到幾千
2. Sinkhorn 步驟的 one-softplus 正規化
3. router 不再請求 `GGML_PREC_F32`（移除 CPU 回退）
4. GDN in-place
5. 零尺寸遞迴節點跳過

作者自報：KLD 0.001153、top token 一致率 98.28%、PPL 7.063。本機未獨立驗證。

## 十、換顯示卡架構

`-DGPU_TARGETS=gfx1201` 改成你的架構（9060 XT 是 `gfx1200`），並確認 `%SDK%\bin\rocblas\library\` 下有對應的 Tensile 核心。本版只放了 gfx1201 的核心，換卡要重新部署整個 runtime。
