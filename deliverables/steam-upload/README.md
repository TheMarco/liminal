# Upload It Wants You To Stay to Steam

Double-click **Upload to Steam.command** and sign in to Steam in Terminal when prompted. The account defaults to `marcovhv`, matching the Steamworks session used for setup. Enter passwords and Steam Guard codes only in SteamCMD's prompt.

The script checks the existing game files and requires the Mac app to pass Developer ID signature verification, stapled notarization-ticket validation, and Gatekeeper assessment. It then runs a SteamPipe preview and uploads to app **4336360**. The game files are version **0.5.3**, exported September 27, 2026. This does not export a new game build from the source code.

| Platform | Depot | Installed executable/bundle |
| --- | --- | --- |
| Windows | 4336364 | `It wants you to stay.exe` |
| Linux | 4336365 | `It wants you to stay.x86_64` |
| macOS | 4336366 | `It wants you to stay.app` |

Only the game executables and Mac bundle are mapped. The old ZIP archives, source code, and uploader files are excluded by the explicit mappings.

An upload does **not** release the game or make the build live on a branch. After Steam reports a successful BuildID, verify it on the [Builds page](https://partner.steamgames.com/apps/builds/4336360). Assigning a branch, testing the installation, and submitting for Valve's review are separate steps.

SteamCMD comes from Valve's Steamworks SDK 1.65. Its local files are in `build/steam-tools/`; build logs and caches go to `build/steam-upload-output/`. Both are under the project's ignored build directory. Do not share SteamCMD's login/config files.

Reference: [Valve's SteamPipe upload documentation](https://partner.steamgames.com/doc/sdk/uploading).
