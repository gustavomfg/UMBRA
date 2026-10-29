# UMBRA 0.4b — Auth motion choreography

## Why the old sequence felt disconnected

`Enter` changed the controller to `AUTHENTICATING` synchronously. `AuthPanel` immediately replaced its prompt and hint from phase-bound strings, disabled focus, and cleared the password. The hero only began its 440 ms `InOutCubic` authentication-tension response after that phase change.

The normal preview then waited 920 ms before reporting failure. `FAILURE` started its own 90 ms rise, 360 ms hold, and 200 ms fall. At the same phase change, authentication tension began returning to zero over 440 ms, so the hero was already releasing while the failure pulse was still active.

The old `Ctrl+Enter` path skipped `AUTHENTICATING`: `previewSuccess()` moved directly to `SUCCESS` and started a separate 1480 ms `InOutCubic` timeline. All three UI groups used `1 - min(1, successProgress * 3)` and were fully gone at progress 1/3, about 646 ms in. The shader began ring convergence at progress .08 (about 402 ms), body compression at .2 (about 545 ms), and lighting collapse at .58 (about 782 ms). The whole UI therefore disappeared roughly 136 ms before the hero's lighting collapse began, with no shared response at Enter.

## New choreography

Both preview outcomes now begin with `requestAuthentication()`. The success shortcut starts the existing `successProgress` timeline at the same instant as the submit, then the preview adapter reports its simulated success after 360 ms. `completePreviewSuccess()` changes the phase without restarting that timeline. The phase boundary therefore does not restart the shader's progress or the tension response.

The success curve remains 1480 ms `InOutCubic`; its duration, curve, shader source, and 16 ms shader clock were not changed. One progress value now coordinates the UI and the existing shader:

| Element | Progress range | Approximate time from Enter |
| --- | --- | ---: |
| Auth panel | .05 → .50 | 344 → 740 ms |
| Brand and system chrome | .30 → .78 | 624 → 918 ms |
| Ring convergence begins | .08 | 402 ms |
| Body compression begins | .20 | 545 ms |
| Hero lighting collapse begins | .58 | 782 ms |
| Final shader frame | 1.00 | 1480 ms |

The panel begins to recede while the rings are already converging. Brand and system chrome remain longer, then fade while the hero darkens. `successPresence()` uses a bounded smoothstep over the shared progress, not new per-component timers. The shader still multiplies to exact zero at progress 1 over an `#000000` background.

At submit, authentication tension now enters over 360 ms with `OutCubic`, so the first part of the response is visible in the first 100–200 ms and then settles. Release remains 440 ms `InOutCubic`. A read-only phase-derived `authenticationTensionActive` stays true through `AUTHENTICATING`, `FAILURE`, and `SUCCESS`; it changes only when entering or leaving that group. This prevents the phase change to `SUCCESS` from restarting the tension animation and keeps failure from reversing the hero while its result animation is active.

The auth hint uses one text node. It dissolves to zero at the midpoint of the same tension value, changes from the idle hint to “Preparing your space” at zero opacity, and then resolves into the single failure hint through `failureProgress`. This avoids two strings being composited on top of each other. The input text is still cleared immediately and is never retained or logged. The focused underline contracts using its existing 240 ms `OutCubic` behavior; the form and identity only lose 12% and 8% presence as tension builds.

Escape still cancels the adapter timers and stops the success timeline before returning. Repeated submits remain rejected by the phase guard. `PreviewAuthenticator` keeps real authentication out of scope; its 360 ms success is a visual preview result only.

## Cadence and validation

The fixed `shaderClock` remains at 16 ms (62.5 nominal time updates/s). The normal preview's QSG diagnostic reported a 5.56 ms VSync animation driver on the 180 Hz display and warm GUI polish intervals with a 15 ms median, 16 ms p95, and 17 ms p99/max. It also reported occasional shorter 2–7 ms intervals; these are render-loop callbacks, not shader-clock updates. The QSG log had no QML `WARN` or `ERROR` lines. Qt's log does not expose compositor presentation timestamps, so these figures establish that the 16 ms cadence was not coarsened again; they are not a scanout measurement.

The 18 QML checks pass, including rapid wake/type/submit, Enter failure, Ctrl+Enter success, Escape cancellation of both pending result paths, success after failure, repeated submission, password clearing, long input, Backspace, and mouse submit. `qmllint`, QSB build, `glslangValidator`, and `bash -n` pass. No fragment shader source changed; the rebuilt QSB hash matches the saved 0.4 snapshot.

Preview state images at 1920×1080 are in [`screenshots/auth-motion-0.4b/`](screenshots/auth-motion-0.4b/). They were captured through the existing QML preview capture path, including a frame about 90 ms after simulated Enter. They document representative frames, not a recording. The CUA native-window inventory was empty in this environment, so keyboard/mouse behavior could be tested in QML tests but the final interactive motion could not be watched or recorded independently as a person would see it. The real preview did run with the threaded Qt Quick renderer; no claim about compositor scanout or subjective live motion is inferred from static captures.

## Restore

Run [`scripts/restore-umbra-0.4.sh`](../scripts/restore-umbra-0.4.sh) to restore the hash-checked snapshot at `backups/umbra-0.4-before-auth-motion/`. It restores project files only and does not touch display-manager, PAM, boot, login services, or system configuration.
