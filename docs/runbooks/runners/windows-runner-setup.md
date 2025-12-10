# Windows GitHub Runner Setup

This guide covers setting up a Windows-based GitHub Actions runner on Intel NUC (x86_64) devices.

## Prerequisites

- Intel NUC hardware
- Windows Server installation media
- GitHub repository or organization access
- Network connectivity

## Setup Steps

### 1. Install Windows Server

1. **Download Windows Server**
   - Download Windows Server installation media
   - Create bootable USB drive
   - Install Windows Server on the device

2. **Configure Network**
   - Set static IP address
   - Enable Remote Desktop
   - Configure Windows Firewall

### 2. Install Prerequisites

1. **Install Docker Desktop for Windows**
   - Download from [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - Install and configure
   - Enable WSL 2 backend

2. **Install Development Tools**
   - Install Git for Windows
   - Install PowerShell 7+
   - Install Visual Studio Build Tools (if needed)

### 3. Install GitHub Actions Runner

1. **Get Runner Token**
   - Navigate to GitHub repository/organization
   - Go to **Settings** → **Actions** → **Runners**
   - Click **New self-hosted runner**

2. **Download and Configure Runner**
   ```powershell
   # Create directory
   mkdir C:\actions-runner
   cd C:\actions-runner
   
   # Download runner
   Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.XXX.0/actions-runner-win-x64-2.XXX.0.zip -OutFile actions-runner-win-x64-2.XXX.0.zip
   
   # Extract
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\actions-runner-win-x64-2.XXX.0.zip", "$PWD")
   
   # Configure
   .\config.cmd --url https://github.com/<org-or-user>/<repo> --token <token>
   ```

3. **Install as Service**
   ```powershell
   .\svc.cmd install
   .\svc.cmd start
   ```

### 4. Configure Docker Host

For Windows runners, Docker may be accessible via TCP:
- Set `DOCKER_HOST=tcp://127.0.0.1:2375` in runner environment

## Verification

- Check runner status in GitHub: **Settings** → **Actions** → **Runners**
- Runner should appear with green status
- Test with a simple GitHub Actions workflow

