@echo off
chcp 65001 >nul

:: ============================================
:: generate.bat - 生成解决方案并编译复制
:: ============================================
::
:: 用法：

::   generate.bat                      使用默认配置（VS2026, Release）

::   generate.bat 2022                 使用 VS2022, Release 模式

::   generate.bat 2026 debug           使用 VS2026, Debug 模式

::   generate.bat 2022 release         使用 VS2022, Release 模式
::
:: 参数说明：

::   参数1: VS版本（2022 或 2026）

::   参数2: 编译模式（debug 或 release）
::
:: ============================================

rem 使用短路径名避免 Windows 上的 Unicode 路径问题
for %%I in ("%~dp0.") do set "ROOT_SHORT=%%~sI"
pushd "%ROOT_SHORT%"

:: ============================================
:: 配置选项（可在此处修改默认值）
:: ============================================

:: Visual Studio 版本：设置为 2022 或 2026
:: 也可通过命令行参数传递：generate.bat 2026 debug
set "PREM_AVAIL_VS=2026"

:: 编译模式：设置为 Debug 或 Release
:: 也可通过命令行参数传递：generate.bat 2026 debug
set "BUILD_CONFIG=Release"

:: ============================================
:: 命令行参数覆盖（可选）
:: ============================================

:: 第一个参数：VS 版本
if not "%~1"=="" set "PREM_AVAIL_VS=%~1"

:: 第二个参数：编译模式
if not "%~2"=="" set "BUILD_CONFIG=%~2"

:: ============================================
:: 根据 VS 版本选择 premake 操作和解决方案扩展名
:: ============================================

if /i "%PREM_AVAIL_VS%"=="2026" (
	Solution\external\premake\premake5.exe vs2026
	set "SLN_EXT=slnx"
) else (
	Solution\external\premake\premake5.exe vs2022
	set "SLN_EXT=sln"
)
popd

:: 编译解决方案并复制 .asi 到游戏目录
echo.
echo 正在编译 %BUILD_CONFIG% 配置并复制到 D:\Games\GTAV Mod

:: ============================================
:: 通过 vswhere 查找 Visual Studio 安装路径
:: ============================================

set "VSVARS="
set "VSHOME="
set "VSW=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSW%" set "VSW=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSW%" (
	for /f "usebackq delims=" %%P in (`"%VSW%" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -products * -property installationPath`) do set "VSHOME=%%P"
)

if defined VSHOME (
	set "VSVARS=%VSHOME%\VC\Auxiliary\Build\vcvars64.bat"
)

if not exist "%VSVARS%" (
	if /i "%PREM_AVAIL_VS%"=="2026" (
		set "VSVARS=%ProgramFiles%\Microsoft Visual Studio\2026\Community\VC\Auxiliary\Build\vcvars64.bat"
	) else (
		set "VSVARS=%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
	)
)

if exist "%VSVARS%" (
	call "%VSVARS%" >nul 2>&1
) else (
	echo 警告：未找到 vcvars。vswhere 查找失败或 Visual Studio 未安装在预期位置。
	echo 如果 msbuild.exe 在 PATH 中，仍可编译；否则请安装 Visual Studio 或调整 PREM_AVAIL_VS。
)

:: ============================================
:: 切换到解决方案目录并编译
:: ============================================

cd /d "%ROOT_SHORT%\Solution"

:: 通过 PowerShell 查找 msbuild 并执行编译（单行命令避免 cmd 解析问题）
powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Command msbuild.exe -ErrorAction SilentlyContinue).Source | ForEach-Object { if(-not $_){Write-Error 'msbuild not found'; exit 1}; & $_ '%ROOT_SHORT%\\Solution\\Menyoo.%SLN_EXT%' /p:Configuration=%BUILD_CONFIG% /p:Platform=x64; exit $LASTEXITCODE }"

if %errorlevel% neq 0 (
		echo 编译失败，中止复制。
		pause
		exit /b %errorlevel%
)

:: ============================================
:: 复制编译产物
:: ============================================

:: 目标路径
set "TARGET_PATH=D:\Games\GTAV Mod"

:: 根据编译模式确定源路径
if /i "%BUILD_CONFIG%"=="Release" (
	set "SOURCE_PATH=%ROOT_SHORT%\Solution\source\_Build\bin\Release"
) else (
	set "SOURCE_PATH=%ROOT_SHORT%\Solution\bin\Debug"
)

:: 确保目标目录存在
if not exist "%TARGET_PATH%" (
	mkdir "%TARGET_PATH%"
	if %errorlevel% neq 0 (
		echo 创建目标目录失败：%TARGET_PATH%
		pause
		exit /b %errorlevel%
	)
)

:: 复制生成的 .asi 文件
xcopy "%SOURCE_PATH%\*.asi" "%TARGET_PATH%\" /Y >nul 2>&1

if not exist "%TARGET_PATH%\*.asi" (
	echo 编译输出中未找到 .asi 文件，复制可能失败。
	pause
	exit /b 1
)

echo.
echo ============================================
echo 编译并复制完成！
echo 编译模式: %BUILD_CONFIG%
echo 目标路径: %TARGET_PATH%
echo ============================================
pause
