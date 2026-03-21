# Windows 打包与快速卸载

## 1. 生成应用 Release

先在项目根目录执行：

```powershell
fvm flutter build windows --release
```

产物目录：

- build/windows/x64/runner/Release

## 2. 制作 EXE 安装包（Inno Setup）

本仓库脚本：

- inno.iss

脚本已改为相对路径打包，会自动包含 Release 目录下全部运行文件（排除 .lib/.exp）。

### 2.1 安装 Inno Setup

- 下载并安装 Inno Setup 6（安装后会有 ISCC.exe）。

### 2.2 图形界面编译

1. 打开 Inno Setup Compiler
2. 打开项目中的 inno.iss
3. 点击 Compile

输出目录：

- dist/inno

输出文件名：

- pure_live_setup.exe

### 2.3 命令行编译

如果系统中有 ISCC.exe，可在项目根目录执行：

```powershell
"$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" inno.iss
```

说明：安装向导中的“创建桌面快捷方式”现在默认勾选，安装时可按需取消。

## 3. 制作 MSIX（可选）

仓库也支持 MSIX：

```powershell
fvm dart run msix:create --signtool-options "/td SHA256"
```

## 4. 快速卸载

### 4.1 EXE 安装包（Inno）

- 设置 -> 应用 -> 已安装应用 -> 卸载
- 或安装目录运行卸载程序（通常是 unins000.exe）

### 4.2 MSIX

- 设置 -> 应用 -> 已安装应用 -> 卸载
- 或 PowerShell：

```powershell
Get-AppxPackage *pure_live* | Remove-AppxPackage
```

## 5. 常见问题

### 5.1 编译 Inno 报找不到文件

先确认是否已执行：

- fvm flutter build windows --release

并确认目录存在：

- build/windows/x64/runner/Release

### 5.2 构建时出现 CMake Warning (dev)

一般为警告，不会阻断生成 EXE。只要最终有 Built ...\pure_live.exe 即可。
