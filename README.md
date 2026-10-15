# AI Orchestrator training: reset button

One button that gives a Windows laptop a fresh copy of every training session:

1. Asks for confirmation (type `Y`)
2. Stops running Node.js and Bun processes, so they release the session folders
3. Per session: removes the existing folder, clones it again from GitHub and runs its `setup.ps1`

| Session | Repository |
|---|---|
| `asr-session-1` | https://github.com/AlexDM0/asr-session-1 |
| `asr-session-2` | https://github.com/AlexDM0/asr-session-2 |

The sessions go on the desktop, next to this launcher. When the desktop cannot be written to, they
go in `C:\training`. Never inside this folder: the session setups refuse to run inside another git
repository.

## Install, once per laptop

Clone this repository to the desktop, from a PowerShell window:

```powershell
git clone https://github.com/lrlip/asr-training-reset.git "$([Environment]::GetFolderPath('Desktop'))\asr-training-reset"
```

`GetFolderPath` finds the desktop also when OneDrive has moved it.

## Use

Double-click `reset.cmd` in the `asr-training-reset` folder on the desktop. The first run also adds a **Reset ASR training** shortcut to the desktop;
from then on that shortcut is the button. Between two groups: press it, type `Y`, wait until it
says every session is ready.

Pressing it deletes all work in the session folders. It does not sign anyone out of GitHub, VS Code
or Copilot, and does not change the git name and email.

Options, from a PowerShell window in this folder:

```powershell
.\reset.cmd -Force                          # no confirmation
.\reset.cmd -TrainingFolder D:\training     # another folder than the desktop (an absolute path)
```

## Requirements

- Windows with git (https://git-scm.com)
- Internet access to GitHub; behind a proxy the Windows proxy settings are picked up
- Everything else (uv, Python, Bun) is installed by the session setups
