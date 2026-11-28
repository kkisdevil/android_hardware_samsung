# android_hardware_samsung — YuZora fork

Samsung hardware abstraction layers (HALs) for LineageOS 22.2 (Android 15),
forked from
[LineageOS/android_hardware_samsung](https://github.com/LineageOS/android_hardware_samsung)
(branch `lineage-22.2`).

This fork is the home of the **YuZora Lights HAL build**: a build-only
GitHub Actions workflow that compiles
`android.hardware.light-service.samsung` for the Galaxy M51 (SM-M515F)
from a minimal 32-project `repo` manifest, without a full LineageOS sync.
It is part of the YuZora porting work for the M51 (UN1CA One UI and
HyperOS), kept open source with credits below.

## What is in this tree

The standard LineageOS Samsung HAL tree, plus the YuZora changes:

| Directory | Contents |
|---|---|
| `aidl/` | AIDL HALs, including `aidl/light/` — the Lights HAL this fork builds |
| `fingerprint/` | Fingerprint HAL |
| `sensors/` | Sensors HAL |
| `hidl/` | HIDL HALs (livedisplay and others) |
| `interfaces/` | Hardware interface definitions |
| `ril/` | Radio interface layer (Samsung RIL) |
| `doze/` | Samsung Doze |
| `dap/` | Samsung DAP (audio) |
| `AdvancedDisplay/` | Advanced display features |
| `vintf/` | VINTF manifests and compatibility matrices |
| `dtbhtool/`, `loki_tool/`, `rebalance_interrupts/` | Samsung device tooling |
| `build-lights/` | The YuZora minimal-manifest Lights HAL build (manifest, stubs, docs) |
| `.github/workflows/` | GitHub Actions workflows, including `build-lights-hal.yml` |

The fork's own source change to the HAL is the **no-op NOTIFICATIONS
light** (`e7968ab`): the M51 has no notification LED, so the Lights HAL
is BACKLIGHT only and the notifications light is a no-op that returns
success. See `aidl/light/`.

## The Lights HAL build

Workflow: **Build lights HAL** (`.github/workflows/build-lights-hal.yml`).
It builds only `android.hardware.light-service.samsung` — nothing else,
flashes nothing, touches no recovery partition.

- **Why minimal:** a full LineageOS 22.2 sync is ~100 GB; a GitHub
  Actions runner has ~14 GB usable disk. The dependency closure of the
  one module, traced file-by-file from the real `.bp` files, is
  **32 projects** — small enough to fit with headroom.
- **The service:** `cc_binary android.hardware.light-service.samsung`
  (`vendor: true`), sources `Lights.cpp` + `service.cpp`, shared libs
  `libbase`, `libbinder_ndk`, `android.hardware.light-V2-ndk`.
- **How to run it:** Actions tab → "Build lights HAL" → Run workflow,
  branch `lineage-22.2`. The workflow restores a repo cache, syncs the
  minimal manifest, prunes subtrees the HAL never needs, stubs the
  remaining missing modules, then runs
  `lunch yuzora_lights-trunk_staging-userdebug` and
  `m android.hardware.light-service.samsung`.
- **Status:** under active development — the build is currently working
  through Soong's dependency-resolution phase (each run surfaces the
  next wave of undefined modules, which are stubbed or pruned in the
  next fix round). See the Actions tab for the latest run.
- **Full documentation:** [`build-lights/README.md`](build-lights/README.md)
  — the closure table, pins, disk/time budget, the complete run-by-run
  failure history, and every lesson learned. That is the authoritative
  doc for the build; this file is the overview.

## Building locally

The workflow is the supported route (GitHub-hosted runners, no local
setup). The same manifest and scripts can be run locally with the
`repo` tool, `lunch yuzora_lights-trunk_staging-userdebug`, and `m` —
see `build-lights/README.md` for the project list and pins. A local
build needs roughly 7 GB free (about 5 GB sync + 1–2 GB output).

## Credits

- [LineageOS](https://lineageos.org/) — the upstream tree this fork is
  built on.
- [AOSP](https://source.android.com/) (Android 15.0.0_r32) — the base
  platform and the pinned prebuilt/toolchain projects.
- YuZora (Kartik Deepak Sormare) — the Lights HAL build, the minimal
  manifest, and the stub/prune fix rounds.
- The UN1CA project ([salvogiangri/UN1CA](https://github.com/salvogiangri/UN1CA))
  and the M51 porters whose trees and guides informed the wider M51
  porting effort — see the UN1CA repositories for their credits.

## License

Apache License 2.0, as the upstream LineageOS tree. See `NOTICE` where
present in the individual projects.
