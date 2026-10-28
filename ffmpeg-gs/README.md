# ffmpeg-gs dependency folder

This folder is intended to contain the Windows tools used by the repository's batch and PowerShell scripts.

## Required files

Copy the matching, trusted Windows x64 binaries into this folder:

- `ffmpeg.exe`
- `fpcalc.exe`
- `gsdll64.dll`
- `gswin64c.exe`
- `img2pdf.exe`
- `img2pdf-gui.exe`
- `pikepdf-tools.exe`
- `TagLibSharp.dll`

The repository workflow `.github/workflows/populate-ffmpeg-gs.yml` fetches and stages these tools from their upstream release sources. See `DEPENDENCIES.txt` for selected versions and provenance. The `img2pdf` executables are self-contained builds made from the upstream `img2pdf` package; `pikepdf-tools.exe` is a self-contained helper for PDF merge, split, and page-count operations. Their sizes will differ from small launcher stubs installed by Python's package manager.

## Check the folder

On Windows, run this from PowerShell:

```powershell
.\verify-dependencies.ps1
```

The checker verifies that every required file exists and is non-empty. It deliberately does not execute the binaries.

## Important notes

- Use trusted official or project-maintained builds, and keep each component's version and license information with the release.
- FFmpeg Windows executables are provided by third-party build providers linked from the [official FFmpeg download page](https://ffmpeg.org/download.html).
- Ghostscript is available from [Ghostscript's official releases page](https://ghostscript.com/releases). Review its license before redistributing it.
- Some builds of FFmpeg or other tools can be too large for a normal GitHub repository file. Consider Git LFS or a versioned GitHub Release for large binary assets, after checking the applicable licensing terms.
- The scripts are being updated to resolve tools from this repository's `ffmpeg-gs` directory first; some retain `E:\ffmpeg-gs` as a compatibility fallback. Keep this folder beside the repository's `bat` directory after extraction.
