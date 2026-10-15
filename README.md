# AI Orchestrator training: reset button

Reset buttons that give a Windows laptop a fresh copy of one or every training session:

| File | Desktop shortcut | Resets |
|---|---|---|
| `reset1.cmd` | **Reset ASR session 1** | `asr-session-1` |
| `reset2.cmd` | **Reset ASR session 2** | `asr-session-2` |
| `resetall.cmd` | **Reset ASR all sessions** | every session |
| `reset.cmd` | (none) | asks: `1`, `2` or `A` for all of them |

Each button:

1. Asks for confirmation: type `Y`. `reset.cmd` asks which session instead, and that answer is the
   confirmation
2. Stops every running Node.js and Bun process, also when only one session is reset, so they
   release the session folders
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

Double-click one of the files in the `asr-training-reset` folder on the desktop once: every run adds
the three desktop shortcuts that are missing. From then on the shortcuts are the buttons. Between
two groups: press the one for the session to reset, type `Y`, press Enter and wait until it says
the session is ready. Anything else than `Y` stops without changing anything.

Resetting deletes all work in the chosen session folders. It does not sign anyone out of GitHub, VS Code
or Copilot, and does not change the git name and email.

Options, from a PowerShell window in this folder:

```powershell
.\reset1.cmd -Force                         # asr-session-1, no confirmation
.\resetall.cmd -Force                       # every session, no confirmation
.\resetall.cmd -TrainingFolder D:\training  # another folder than the desktop (an absolute path)
```

## Requirements

- Windows with git (https://git-scm.com)
- Internet access to GitHub; behind a proxy the Windows proxy settings are picked up
- Everything else (uv, Python, Bun) is installed by the session setups
