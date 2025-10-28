============================================
OSCDIMG - Windows ISO Building Tool
============================================

OSCDIMG is part of Windows Assessment and Deployment Kit (ADK)
Used to create bootable Windows ISO images.

FILES INCLUDED:
---------------
- oscdimg.exe         : Main ISO builder executable
- etfsboot.com        : Legacy BIOS boot sector
- efisys.bin          : UEFI boot file (normal prompt)
- efisys_noprompt.bin : UEFI boot file (no prompt)
- efisys_EX.bin       : Extended UEFI boot file
- efisys_noprompt_EX.bin : Extended UEFI boot file (no prompt)

USAGE:
------
These files are automatically used by the BuildISO.bat script module.
You don't need to run oscdimg.exe manually.

BOOT TYPES:
-----------
- Legacy BIOS: Uses etfsboot.com
- UEFI: Uses efisys_noprompt.bin
- Hybrid: Supports both BIOS and UEFI boot

SCRIPT MODULE:
--------------
Run from WimBuilder Launcher > Option [2] Build Bootable ISO from WIM

The script will:
1. Ask you to select a WIM file from Kitchen\Output
2. Ask for source Windows ISO (to copy boot files)
3. Copy boot files from source ISO
4. Replace install.wim with your custom WIM
5. Build bootable ISO with oscdimg
6. Output ISO to Kitchen\ISO_Output

REQUIREMENTS:
-------------
- Source Windows ISO (same version as your custom WIM)
- Custom WIM file in Kitchen\Output folder
- Minimum 8GB free disk space

SOURCE:
-------
Windows ADK (https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
