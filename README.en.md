# Portable Node.js Dev Environment ( Windows 10/11 )

[![Portable](https://img.shields.io/badge/Status-Portable-green)]() [![Version](https://img.shields.io/badge/Version-1.2.0-blue)]()

A project for creating a Portable Development Environment. It allows you to run and develop Node.js/JavaScript projects instantly on Windows without installing Git, Node.js, or 7-Zip on the operating system. Perfect for running off a USB Flash Drive or moving between workstations freely.

## ✨ Key Features (V1.2.0 Update)
- 🔒 **Zero Installation & Isolation** : All tools are sandboxed within the project folder. No pollution to the global OS environment.
- 🚀 **Smart Dynamic Fetching** : 
    1. Automatically searches and downloads the latest 7-Zip via NuGet v3 API.
    2. Checks and fetches the latest Portable Git from GitHub Releases.
    3. Checks and downloads the latest Node.js LTS version from the official website.
- 🌐 **Smart Proxy Detection** : Supports pulling files through a Local CDN Gateway over LAN (drastically reducing internet download times).
- 🧠 **Smart Directory Router** : An intelligent menu system that auto-detects and lets you select a project from the Workspace if multiple projects exist.
- 🧹 **Anti-Zombie Process (Clean Exit)** : Uses Try/Finally to catch script exits. Ensures that pressing Ctrl + C safely terminates all background Node.js processes (Zero Zombie Processes).
- ⚡ **Auto-Start Launcher (`start.bat`)** : Simply double-click `start.bat` and the system will run Auto-Detect (`-r`) mode to instantly drop you into the active project.

---

## 🚀 Usage

### 1. View Help Menu
```powershell
.\setup.ps1 -h
```

### 2. Installation Mode
You can install all tools at once, or selectively install what you need:
```powershell
.\setup.ps1 -i all    # (Installs 7-Zip, Git, Node.js)
.\setup.ps1 -i node   # (Installs Node.js only)
.\setup.ps1 -i git    # (Installs Git only)

# Install Node.js by overriding the Proxy temporarily (e.g., to a Local Proxy)
.\setup.ps1 -i node -p http://192.168.1.2:8080 -y
```

### 3. Dev Environment Shell Mode
Open the sandboxed environment shell (automatically navigates to the Workspace folder):
```powershell
.\setup.ps1 -e
```

### 4. Execution Mode (Workspace Router)
- **Smart Default Mode** : Place your project folder inside the `workspace` directory, then run the command below. The system will auto-select the project and run `npm install` followed by `npm run dev`.
```powershell
.\setup.ps1 -r
```

- **Combo Clone + Run Mode** : Clone a project directly from GitHub and run it instantly in your Workspace!
```powershell
.\setup.ps1 -u "https://github.com/username/your-repo.git" -r
```

## 📂 Project Structure

When the script is executed, the following directory structure is generated:

```text
portable-nodejs-env
├── setup.ps1          # Core script for environment orchestration
├── start.bat          # Quick launcher (auto-drops you into your workspace)
├── auto-install.bat   # Remote fetch script for initial setup
├── tools/             # (Auto-generated) Sandboxed Node.js, Git, 7-Zip, Aria2
└── workspace/         # (Auto-generated) Place your project folders here
```

---

## ⚙️ Internal Toolchain Structure

This script automatically provisions portable tools and places them in the `tools/` folder:
- **Node.js (LTS Version)**: Fetched directly from Node.js Official Distribution (https://nodejs.org/dist/)
- **Git for Windows (Portable 64-bit)**: Version-checked and downloaded via GitHub Releases API (https://github.com/git-for-windows/git/releases)
- **7-Zip CommandLine (7za.exe)**: Found and extracted via NuGet v3 Service Index (https://www.nuget.org/packages/7-Zip.CommandLine/)
- **Aria2 (Lightweight Download Utility)**: Multi-connection parallel downloading for maximum speed (https://github.com/aria2/aria2/releases)

---

## License

- **Developer:** [rathanon-dev](https://github.com/rathanon-dev)
- **License:** MIT License
