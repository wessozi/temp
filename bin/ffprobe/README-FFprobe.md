# FFprobe Dependency Setup

This directory should contain `ffprobe.exe` to enable metadata extraction functionality.

## Download Instructions

1. **Download FFmpeg** from the official website:
   - Go to: https://ffmpeg.org/download.html
   - Select "Windows" and choose "Windows builds by BtbN"
   - Or direct link: https://github.com/BtbN/FFmpeg-Builds/releases

2. **Extract FFprobe**:
   - Download the latest release (e.g., `ffmpeg-master-latest-win64-gpl.zip`)
   - Extract the archive
   - Navigate to the `bin` folder in the extracted files
   - Copy `ffprobe.exe` to this directory

3. **Verify Installation**:
   ```
   .\bin\ffprobe\ffprobe.exe -version
   ```
   
   Should display FFprobe version information.

## Directory Structure

After setup, your directory should look like:
```
bin/
└── ffprobe/
    ├── README-FFprobe.md (this file)
    ├── ffprobe.exe
    └── *.dll (required dependencies)
```

## File Size Reference

`ffprobe.exe` is typically 60-80 MB in size.

## Alternative Download Options

- **Chocolatey** (if you have it installed):
  ```
  choco install ffmpeg
  ```
  Then copy ffprobe.exe from the Chocolatey installation directory.

- **Scoop** (if you have it installed):
  ```
  scoop install ffmpeg
  ```
  Then copy ffprobe.exe from the Scoop installation directory.

## Troubleshooting

- **"Access Denied" error**: Run PowerShell as Administrator
- **"Not recognized" error**: Ensure ffprobe.exe is in this exact directory
- **Permission issues**: Right-click ffprobe.exe → Properties → Unblock (if present)

## Note

FFprobe is part of the FFmpeg project and is completely free and open source. It's used by many popular media applications and is safe to download from the official sources above.