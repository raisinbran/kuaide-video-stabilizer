# Build inventory spike

This PowerShell 7 collector records evidence from trusted local FFmpeg and ffprobe files. It runs only `-version`, `-buildconf`, `-filters` and `-encoders`. It does not download tools, open footage, run filters, encode video or test a GPU.

Use explicit tool paths and an existing output directory outside this repository and both tool directories:

```powershell
pwsh -NoProfile -File ./spikes/media-capabilities/collect-build-inventory.ps1 `
  -FfmpegPath 'C:/media-tools/ffmpeg.exe' `
  -FfprobePath 'C:/media-tools/ffprobe.exe' `
  -OutputDirectory 'C:/media-evidence/run-01'
```

The collector creates `build-inventory.json` without replacing an existing file. Use a separate output directory for each collection. Linked paths, including junctions and symbolic links in an ancestor, are rejected to keep the output boundary explicit. The directory must already exist; the collector does not create or remove directories.

Optional `-SourceUrl` and `-LicensePath` preserve caller-supplied provenance and license text. The collector does not verify the URL, authenticity, license applicability, archive checksums or correspondence to source code. Missing information stays `unknown`. SHA-256 identifies the exact tool files and supplied license file; it is not a trusted-publisher check.

The report preserves stdout and stderr separately for every command. It includes tool paths, SHA-256, UTC collection time, OS, architecture and PowerShell version. A before/after hash check rejects a tool file changed during collection. Command errors or a timeout stop collection before a report is created. Each command has a 15-second timeout by default (`-TimeoutSeconds`, 1-120). Do not run untrusted executable files or scripts.

The lists describe what the build reports. An encoder such as `h264_nvenc` appearing in a list does not prove that a GPU, driver or actual encoding works. No Windows or macOS suitability, tone-mapping quality or packaging decision follows from this inventory alone. These need later runtime tests and provenance review under WP 1C.

Run the bounded offline checks:

```powershell
pwsh -NoProfile -File ./spikes/media-capabilities/test-build-inventory.ps1
```

The checks launch local `.ps1` stand-ins through child PowerShell processes and test output safety, raw evidence capture, provenance labels, nonzero exits and timeout handling. They use real filesystem writes and subprocesses, but do not establish FFmpeg interoperability. The collector accepts `.ps1` paths for these trusted stand-ins. The checks print their temporary results directory and leave it available for inspection.
