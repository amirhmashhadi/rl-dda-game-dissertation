# Installation and Initialisation Instructions

These instructions explain how to set up the project on **Windows** and **macOS**. The GitHub repository contains the Godot project files, source code, documentation, notebooks, and Python dependency list. However, each machine must install its own local software, including Godot, Python, .NET, and the Python virtual environment.

## Required Software

Install the following software before running the project:
(Godot RL Agents is installed automatically through `requirements.txt`. The links below are included for documentation, troubleshooting, and reference only.)

* [Godot 4.1.4 .NET for Windows](https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=mono_win64.zip&version=4.1.4)
* [Godot 4.1.4 .NET for macOS](https://downloads.godotengine.org/?flavor=stable&platform=macos.universal&slug=mono_macos.universal.zip&version=4.1.4)
* [Godot 4.1.4 Release Page](https://godotengine.org/article/maintenance-release-godot-4-2-2-and-4-1-4/)
* [Python 3.10.11](https://www.python.org/downloads/release/python-31011/)
* [.NET SDK](https://dotnet.microsoft.com/en-us/download)
* [Visual Studio Code](https://code.visualstudio.com/)
* [Godot RL Agents GitHub Repository](https://github.com/edbeeching/godot_rl_agents)
* [Godot RL Python Package](https://pypi.org/project/godot-rl/)

## Recommended Versions

This project is intended to use:

```text
Godot: Godot 4.1.4 .NET
Python: Python 3.10
RL package: godot-rl
RL backend: Stable-Baselines3
Editor: Visual Studio Code
```

The Godot project itself is cross-platform and can be pulled from GitHub on both Windows and macOS. The Python virtual environment is **not** shared through GitHub and must be created separately on each machine.

---

# Windows Setup

## 1. Clone the Repository

Open PowerShell and move to the folder where you want to store the project:

```powershell
cd "C:\Users\YOUR_USERNAME\Documents"
```

Clone the repository:

```powershell
git clone https://github.com/bigladamir/rl-dda-game-dissertation.git
```

Move into the repository:

```powershell
cd rl-dda-game-dissertation
```

## 2. Install Godot 4.1.4 .NET

Download Godot 4.1.4 .NET for Windows:

[Godot 4.1.4 .NET for Windows](https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=mono_win64.zip&version=4.1.4)

Extract the downloaded `.zip` file to a location outside the repository, for example:

```text
C:\Godot\Godot_v4.1.4-stable_mono_win64\
```

Do **not** place the Godot editor executable inside the project repository.

Open the Godot executable and import the project file:

```text
godot_project/game_project/project.godot
```

## 3. Install the .NET SDK

Download and install the .NET SDK:

[.NET SDK Download](https://dotnet.microsoft.com/en-us/download)

After installation, open PowerShell and check that .NET is available:

```powershell
dotnet --version
```

If a version number appears, the installation is working.

## 4. Install Python 3.10

Check which Python versions are already installed:

```powershell
py -0p
```

If Python 3.10 is not listed, install it using one of the following methods.

### Option A: Install with winget

```powershell
winget install --id Python.Python.3.10 -e
```

After installation, close and reopen PowerShell or VS Code, then check again:

```powershell
py -0p
```

### Option B: Install from python.org

Download Python 3.10.11 from:

[Python 3.10.11](https://www.python.org/downloads/release/python-31011/)

During installation, tick:

```text
Add python.exe to PATH
```

Then reopen PowerShell and check:

```powershell
py -3.10 --version
```

## 5. Create the Python Virtual Environment

From the repository root, run:

```powershell
py -3.10 -m venv .venv
```

Activate the virtual environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

When activated, the terminal should start with:

```text
(.venv)
```

If PowerShell blocks the activation script, run this once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then activate the environment again:

```powershell
.\.venv\Scripts\Activate.ps1
```

## 6. Install Python Dependencies

With the virtual environment active, upgrade pip:

```powershell
python -m pip install --upgrade pip
```

Install the project dependencies:

```powershell
pip install -r requirements.txt
```

If `requirements.txt` is missing, install the main packages manually:

```powershell
pip install godot-rl stable-baselines3
```

Then create the dependency file:

```powershell
pip freeze > requirements.txt
```

## 7. Open the Project in VS Code

Open the repository folder in VS Code:

```powershell
code .
```

Recommended VS Code extensions:

```text
C# Dev Kit
C#
Godot Tools
Python
Jupyter
YAML
GitLens
```

## 8. Connect VS Code to Godot

In VS Code, install the **Godot Tools** extension.

If the extension asks for the Godot executable path, select the actual Godot executable, for example:

```text
C:\Godot\Godot_v4.1.4-stable_mono_win64\Godot_v4.1.4-stable_mono_win64.exe
```

Do **not** select the project folder or `project.godot`.

---

# macOS Setup

## 1. Clone the Repository

Open Terminal and move to the folder where you want to store the project:

```bash
cd ~/Documents
```

Clone the repository:

```bash
git clone https://github.com/bigladamir/rl-dda-game-dissertation.git

Move into the repository:

```bash
cd rl-dda-game-dissertation
```

## 2. Install Godot 4.1.4 .NET

Download Godot 4.1.4 .NET for macOS:

[Godot 4.1.4 .NET for macOS](https://downloads.godotengine.org/?flavor=stable&platform=macos.universal&slug=mono_macos.universal.zip&version=4.1.4)

Extract the downloaded `.zip` file and move the Godot app to:

```text
/Applications/
```

Do **not** place the Godot editor app inside the project repository.

Open Godot and import the project file:

```text
godot_project/game_project/project.godot
```

## 3. Install the .NET SDK

Download and install the .NET SDK:

[.NET SDK Download](https://dotnet.microsoft.com/en-us/download)

Choose the correct macOS installer:

```text
Arm64 = Apple Silicon Macs, such as M1, M2, M3, M4
x64 = Intel Macs
```

After installation, check that .NET is available:

```bash
dotnet --version
```

If a version number appears, the installation is working.

## 4. Install Python 3.10

Check your Python version:

```bash
python3 --version
```

If Python 3.10 is not installed, use one of the following methods.

### Option A: Install with Homebrew

Install Homebrew if needed:

[Homebrew](https://brew.sh/)

Then run:

```bash
brew install python@3.10
```

Check the installation:

```bash
python3.10 --version
```

### Option B: Install from python.org

Download Python 3.10.11 from:

[Python 3.10.11](https://www.python.org/downloads/release/python-31011/)

Install the macOS package, then check:

```bash
python3.10 --version
```

## 5. Create the Python Virtual Environment

From the repository root, run:

```bash
python3.10 -m venv .venv
```

Activate the virtual environment:

```bash
source .venv/bin/activate
```

When activated, the terminal should start with:

```text
(.venv)
```

## 6. Install Python Dependencies

With the virtual environment active, upgrade pip:

```bash
python -m pip install --upgrade pip
```

Install the project dependencies:

```bash
pip install -r requirements.txt
```

If `requirements.txt` is missing, install the main packages manually:

```bash
pip install godot-rl stable-baselines3
```

Then create the dependency file:

```bash
pip freeze > requirements.txt
```

## 7. Open the Project in VS Code

Open the repository folder in VS Code:

```bash
code .
```

Recommended VS Code extensions:

```text
C# Dev Kit
C#
Godot Tools
Python
Jupyter
YAML
GitLens
```

## 8. Connect VS Code to Godot

In VS Code, install the **Godot Tools** extension.

If the extension asks for the Godot executable path, select the Godot executable inside the macOS app bundle. It will usually be similar to:

```text
/Applications/Godot_mono.app/Contents/MacOS/Godot
```

The exact app name may differ depending on the downloaded file.

---

# Running the Project

## 1. Open the Godot Project

Open Godot 4.1.4 .NET and import:

```text
godot_project/game_project/project.godot
```

## 2. Activate the Python Environment

Each time a new terminal is opened, activate the virtual environment before running Python training or analysis scripts.

### Windows

```powershell
.\.venv\Scripts\Activate.ps1
```

### macOS

```bash
source .venv/bin/activate
```

## 3. Check Python Packages

With the virtual environment active, check that the main packages are installed:

```bash
python -c "import godot_rl; print('godot-rl installed')"
```

You can also check that Stable-Baselines3 is installed:

```bash
python -c "import stable_baselines3; print('stable-baselines3 installed')"
```

## 4. Update Dependencies After Installing New Packages

If new Python packages are installed, update `requirements.txt`:

```bash
pip freeze > requirements.txt
```

Then commit the updated file:

```bash
git add requirements.txt
git commit -m "Update Python requirements"
```

---

# Git and Cross-Platform Notes

The following files and folders should be committed:

```text
godot_project/game_project/project.godot
godot_project/game_project/scenes/
godot_project/game_project/scripts/
godot_project/game_project/addons/
rl_training/
notebooks/
docs/
requirements.txt
README.md
.gitignore
```

The following files and folders should **not** be committed:

```text
.venv/
.godot/
.import/
__pycache__/
*.pyc
.DS_Store
Thumbs.db
Godot editor executables
Exported builds
```

The Godot RL addon should be committed if it is inside:

```text
godot_project/game_project/addons/
```

The Python package installation should not be committed. Each machine recreates it using:

```bash
pip install -r requirements.txt
```

Avoid hardcoded machine-specific paths such as:

```text
C:\Users\YOUR_USERNAME\...
```

Use project-relative paths instead wherever possible.

---

# Quick Setup Summary

## Windows

```powershell
git clone https://github.com/YOUR_USERNAME/rl-dda-game-dissertation.git
cd rl-dda-game-dissertation

py -3.10 -m venv .venv
.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
pip install -r requirements.txt
```

## macOS

```bash
git clone https://github.com/YOUR_USERNAME/rl-dda-game-dissertation.git
cd rl-dda-game-dissertation

python3.10 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
pip install -r requirements.txt
```
