# Windows 批处理工具箱（bat）

一个以 Windows `.bat` 和 PowerShell 脚本为主的个人效率工具集，集中处理音视频转换、PDF/图片转换、音乐标签检查、目录树生成和局域网共享诊断。多数工具使用“把文件或文件夹拖到脚本上”的方式启动，不需要手动输入复杂命令。

> **平台：** Windows x64。部分功能使用仓库自带的 FFmpeg、Ghostscript 和独立 EXE；Word 转 PDF 仍需安装桌面版 Microsoft Word。请先阅读下方的安装和注意事项，再处理重要文件。

## 功能一览

| 分类 | 工具 | 功能 |
| --- | --- | --- |
| 音频 | [FLAC / TAK / MKA 转 MP3 320k](<bat/FLAC TAK MKA转 MP3 320k(拖文件或文件夹).bat>) | 将 FLAC、TAK、MKA 转成 320 kbps MP3；拖入文件夹时可递归处理，并可选择复制 cue/log 与图片等配套文件。 |
| 视频 | [Video to MKV / MP4](<bat/Video to MKV MP4 一个或多个视频转MKV或MP4.bat>) | 选择 MKV 或 MP4、视频编码方式、音轨、音频编码和字幕策略。 |
| 图片 / PDF | [图片转 PDF](<bat/IMG to PDF 无损 一个或多个图片转一个PDF.bat>) | 多张图片按指定顺序合并为一个 PDF，可选择原尺寸、A4 或 16:9 页面。 |
| PDF | [PDF Merge](<bat/PDF Merge 无损 多个PDF合并成一个PDF.bat>) | 将多个 PDF 合并为一个文件，可指定输入顺序，并选择保留原页面尺寸或统一页面宽度。 |
| PDF | [PDF Split](<bat/PDF Split 无损 单个PDF拆分成单个单页或多个多页PDF.bat>) | 按页码范围拆分 PDF；每个范围生成一个 PDF，支持跳页或范围重叠。 |
| PDF / 图片 | [PDF 转长图](<bat/PDF to Long Image 一个PDF转一个长图.bat>) | 将 PDF 各页纵向拼接为一张长 PNG，并根据页数调整渲染 DPI。 |
| PDF / 图片 | [PDF 转 PNG](<bat/PDF to PNG 一个PDF白透明转一个或多个白底PNG.bat>) | 将 PDF 指定页或全部页面渲染为白底 PNG，使用 300 DPI。 |
| Office | [Word 转 PDF](<bat/Word to PDF 一个Word文档转一个PDF.bat>) | 调用本机 Microsoft Word，将 DOC/DOCX 导出为 PDF。 |
| 文件管理 | [Directory Tree Generator](<bat/ps1/Directory Tree Generator 输入路径不能拖.bat>) | 生成目录树文本，可设置扫描深度、每个目录的文件数量限制、排除规则和是否跟随链接。 |
| 音乐诊断 | [Lyric Diagnosis](<bat/ps1/Lyric Diagnosis拖文件或文件夹生成歌词诊断.bat>) | 检查音频标签、歌词字段、ID3v2 SYLT 同步歌词帧和相关信息，并把输出保存到桌面文本日志。 |
| 音乐管理 | [Music Tag Scanner](<bat/ps1/Music Tag Scanner 拖文件或文件夹进去批量读音乐标签.bat>) | 批量读取音乐元数据，输出 CSV，包含标题、艺术家、专辑、曲目号、年份、时长、码率、采样率、歌词存在情况等字段。 |
| 网络诊断 | [网络共享检查](<bat/ps1/sharecheck双击检查网络共享.vbs>) | 以管理员权限运行检查脚本，查看网络地址、SMB/NFS 等共享、共享权限、监听端口、防火墙、Syncthing、qBittorrent 和 aria2 等信息。 |
| 网络工具 | [局域网 IP 扫描](<bat/局域网IP扫描，用于电脑快速连接/局域网IP扫描.bat>) | 使用 tcping 并行探测本机 IPv4 网段中指定 TCP 端口，并尝试打开部分常见 Web/FTP 服务。 |

## 快速开始

### 1. 下载仓库

点击 GitHub 页面上的 **Code → Download ZIP**，解压到本机。也可以使用 Git 克隆：

```powershell
git clone https://github.com/WuLinLee/bat.git
```

### 2. 保持仓库目录结构

下载 ZIP 并解压后，保持仓库根目录下的 `bat` 与 `ffmpeg-gs` 文件夹在一起，不需要把依赖手动复制到 E 盘，也不要重命名文件夹。脚本会优先从仓库相对路径寻找 FFmpeg、Ghostscript、img2pdf、pikepdf-tools 和 TagLibSharp；为兼容旧配置，部分脚本仍保留 `E:\\ffmpeg-gs\\` 备用路径。

