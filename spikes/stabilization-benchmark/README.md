# Clip manifest spike

This PowerShell 7 script hashes top-level files from the directory named by `KUAIDE_CLIPS_DIR`. It records filenames, byte sizes and full-file SHA-256. It never modifies the input files. It does not probe, decode or classify media and does not run FFmpeg.

Set the environment variable to the local original-clips directory. Keep only original clips there, as AGENTS.md requires. Supply an existing output directory outside this repository and the clips directory:

```powershell
$env:KUAIDE_CLIPS_DIR = 'C:/original-clips'
pwsh -NoProfile -File ./spikes/stabilization-benchmark/write-clip-manifest.ps1 `
  -OutputDirectory 'C:/benchmark-evidence/run-01'
```

The script creates `clips.manifest.json` with create-new semantics. It refuses an existing report. It rejects linked paths, including junctions or symbolic links in ancestors. Cloud-storage placeholders (OneDrive, Google Drive files-on-demand) are reparse points without a link target and are accepted; hashing them downloads the full file. It does not create or remove directories. A disk write failure can leave a new incomplete report, but cannot overwrite an earlier file.

The manifest uses filenames only, so it can later be reviewed for inclusion at `spikes/stabilization-benchmark/clips.manifest.json` without committing a computer-specific source directory. Review filenames for private information before sharing. Do not commit original footage or local output directories. Future benchmark scripts must resolve the filenames against `KUAIDE_CLIPS_DIR`.

All top-level regular files are candidates, regardless of extension, except hidden or system files such as `desktop.ini`; nested directories are not scanned. A file listed here is not proven to be playable video or a camera original. Format, camera, originality and footage categories remain unknown until later probe or owner evidence. Full hashes identify exact bytes; they do not establish how those bytes were recorded or edited.

Do not change input files or directory links while collection runs. Size and modification time are checked before and after hashing, but this is not a filesystem snapshot. Hashing large footage can take time; cancellation before the final write leaves existing files intact.

Run the offline checks:

```powershell
pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-clip-manifest.ps1
```

The checks create temporary byte fixtures with spaced and Unicode names, invoke the public script in child PowerShell processes and verify hashes, unknown evidence, output guards and the environment requirement. They do not access real footage or prove media validity. They print and preserve the unique temporary results directory for inspection.
