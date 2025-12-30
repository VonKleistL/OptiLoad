# OptiLoad

A high-performance download manager for macOS that replaces your browser's default download system with intelligent, accelerated downloads.

![IMG_1792](https://github.com/user-attachments/assets/ad9c8776-715c-494c-b39a-c0a00f10e26a)

<img width="1678" height="1278" alt="CleanShot 2025-12-24 at 13 34 52@2x" src="https://github.com/user-attachments/assets/a3396b1a-9262-4f8b-b300-4d79417a1693" />


## Features

### Core Functionality
- **Multi-threaded Downloads**: Splits files into chunks and downloads them simultaneously for significantly faster speeds
- **Automatic Browser Integration**: Seamlessly intercepts downloads from Chrome and Firefox via browser extensions
- **Menu Bar Interface**: Lightweight, always-accessible interface that lives in your macOS menu bar
- **Real-time Progress Tracking**: Live download speeds, progress bars, and time remaining estimates
- **Pause and Resume**: Stop downloads at any time and resume them later without losing progress

### Technical Details
- Built entirely in Swift for native macOS performance
- Local HTTP server on port 8765 for browser extension communication
- Concurrent download engine with configurable chunk sizes
- Automatic file verification and integrity checking

## Installation

### 1. Install OptiLoad App
- Download and open `OptiLoad-Installer.dmg`
- Drag OptiLoad to your Applications folder
- Launch OptiLoad from Applications
- Grant necessary permissions when prompted

### 2. Install Browser Extension

#### Chrome
1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" in the top right
3. Click "Load unpacked"
4. Select the `OptiLoad Chrome` folder
5. The extension icon will appear in your toolbar

#### Firefox
1. Under Review by Mozilla Team and will be added ASAP.

### 3. Verify Connection
Click the extension icon in your browser toolbar. You should see "OptiLoad is running" with a green checkmark.

## Usage

Once installed, OptiLoad automatically handles all downloads:

1. Click any download link in your browser
2. The browser's default download is cancelled
3. OptiLoad intercepts and begins accelerated download
4. Monitor progress from the menu bar icon
5. Downloaded files appear in your default Downloads folder

### Managing Downloads
- **View Active Downloads**: Click the menu bar icon
- **Pause/Resume**: Right-click on any active download
- **Cancel**: Click the X button next to any download
- **Settings**: Configure download location, chunk size, and concurrent connections

## System Requirements

- macOS Sequioa or later
- 50MB free disk space
- Chrome or Firefox browser

## How It Works

OptiLoad uses range requests to download files in parallel chunks. When a download starts:

1. Browser extension sends the URL to OptiLoad via localhost:8765
2. OptiLoad queries the server for file size and range support
3. File is split into optimal chunks based on size
4. Multiple connections download chunks simultaneously
5. Chunks are reassembled and verified upon completion

This approach typically achieves 3-5x faster download speeds compared to standard browser downloads, especially for large files on fast connections.

## Troubleshooting

**Extension shows "OptiLoad is not running"**
- Ensure OptiLoad app is running (check menu bar)
- Verify no firewall is blocking port 8765
- Try restarting the OptiLoad app

**Downloads not intercepting**
- Check that the extension is enabled in your browser
- Verify the extension has necessary permissions
- Some sites with special download mechanisms may not be supported

**Slow download speeds**
- Check your internet connection
- Some servers may not support range requests (falls back to single connection)
- Adjust chunk size in settings for your connection type

## Privacy

OptiLoad operates entirely on your local machine. No data is sent to external servers, no analytics are collected, and no account is required. All downloads are direct connections between your computer and the source server.

## License

MIT License - see LICENSE file for details

## Support

For issues, feature requests, or contributions, visit the GitHub repository.

Support the developer and request new features - https://www.paypal.me/LukeVonKleist

Built for the Apple Silicon Mac community by VonKleistL

macOS Apple Silicon