目录结构应类似这样：

```text
bat/
├── bat/
│   └── 各种 .bat / PowerShell 脚本
├── ffmpeg-gs/
│   ├── ffmpeg.exe
│   ├── fpcalc.exe
│   ├── gsdll64.dll
│   ├── gswin64c.exe
│   ├── img2pdf.exe
│   ├── img2pdf-gui.exe
│   ├── pikepdf-tools.exe
│   └── TagLibSharp.dll
└── tools/
    └── pikepdf_tools.py
```

可以在仓库根目录打开 PowerShell，检查依赖文件是否齐全：

```powershell
.\\ffmpeg-gs\\verify-dependencies.ps1
```

依赖版本、下载来源和许可提示见 [ffmpeg-gs/README.md](<ffmpeg-gs/README.md>) 与 [DEPENDENCIES.txt](<ffmpeg-gs/DEPENDENCIES.txt>)。

### 3. 依赖说明

| 工具 | 依赖 / 要求 |
| --- | --- |
| 音频转 MP3、视频转 MKV/MP4 | 仓库内的 `ffmpeg.exe` |
| 图片转 PDF | 仓库内自包含的 `img2pdf.exe` |
| PDF 合并 / 拆分 | 仓库内自包含的 `pikepdf-tools.exe`；无需另装 Python 或 `pikepdf` |
| PDF 转 PNG | 仓库内的 `gswin64c.exe` 与 `pikepdf-tools.exe`；无需另装 Python 或 `pikepdf` |
| PDF 转长图 | 仓库内的 `gswin64c.exe` 与 `ffmpeg.exe` |
| Word 转 PDF | 已安装的桌面版 Microsoft Word；依赖 Word COM 自动化 |
| 音乐标签读取 / 歌词诊断 | 仓库内的 `TagLibSharp.dll` |
| 目录树生成、网络共享检查 | Windows PowerShell；网络共享检查涉及系统级信息，建议使用其 VBS 启动器按提示授权 |
| 局域网 IP 扫描 | 与 `局域网IP扫描.bat` 同目录的 `tcping.exe` |

除了 Word 转 PDF 需要本机安装桌面版 Microsoft Word 之外，表中列出的音视频和 PDF 工具均使用仓库内提供的运行程序。无需为了 PDF 合并、拆分、图片转 PDF 或 PDF 转 PNG 单独安装 Python。
 
## 各工具怎么用

### 音频、视频、图片和 PDF

1. 按上面的依赖说明配置好程序。
2. 对于文件转换工具，将一个或多个文件（或支持文件夹输入的工具中的文件夹）拖放到对应的 `.bat` 文件上。
3. 根据命令行提示选择格式、编码、页码范围或输出模式。
4. 等待脚本显示完成，再打开输出文件检查结果。

**默认输出位置各有不同：**

- 图片转 PDF、PDF 合并、PDF 拆分、PDF 转 PNG、PDF 转长图：通常输出到当前 Windows 用户的桌面。
- Word 转 PDF：输出到桌面。
- 视频转码：输出到源视频所在目录，文件名追加 `-转码`，扩展名跟随所选格式。
- 音频文件夹转码：在源文件夹旁创建类似 `文件夹名_MP3` 或 `文件夹名_MP3_IMG` 的输出目录；单个音频文件通常输出到同目录。
- 音乐标签扫描：输出到桌面上的 `tags.csv`。
- 歌词诊断：在桌面生成带日期时间的 `DiagnoseResult_*.txt` 日志。
- 目录树生成：在桌面生成以扫描目录名称开头、以 `_tree.txt` 结尾的文件。

请以每个脚本运行时显示的最终输出路径为准。

### 目录树生成器

此工具的启动器明确提示**输入路径，不支持直接拖文件夹**。双击运行后，按提示输入目标目录，并选择扫描模式：

- **Unlimited**：默认模式，不限制目录深度或每个目录列出的文件数量。
- **Fast mode**：可以设置最大深度和每个目录的最大文件数，适合大型目录。
- 可配置是否跟随符号链接 / Junction，以及排除目录名、路径或通配规则。
- 脚本会读取部分简单的 `.gitignore` 规则，但不支持其全部语法。

默认会将目录树文本写入桌面。大型目录建议使用 Fast mode，避免扫描耗时过长或生成超大文本。

### 网络共享检查

双击 `bat/ps1/sharecheck双击检查网络共享.vbs`，Windows 会请求管理员权限。该工具以读取和诊断为主，会汇总共享目录、共享权限、网络监听和防火墙等信息；结果并不等价于从另一台电脑或手机完成了真实连接测试。

