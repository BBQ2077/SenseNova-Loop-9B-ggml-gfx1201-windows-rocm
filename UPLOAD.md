# 上傳到 GitHub

## 為什麼不能直接 git push

`amd_comgr.dll` 是 **116.1 MB**，超過 GitHub 單檔 100 MB 硬限制，push 會被拒絕。整包 508 MB 也不該進 git 歷史。

**正解：repo 只放文字，二進位丟 Release。**

| 位置 | 放什麼 |
|---|---|
| repo（git） | `README.md`、`BUILD.md`、`LICENSE-llama.cpp`、`verify.cmd` |
| Release asset | `ggml-gfx1201-windows-rocm.zip`（約 287 MB，上限 2 GB） |

## 一、建立 repo

```bash
cd C:/Users/user/hermes-files/sensenova-loop-gfx1201-release
git init
git add README.md BUILD.md LICENSE-llama.cpp .gitignore
git commit -m "SenseNova-Loop-9B gfx1201 Windows ROCm runtime"
git branch -M main
git remote add origin https://github.com/<帳號>/SenseNova-Loop-9B-ggml-gfx1201-windows-rocm.git
git push -u origin main
```

`.gitignore` 已經擋掉 zip 與二進位資料夾，不會誤傳。

## 二、發 Release

網頁操作：

1. repo → **Releases** → **Draft a new release**
2. Tag：`v2026.11.22`
3. Title：`SenseNova-Loop-9B Q4_K_M — gfx1201 Windows ROCm（tg128 53.71 tok/s）`
4. `README.md` 內容貼進 description
5. 附件拖入 `ggml-gfx1201-windows-rocm.zip`
6. Publish

gh CLI：

```bash
gh release create v2026.11.22 ggml-gfx1201-windows-rocm.zip \
  --title "SenseNova-Loop-9B gfx1201 Windows ROCm" \
  --notes-file README.md
```

## 三、之後更新

只改文件的話直接 `git push`。換了二進位就重新壓 zip、發新 tag。

`amd_comgr.dll` 116 MB 這種單檔上限問題只在 Release 才會遇到（2 GB），所以永遠不要把 DLL 放進 git。

## 四、可以去哪裡說

到上游開 issue 或留言，重點兩個：

- `GGML_HIP_NO_VMM=ON` 沒開會拿到「buffer 0.00 MiB、GPU 0%、CPU 滿載」的假結果，這件事沒有任何官方文件
- gfx1201 + `sensenova_loop` 在 Windows 原生可跑，tg128 53.71 tok/s，附完整 runtime

llama.cpp 的 **Discussions** 比 issue 適合放「實測結果 + 預編二進位」。issue 區會要求可重現的最小案例。
