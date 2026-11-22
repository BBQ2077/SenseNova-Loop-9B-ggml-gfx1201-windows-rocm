@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "FAIL=0"

echo ================================================
echo  sensenova-loop-gfx1201  -  runtime verify
echo ================================================
echo.

echo [1/4] files
for %%F in (ggml-hip.dll ggml-base.dll ggml.dll llama.dll amdhip64_7.dll amd_comgr.dll hipblas.dll rocblas.dll rocsolver.dll libhipblaslt.dll llama-cli.exe llama-server.exe test-backend-ops.exe) do (
    if exist "%%F" (
        echo   OK   %%F
    ) else (
        echo   MISS %%F
        set "FAIL=1"
    )
)
if not exist ".kpack\blas_lib_gfx1201.kpack" (
    echo   MISS .kpack\blas_lib_gfx1201.kpack
    set "FAIL=1"
) else (
    echo   OK   .kpack\blas_lib_gfx1201.kpack
)
if not exist "rocblas\library\" (
    echo   MISS rocblas\library\
    set "FAIL=1"
) else (
    echo   OK   rocblas\library\
)
if not exist "hipblaslt\library\gfx1201\" (
    echo   MISS hipblaslt\library\gfx1201\
    set "FAIL=1"
) else (
    echo   OK   hipblaslt\library\gfx1201\
)
echo.

if "%FAIL%"=="1" (
    echo RUNTIME_FILES_INCOMPLETE
    echo   The zip was not fully extracted, or files were removed.
    echo   Re-extract the whole archive into an empty folder.
    echo.
    goto :end
)
echo RUNTIME_FILES_VERIFIED
echo.

echo [2/4] version
llama-cli.exe --version 2>&1 | findstr /i "version built"
echo.

echo [3/4] GPU
set "DEVS="
for /f "delims=" %%D in ('llama-cli.exe --list-devices 2^>^&1 ^| findstr /i "ROCm0"') do set "DEVS=%%D"
if defined DEVS (
    echo  !DEVS!
) else (
    echo   MISS no ROCm0 device - backend did not load
)
echo   kernels: gfx1201 only
echo.

echo [4/4] backend ops
set "GDN="
for /f "delims=" %%S in ('test-backend-ops.exe support -o GATED_DELTA_NET 2^>^&1 ^| findstr /c:"Backend ROCm0"') do set "GDN=%%S"
if defined GDN (
    echo   GATED_DELTA_NET on !GDN!
    echo   BACKEND_OK
) else (
    echo   GATED_DELTA_NET NOT on ROCm0
)
echo.

echo ================================================
echo  Done. Any MISS above means re-extract the zip.
echo  Model is not included - see README.md
echo ================================================

:end
endlocal