运行前请关闭不需要的其他窗口，并注意输出中可能包含电脑名、用户名、局域网 IP、共享路径、进程路径和服务端口等信息。公开日志前应先脱敏。

### 局域网 IP 扫描

双击 `bat/局域网IP扫描，用于电脑快速连接/局域网IP扫描.bat`，按提示刷新扫描或输入指定端口。脚本默认扫描 TCP 2333 端口，并会对部分预设端口尝试打开浏览器或 FTP 地址。请只在自己拥有或获准管理的网络中使用。

## 常见问题

**脚本提示找不到 FFmpeg、Ghostscript、img2pdf、pikepdf-tools 或 TagLibSharp？**

检查解压目录里是否同时存在 `bat` 和 `ffmpeg-gs` 两个文件夹，以及 `ffmpeg-gs` 中的依赖文件是否齐全。不要只下载某几个 BAT 文件或把依赖目录改名；可以运行 `ffmpeg-gs\\verify-dependencies.ps1` 检查缺失文件。

**PDF 合并 / 拆分提示缺少 pikepdf-tools？**

请重新下载仓库最新 ZIP 并完整解压，确认 `ffmpeg-gs\\pikepdf-tools.exe` 存在。不需要另外安装 Python 或运行 pip。

**Word 转 PDF 失败？**

确认安装的是支持 COM 自动化的桌面版 Microsoft Word，而不是只有网页访问的 Office。首次启动 Word 或系统弹出自动化 / 文件访问提示时，按自己的安全策略处理。

**路径中有特殊字符，导致拖放转换失败？**

部分批处理为规避 Windows CMD 对路径中半角百分号 `%` 和感叹号 `!` 的解析问题，会先提示重命名；部分脚本允许输入 `000` 强制跳过检查。除非确认输入路径安全并理解失败风险，否则建议重命名后再运行。

**输出文件已经存在？**

不同脚本的处理策略不同：有的会询问覆盖，有的会跳过或使用带日期时间的文件名。开始转换前，请确认目标文件没有需要保留的旧结果。尤其是视频转码脚本，当前实现可能删除同名的旧 `-转码` 输出文件后再生成新文件；重要文件请提前备份。

## 安全与许可

- 这些脚本会读取你指定的文件；有些会在桌面或源目录创建文件，也会在临时目录写入辅助清单或临时脚本。运行前请先检查输入文件和输出位置。
- 网络共享检查会读取较多系统网络信息；局域网扫描会主动探测端口。请勿在无授权的设备或网络中运行扫描。
- `sharecheck.ps1` 的结果属于诊断信息，不应被视为完整的渗透测试或安全审计。应结合真实客户端连接测试、Windows 共享权限和 NTFS ACL 一起判断。
- 仓库根目录的 [LICENSE](<LICENSE>) 适用于仓库项目本身；随目录提供的第三方 EXE / DLL 有各自的许可条款。重新分发或用于商业用途前，请查阅 [依赖来源和许可说明](<ffmpeg-gs/DEPENDENCIES.txt>) 及上游项目条款。尤其要留意 FFmpeg 构建配置和 Ghostscript 的许可要求。
- 仓库提供的 `img2pdf.exe`、`img2pdf-gui.exe` 与 `pikepdf-tools.exe` 是从上游 Python 包构建的自包含 Windows 程序，体积会明显大于普通 Python 启动器。
- 请先在测试文件上验证输出，再处理唯一副本、重要文档或大型媒体库。

## 目录结构

```text
bat/
├── README.md
├── LICENSE
├── .github/
│   └── workflows/
│       └── populate-ffmpeg-gs.yml
├── bat/
│   ├── 音频、视频、PDF、图片和 Word 转换脚本
│   ├── 局域网IP扫描，用于电脑快速连接/
│   └── ps1/
│       ├── sharecheck.ps1
│       ├── tree.ps1
│       ├── 诊断.ps1
│       └── 读标签.ps1
├── tools/
│   └── pikepdf_tools.py
└── ffmpeg-gs/
    ├── ffmpeg.exe
    ├── fpcalc.exe
    ├── gsdll64.dll
    ├── gswin64c.exe
    ├── img2pdf.exe
    ├── img2pdf-gui.exe
    ├── pikepdf-tools.exe
    ├── TagLibSharp.dll
    ├── DEPENDENCIES.txt
    └── verify-dependencies.ps1
```

## 许可与反馈

欢迎提交 issue 反馈错误、兼容性问题或改进建议。提交问题时请注明 Windows 版本、使用的脚本名称、依赖版本、报错信息及最小复现步骤；分享日志前请移除个人路径、用户名、IP 和其他敏感信息。
