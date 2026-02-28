# Launch Menu

Launch Menu is a macOS 26 (Tahoe) launcher app prototype that recreates and extends Launchpad.

## Implemented
- Menu bar resident app + full-screen overlay
- Toggle hotkey (`Command+L`)
- App scanning + icon cache
- Search (Hangul initials + fuzzy matching)
- Smart tabs (All / Recent / Frequent / New)
- Paged/scroll grid modes
- Jiggle mode + drag reorder + folder create/open
- Launchpad DB import
- Dock add action, hot corner
- Localization (15 locales)
- Backup/restore, third-party app uninstall

## Build
```bash
cd LaunchMenu
xcodegen generate
xcodebuild -project LaunchMenu.xcodeproj -scheme LaunchMenu -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

## Key paths
- Store: `LaunchMenu/App/LaunchMenuStore.swift`
- Root UI: `LaunchMenu/Views/Overlay/RootContentView.swift`
- Folder icon view: `LaunchMenu/Views/Folder/FolderIconView.swift`
- Localization helper: `LaunchMenu/Localization/L10n.swift`
