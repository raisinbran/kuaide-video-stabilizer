# Windows media-tool candidate

This is one proposed Windows x64 GPL static FFmpeg candidate for Phase 1 evidence. It is not the final selected build. The script downloads and extracts files locally; it does not install globally, change PATH, run the downloaded programs, process footage or test hardware encoders.

[FFmpeg's download page](https://ffmpeg.org/download.html) links to BtbN's Windows builds. The [publisher release](https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2026-10-28-19-47) labels this asset GPL, static. The [GitHub release API](https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/autobuild-2026-10-28-19-47) reported these values on 2026-10-29:

| Field | Pinned value |
|---|---|
| Asset | `ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0.zip` |
| Size | `195092333` bytes |
| SHA-256 | `cd9b8df51452d21b24b108de3cb11a9ad6770d7f3a8fd676222829b86d8e59ed` |
| Release tag | `autobuild-2026-10-28-19-47` |

The release API says the release is not immutable. The script pins bytes with the hardcoded hash instead of trusting a tag or a `latest` URL. The publisher's [checksum file](https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-28-19-47/checksums.sha256) is additional publisher evidence; its API-reported SHA-256 is `72b4c1fe06bfb3aea6aecc1f1647d2d4c26a80760253f1931ef46f18ed09d9bc`. These publisher hashes do not establish correspondence to source code, complete dependency licenses or readiness to redistribute.

Run on Windows x64 with PowerShell 7:

```powershell
pwsh -NoProfile -File ./app/third-party/get-windows-ffmpeg.ps1
```

For an already downloaded local archive, add `-ArchivePath 'C:/downloads/candidate.zip'`. The same pinned digest is required. No alternate URL or checksum override is available. The script opens the archive read-only and keeps that handle open through checksum verification and extraction. No archive entry is extracted before the digest matches. .NET's ZIP extraction checks entry paths and refuses existing files.

All downloaded and extracted files stay under ignored `app/third-party/bin/`. Success places the archive's root inside `bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/` and prints paths to both executables. A downloaded archive is named `download-<id>.zip.partial` until it passes the hash check and extraction, then renamed to `download-<id>.zip`; a `.partial` file is always unverified or incomplete. An existing candidate directory makes the script fail. It creates uniquely named download/staging paths and never deletes or replaces previous files. A failed run may leave ignored partial downloads or extraction directories; inspect them before any later owner-approved cleanup. Do not change directory links concurrently. Linked paths are rejected.

The HTTP transfer has a five-minute cancellation deadline. This approximately 195 MB archive should be a bounded acquisition task; extraction and inventory are separate stopping points. No source build or long render batch is part of this script.

Run the offline rejection check:

```powershell
pwsh -NoProfile -File ./app/third-party/test-windows-ffmpeg.ps1
```

The check copies the acquisition script to a unique temporary tree, supplies known wrong bytes and verifies rejection at the checksum gate without a binary/extraction directory or input modification. It uses no network and runs no downloaded program. The real successful path must still be checked with the pinned archive.

After acquisition, run the separate `spikes/media-capabilities/collect-build-inventory.ps1` against the printed paths and an existing evidence directory outside the repository. Supply the asset URL as `-SourceUrl`; inspect the extracted license files and supply the actual appropriate file as `-LicensePath`. If a relevant license file is absent, record that evidence gap. Record executable and license-file hashes, versions, configure flags and reported filters/encoders in reviewed evidence prose. Listings do not prove runtime GPU support. No hardware, codec quality, source correspondence or complete licensing conclusion follows from this step.
