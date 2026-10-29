# Windows FFmpeg candidate: observed build evidence

Date: 2026-10-29. Scope: one candidate build on this session host. This is not the Phase 1 decision record.

## Source and archive identity

[FFmpeg download sources](https://ffmpeg.org/download.html) link to BtbN. The [publisher release](https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2026-10-28-19-47) describes the chosen asset as Windows x64 GPL static. The fixed archive passed the pinned checksum gate before extraction. An independent hash of the retained download also matched.

- Asset: `ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0.zip`.
- Download: https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-28-19-47/ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0.zip
- Archive bytes: `195092333`.
- Archive SHA-256: `cd9b8df51452d21b24b108de3cb11a9ad6770d7f3a8fd676222829b86d8e59ed`.
- Publisher API: [release metadata](https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/autobuild-2026-10-28-19-47). The release is mutable; the acquisition script pins bytes.

## Observed tool identity

- Collection time, UTC: `2026-10-29T22:28:58.0413595+00:00`.
- Host OS reported by .NET: `Microsoft Windows 10.0.26300`; architecture `X64`; PowerShell `7.6.5`.
- FFmpeg: `ffmpeg version n9.0.2-37-gae19868753-20261028 Copyright (c) 2000-2026 the FFmpeg developers`.
- ffprobe: `ffprobe version n9.0.2-37-gae19868753-20261028 Copyright (c) 2007-2026 the FFmpeg developers`.
- FFmpeg executable SHA-256: `0b832615861f6881117c0b6041ef3525f94f08efb62604d0a06ace8495767efa`.
- ffprobe executable SHA-256: `8dae9a12ecc2943b7d9ed35164b55bd0fa1392d6e83e62cae60d59c4a0769a0f`.
- All six collector commands exited zero: both versions, both build configurations, FFmpeg filters and FFmpeg encoders.
- The collector checked each tool hash before and after inspection.

## Reported build configuration

```text
configuration:
    --prefix=/ffbuild/prefix
    --pkg-config-flags=--static
    --pkg-config=pkg-config --cross-prefix=x86_64-w64-mingw32-
    --arch=x86_64
    --target-os=mingw32
    --enable-gpl
    --enable-version3
    --disable-debug
    --disable-w32threads
    --enable-pthreads
    --enable-iconv
    --enable-zlib
    --enable-libxml2
    --enable-libvmaf
    --disable-libxcb
    --disable-xlib
    --enable-fontconfig
    --enable-libharfbuzz
    --enable-libfreetype
    --enable-libfribidi
    --enable-lcms2
    --enable-vulkan
    --enable-libdav1d
    --enable-libvorbis
    --enable-librav1e
    --enable-librsvg
    --disable-libpulse
    --enable-gmp
    --enable-lzma
    --enable-liblcevc-dec
    --enable-opencl
    --enable-amf
    --enable-libaom
    --enable-avisynth
    --enable-chromaprint
    --enable-libdavs2
    --enable-libdvdread
    --enable-libdvdnav
    --disable-libfdk-aac
    --enable-ffnvcodec
    --enable-cuda-llvm
    --enable-frei0r
    --enable-libgme
    --enable-libkvazaar
    --enable-libaribb24
    --enable-libaribcaption
    --enable-libass
    --enable-libbluray
    --enable-libjxl
    --enable-libmp3lame
    --enable-libopus
    --enable-libplacebo
    --enable-librist
    --enable-libssh
    --enable-libtheora
    --enable-libvpx
    --enable-libwebp
    --enable-libzmq
    --enable-lv2
    --enable-libvpl
    --enable-openal
    --enable-liboapv
    --enable-libopencore-amrnb
    --enable-libopencore-amrwb
    --enable-libopenh264
    --enable-libopenjpeg
    --enable-libopenmpt
    --enable-librubberband
    --enable-schannel
    --enable-sdl2
    --enable-libsnappy
    --enable-libsoxr
    --enable-libsrt
    --enable-libsvtav1
    --enable-libtwolame
    --enable-libuavs3d
    --disable-libdrm
    --enable-vaapi
    --enable-vapoursynth
    --enable-libvidstab
    --enable-libvvenc
    --disable-whisper
    --enable-libx264
    --enable-libx265
    --enable-libxavs2
    --enable-libxvid
    --enable-libzimg
    --enable-libzvbi
    --extra-cflags=-DLIBTWOLAME_STATIC
    --extra-cxxflags=
    --extra-libs=-lgomp
    --extra-ldflags=-pthread
    --extra-ldexeflags=
    --cc=x86_64-w64-mingw32-gcc
    --cxx=x86_64-w64-mingw32-g++
    --ar=x86_64-w64-mingw32-gcc-ar
    --ranlib=x86_64-w64-mingw32-gcc-ranlib
    --nm=x86_64-w64-mingw32-gcc-nm
    --extra-version=20261028

Exiting with exit code 0
```

## Reported relevant components

```text
 .. vidstabdetect     V->V       Extract relative transformations, pass 1 of 2 for stabilization (see vidstabtransform for pass 2).
 .. vidstabtransform  V->V       Transform the frames, pass 2 of 2 for stabilization (see vidstabdetect for pass 1).
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (codec h264)
 V....D libx264rgb           libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 RGB (codec h264)
 V....D h264_amf             AMD AMF H.264 Encoder (codec h264)
 V....D h264_nvenc           NVIDIA NVENC H.264 encoder (codec h264)
 V..... h264_qsv             H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (Intel Quick Sync Video acceleration) (codec h264)
 V....D libx265              libx265 H.265 / HEVC (codec hevc)
 V....D hevc_amf             AMD AMF HEVC encoder (codec hevc)
 V....D hevc_nvenc           NVIDIA NVENC hevc encoder (codec hevc)
 V..... hevc_qsv             HEVC (Intel Quick Sync Video acceleration) (codec hevc)
```

These lines establish that the build lists these components. No encode, decode, stabilization filter execution, GPU initialization, camera-media probe or benchmark was run. Hardware suitability remains unverified.

## Observed license file and limits

- Archive root contains `LICENSE.txt`, `35147` bytes.
- Its heading identifies GNU General Public License, Version 3, 29 June 2007.
- License-file SHA-256: `8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903`.
- The collector preserved the license text as caller-supplied evidence and marked applicability unverified.
- Complete dependency-license coverage and correspondence between the distributed binaries and source code have not been established. This candidate is not approved for packaging or redistribution by this record.

## Reproduction and retained local artifacts

Run `app/third-party/get-windows-ffmpeg.ps1` on Windows x64, then `spikes/media-capabilities/collect-build-inventory.ps1` using its printed paths and the extracted `LICENSE.txt`. Use a new evidence directory outside the repository. The downloader refuses an already existing candidate directory; an already acquired candidate can be inspected directly.

- Acquired files remain under ignored `app/third-party/bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/`.
- Raw local report: `C:/Users/bchen/AppData/Local/Temp/kuaide-real-build-68969b9a076f4ae983c471675afb8693/build-inventory.json` (temporary evidence; not committed).
- Raw report SHA-256: `7cea91da79833850416f7b5fe1757beff79b21b49cab1386191407af871e6070`.
- `git check-ignore` confirmed the downloaded archive and executable paths are ignored. No executable, archive or raw local report is included in the change.

Next evidence: confirm exact source and dependency provenance, run short bounded software/hardware encoder and filter tests on verified reference hardware, and collect macOS arm64 evidence. Media format, VFR, gyro and tone-mapping comparisons remain open.
