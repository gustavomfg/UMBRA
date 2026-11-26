# UMBRA lock screen

Quickshell session lock (`ext-session-lock-v1`) with the greeter's animated
planet, a clock, a PAM password line and a now-playing card (any MPRIS
player, Spotify first).

```
~/Documentos/projetos/umbra/lock/umbra-lock
```

- Needs Quickshell 0.2+ (`Quickshell.Wayland`, `Quickshell.Services.Pam`,
  `Quickshell.Services.Mpris`). Password check uses the `login` PAM service,
  like hyprlock.
- Wrong password replays the lilac wave from the greeter; no red.
- The card hides itself when no player is running.
- Recovery if it hangs: the screen stays locked by design. Press
  Ctrl+Alt+F3, log in, run `pkill quickshell`, then Ctrl+Alt+F2 (or F1).
- `lock/hyprlock.conf` / `umbra-lock-bg.png` are the static fallback.

## Cards

Clock + uptime, sign-in (avatar from `~/.face`, falls back to the initial),
the player, and a bottom strip with network, Bluetooth, CPU, RAM and GPU
(GPU only with `nvidia-smi`). `lock/umbra-lock-stats` samples the numbers
every 3 s; any missing tool just shows "unavailable".
