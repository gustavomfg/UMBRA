# UMBRA 0.4 — Motion and frame pacing

## Diagnosis

The approved Umbra preview advanced `shaderTime` from a repeating 120 ms Qt Quick `Timer`. The shader therefore received a new time value only about 8.3 times per second. A clean 30-second QSG timing sample recorded 8.43 frame calls/s with a median interval of about 119 ms. The renderer and monitor could refresh faster, but the hero's moving features still advanced in coarse steps.

The active display is DP-1 at 1920×1080, 180.003 Hz. Quickshell's `ShellScreen` does not expose a usable refresh-rate property in this setup. A trial QML `FrameAnimation` probe did not report the physical display cadence reliably, so no refresh-rate guess is used in the normal preview.

## Implementation

- The shader clock now ticks at a fixed 16 ms interval, giving a nominal 62.5 updates/s. Its speed is based on measured elapsed time rather than the nominal interval, capped at 50 ms to avoid a large jump after a stalled or suspended window.
- The existing VSync-driven threaded Qt Quick render loop remains the preview default. `QSG_RENDER_LOOP` can still override it for diagnostics.
- The shader pauses at the final black success frame and when the window is hidden. No fragment-shader appearance changes were made.
- The 16/17 ms fractional-timer experiment was removed: changing a running Qt Quick `Timer` interval reset its timing and produced only 58.3 measured updates/s. Driving a `FrameAnimation` every VSync rendered about 180 frames/s and raised idle CPU, without improving the 60 Hz target enough to justify the extra work. An `Item.layer` cache did not reduce window redraws in this composition.
- The existing controller animation curves and durations were preserved. They remain driven by the Qt Quick animation system; there was no measured evidence to justify changing their visual timing independently from the shader clock.

## Measurements

| Preview run | Window render/frame-call cadence | CPU, one core | RSS |
| --- | ---: | ---: | ---: |
| Umbra 0.3 baseline, 120 ms timer | 8.43/s, median 119 ms | ~0.63% | ~216 MiB |
| Umbra 0.4 idle, fixed 16 ms timer | 62.50/s, median 16 ms; p95 17 ms, p99 18 ms, max 19 ms | 5.74% | 229 MiB peak; 226 MiB at sample end |
| Umbra 0.4 AUTH, same fixed timer | Not measured separately | 4.65% | 231.5 MiB peak; 228.6 MiB at sample end |

The 0.4 QSG interval sample covered 30.69 seconds after startup warm-up. The normal-preview idle CPU/RSS sample covered 29.99 seconds and the AUTH sample covered 15.93 seconds, both without QSG diagnostic logging. Both ran with the current Hyprland desktop, OBS and other processes active. NVIDIA `pmon` attributed GPU activity to Quickshell in only 4 of 30 one-second idle samples (3%, 10%, 14%, 7% SM), so this is not a reliable GPU average.

These numbers measure Qt Quick frame rendering/submission cadence, not the physical scanout of every frame by the monitor. QSG reported a VSync animation driver of 5.56 ms (180 Hz) and per-frame swap time of 0 ms; the available local tools did not expose compositor presentation timestamps for this surface. The normal interactive preview ran fullscreen, but a trustworthy local capture/recording path for the native Wayland window was unavailable, so no claim of subjective visual confirmation is made from these measurements alone.

## Interaction checks

- Live fullscreen input sequence: initial character from idle, Backspace, Return failure, Escape during transition, repeated wake, Ctrl+Return visual success, wait through collapse, Escape back to idle, then another failure and cancellation.
- QML suite: 15 passing checks, including first key at idle, repeated wake, escape during WAKE, typing/Backspace/256-character limit, failure, Ctrl+Return success, cancellation, focus and mouse submission.
- Standalone `qmltestrunner` cannot load the system-linked Quickshell core plugin, so it cannot instantiate `SystemChrome` to automate its menu toggles. Its existing 240 ms menu transitions were left unchanged; no power action was invoked.
- `qmllint`, shader baking, `glslangValidator`, shell syntax checks, and Umbra 0.3 backup hash validation passed.

## Restore

Run `scripts/restore-umbra-0.3.sh` to restore the approved 0.3 files from the hash-checked `backups/umbra-0.3` snapshot. The script removes this motion report before copying the snapshot. It restores project files only; it does not interact with display-manager, PAM, boot, or login services.
