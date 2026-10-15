# AI Orchestrator training: reset button

One button that gives a Windows laptop a fresh copy of one or every training session:

1. Asks which session to reset: `1`, `2` or `A` for all of them. That answer is also the confirmation
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

Double-click `reset.cmd` in the `asr-training-reset` folder on the desktop. The first run also adds
a **Reset ASR training** shortcut to the desktop; from then on that shortcut is the button. Between
two groups: press it, type the session to reset (`1`, `2` or `A`), press Enter and wait until it
says the sessions are ready. Only Enter stops without changing anything.

Resetting deletes all work in the chosen session folders. It does not sign anyone out of GitHub, VS Code
or Copilot, and does not change the git name and email.

Options, from a PowerShell window in this folder:

```powershell
.\reset.cmd -Session 2                      # only asr-session-2, after typing Y
.\reset.cmd -Session 1 -Force               # only asr-session-1, no confirmation
.\reset.cmd -Force                          # every session, no confirmation
.\reset.cmd -TrainingFolder D:\training     # another folder than the desktop (an absolute path)
```

## Requirements

- Windows with git (https://git-scm.com)
- Internet access to GitHub; behind a proxy the Windows proxy settings are picked up
- Everything else (uv, Python, Bun) is installed by the session setups
