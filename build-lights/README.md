# Minimal-manifest lights HAL build

Builds **only** `android.hardware.light-service.samsung` from the fork
`kkisdevil/android_hardware_samsung` (branch `lineage-22.2`, no-op
NOTIFICATIONS light commit `e7968ab`) on GitHub Actions, using a minimal
`repo` manifest instead of a full LineageOS sync.

## Why minimal

A full LineageOS 22.2 sync is ~100 GB. A GitHub Actions runner has ~14 GB
usable disk. The dependency closure of the one module, traced file-by-file
from the real `.bp` files (2026-11-24), is **32 projects** — small enough
to fit with headroom.

## The closure (how each project was found)

Starting point: the fork's `aidl/light/Android.bp` (read live at
`lineage-22.2`):

- `cc_binary android.hardware.light-service.samsung`, `vendor: true`,
  `defaults: ["samsung_header_path_defaults"]`, srcs `Lights.cpp` +
  `service.cpp`, shared libs `libbase`, `libbinder_ndk`,
  `android.hardware.light-V2-ndk`, plus `init_rc` and `vintf_fragments`.
- `samsung_header_path_defaults` is defined in the fork's **root**
  `Android.bp` as a `soong_config_module_type` over the `samsungVars`
  namespace, variable `target_specific_header_path` — the value is set by
  the device tree's `BoardConfig.mk` via `$(call soong_config_set,...)`.
  `soong_config_set` itself is defined in `build/make/core/config.mk`
  (~line 315, verified live). The a71-common tree uses the identical call
  at `BoardConfigCommon.mk:148` — this is the working precedent.
- The root `.bp` also has a `soong_namespace` importing
  `hardware/google/pixel` + `hardware/google/interfaces` — both must sync
  or Soong refuses to load the namespace.

Then the transitive `.bp` walk (each file read live at
`android-15.0.0_r32` or `lineage-22.2`):

| Module | Needs | Project |
|---|---|---|
| `android.hardware.light` AIDL v1+v2 | the interface itself; `-V2-ndk` is auto-generated | `hardware/interfaces` |
| `aidl` host tool | `libaidl-common` → `aidl_defaults` → `libbase`, `libgtest`, `libgtest_prod_headers` | `system/tools/aidl`, `system/libbase`, `external/googletest` |
| `libbase` | whole-static `fmtlib` | `external/fmtlib` |
| `libbinder_ndk` | static `libandroid_runtime_lazy` + `libbase`; shared `libbinder`, `liblog`, `libutils`; header `jni_headers` | `frameworks/native`, `system/logging`, `system/core`, `libnativehelper` |
| `libbinder` | `libcutils`, `liblog`, `libutils`, `libbase`, `jni_headers`, `libbinder_headers`, `libapexsupport`, `libvndksupport` | `system/core`, `system/apex` |
| `libutils` / `libcutils` | `liblog`, `libvndksupport`, `libprocessgroup`, `libbase`, `libasync_safe` | `system/core`, `bionic` |
| `libandroid_runtime_lazy` | `liblog`, `libutils`, `jni_headers`, `libbinder_headers` | `frameworks/native` (same repo) |
| `libapexsupport` (Rust) | rustlibs `libapex_manifest_rs` + `libprotobuf` | `system/apex` (the manifest rs is a `rust_protobuf` in `system/apex/proto/Android.bp` — same repo), `external/rust/android-crates-io` (`libprotobuf` + `libbytes`, `libonce_cell`, `libprotobuf_support`, `libthiserror`, all under `crates/`) |
| Rust toolchain | `rustc` | `prebuilts/rust` |
| Soong itself | Go toolchain, `ninja`/host tools, `afdo_profiles.mk` (hard include in `soong_config.mk`) | `prebuilts/go/linux-x86`, `prebuilts/build-tools`, `toolchain/pgo-profiles` |
| Soong's `soong_ui` binary | Go protobuf runtime (`google.golang.org/protobuf/proto`, imported by `android/soong/ui/metrics`) — Soong maps the import to `external/golang-protobuf/proto`; missing it kills the build in 5s (run #9) | `external/golang-protobuf` |
| Soong's `rbcrun` | Starlark-in-Go runtime (`go.starlark.net/starlark`, required by `build/soong/go.mod`) — without `external/starlark-go/starlark` the build dies with "Failed to find deps of rbcrun/rbcrun" (run #12); AOSP `platform/external/starlark-go`, tag `android-15.0.0_r32` | `external/starlark-go` |
| Soong bootstrap (`bootstrap blueprint`) | `external/golang-protobuf/Android.gen.bp` defines `golang-protobuf-internal-order` with a blueprint dep on module `go-cmp` — a blueprint-level dep, not a Go import, so the earlier `.go`-import grep (which claimed protobuf was the only Go module needed) could not see it; without it bootstrap dies with `"golang-protobuf-internal-order" depends on undefined module "go-cmp"` (run #24); AOSP `platform/external/go-cmp`, tag `android-15.0.0_r32` | `external/go-cmp` |
| Soong bootstrap (`bootstrap blueprint`) | `hardware/interfaces/compatibility_matrices/build/Android.bp` defines `vintf-compatibility-matrix-soong-rules` with blueprint deps on `kernel-config-soong-rules` + `soong-selinux`; `build/make/tools/compliance/Android.bp` defines `compliance_sbom` with blueprint deps on five spdx-tools Go modules (`spdx-tools-spdxv2_2`, `spdx-tools-builder2v2`, `spdx-tools-spdxcommon`, `spdx-tools-spdx-json`, `spdx-tools-spdxlib`) — without them bootstrap dies with `"depends on undefined module"` (run #27). The kernel-config repo is top-level `kernel/configs`, NOT `platform/kernel/config` (that path 404s) | `kernel/configs`, `system/sepolicy`, `external/spdx-tools` |
| Soong bootstrap (`bootstrap blueprint`) | `hardware/interfaces/Android.bp` + `hardware/google/interfaces/Android.bp` declare `hidl_package_root` modules and every `hardware/*/interfaces/*/*.bp` declares `hidl_interface` modules — both types are registered ONLY by the `hidl-soong-rules` plugin (`bootstrap_go_package`, `pluginFor: ["soong_build"]`) in `system/tools/hidl/build/`; without that project bootstrap compiles all 112 steps, then the ninja-file generation dies with `unrecognized module type "hidl_interface"` (and `"hidl_package_root"`) (run #30). Its deps are soong-internal only, so no further project is needed | `system/tools/hidl` |
| Soong bootstrap (`bootstrap blueprint`) | `kernel/configs/xsd/*`, `hardware/interfaces/tv/tuner/config/*`, `hardware/interfaces/audio/*`, `hardware/interfaces/bluetooth/audio/utils/*` and `system/apex/apexd/*` declare `xsd_config` modules — the type is registered ONLY by the `xsdc-soong-rules` plugin (`bootstrap_go_package`, `pluginFor: ["soong_build"]`) in `system/tools/xsdc/build/` (`build/xsdc.go`); without that project bootstrap compiles all 113 steps, then the ninja-file generation dies with `unrecognized module type "xsd_config"` (run #33). Its deps (`blueprint`, `soong`, `soong-android`, `soong-java`) are all in `build/soong`, already synced, so no further project is needed | `system/tools/xsdc` |
| Clang + libc++ | `clang-r536225` (LLVM 19) — **LineageOS 22.2's `ClangDefaultVersion`**, verified identical in AOSP r32 | `prebuilts/clang/host/linux-x86` |
| Build engine | `envsetup.sh`, `lunch`, `m` | `build/make`, `build/soong`, `build/blueprint` |
| Release configs | `trunk_staging` + the release map (`build/make/core/release_config.mk` reads `build/release/release_config_map.mk`; without it `ALL_RELEASE_CONFIGS_FOR_PRODUCT` is empty and lunch dies with `No release config found for TARGET_RELEASE`) | `build/release` (34 MB) |

**Traps found while tracing (do not re-introduce):**

- `external/libcxx` is a 38-line trusty **stub** at r32 — Android 15 builds
  libc++ as part of the Clang prebuilt. Do NOT add `external/libcxx` /
  `external/libcxxabi`; the prebuilt provides `libc++` / `libc++abi_shared`.
- `system/libbase` is **AOSP** (`platform/system/libbase`) — there is no
  `LineageOS/android_system_libbase` repo.
- `libasync_safe` lives in **bionic**, not `system/core`.
- `libapexsupport` lives in `system/apex`, not `system/core`.
- `libapex_manifest_rs` is **not** in `android-crates-io` (404 for
  `crates/apex-manifest` and `crates/apex_manifest`) — it is a
  `rust_protobuf` generated from `system/apex/proto/apex_manifest.proto`.
- `jni_headers` is defined in top-level `libnativehelper`
  (`platform/libnativehelper`), not under `frameworks/native`.
- `aidl` skips `classes2.dex` — irrelevant here, but the same "silent
  skip" lesson applies: the workflow verifies every expected file
  explicitly instead of trusting a green step.
- `afdo: true` on libbinder is harmless without a configured profile.
- The `repo` tool's `git archive --remote` does **not** work against
  googlesource; raw reads / `git ls-remote` are the verification routes.
  (`git ls-remote` to github.com is ~1.6 s; to googlesource ~37 s.)

## Pins

| Project | Pin | Verified HEAD / note |
|---|---|---|
| `build/make` | LineageOS `lineage-22.2` | `ab5acb12…` |
| `build/soong` | LineageOS `lineage-22.2` | `7330e4ab…` |
| `build/blueprint` | LineageOS `lineage-22.2` | `c7c63940…` |
| `bionic` | LineageOS `lineage-22.2` | `30951077…` |
| `system/logging` | LineageOS `lineage-22.2` | `0a02c4d1…` |
| `system/core` | LineageOS `lineage-22.2` | `bcb86232…` |
| `frameworks/native` | LineageOS `lineage-22.2` | `19863e8c…` |
| `hardware/interfaces` | LineageOS `lineage-22.2` | `722793b7…` |
| `hardware/google/pixel` | LineageOS `lineage-22.2` | `1dee182b…` |
| `hardware/samsung` | **kkisdevil fork** `lineage-22.2` | `e7968ab68b15d9bda03c267195c2bfb0af986874` |
| all `platform/*`, `toolchain/*` | AOSP `android-15.0.0_r32` | tag, not branch |
| `hardware/google/interfaces` | AOSP `android-15.0.0_r32` | tag |

Full SHAs are in the comments of `manifest.xml`. LineageOS repos are
pinned to the **branch** (so fix-and-repeat picks up new commits);
AOSP repos to the **tag** (stable base). The fork is pinned to its
`lineage-22.2` branch — the no-op light commit `e7968ab` is its tip at
verification time; the workflow fails loudly if the synced code lacks
`handleNotificationsNoOp`.

## Disk / time budget (estimated)

- Sync (depth 1, no tags, 32 projects): **~5 GB** (largest: clang
  prebuilt ~2 GB, frameworks/native + system/core + bionic ~1 GB
  combined, prebuilts/rust + crates-io ~0.8 GB).
- Build output (`out/`): **~1–2 GB** (Soong bootstrap + compiled libs +
  the one binary).
- Total **~7 GB** vs ~14 GB usable on `ubuntu-24.04` — ~7 GB headroom.
- Time: sync ~10–20 min, Soong bootstrap + build ~15–30 min.
  Workflow timeout is 120 min.

## Files in this directory (and where they go in the fork)

The parent uploads these to `kkisdevil/android_hardware_samsung`,
branch `lineage-22.2`:

| Local file | Destination in the fork |
|---|---|
| `manifest.xml` | `build-lights/manifest.xml` |
| `build-lights-hal.yml` | `.github/workflows/build-lights-hal.yml` |
| `device/yuzora/yuzora_lights/*` | `build-lights/device/yuzora/yuzora_lights/*` |
| `README.md` (this file) | `build-lights/README.md` |

The workflow's `repo init -u <fork> -m build-lights/manifest.xml`
fetches the manifest from the fork, and the device files from
`.repo/manifests/build-lights/device/` after sync. **The first run fails
at `repo init` until all four uploads land.**

## The device files (what they are)

- `device/yuzora/yuzora_lights/AndroidProducts.mk` — declares the
  `yuzora_lights-trunk_staging-userdebug` product.
- `device/yuzora/yuzora_lights/yuzora_lights.mk` — build-only product: inherits
  only `aosp_arm64.mk`. No device tree, no vendor blobs, no kernel.
  Never use it to build a system image.
- `device/yuzora/yuzora_lights/BoardConfig.mk` — sets
  `samsungVars/target_specific_header_path` to
  `device/yuzora/yuzora_lights/include` (the `soong_config_set` call) and pins
  the board arch to arm64.
- `device/yuzora/yuzora_lights/include/samsung_lights.h` — verbatim copy of the
  a71-common override header: `PANEL_BRIGHTNESS_NODE` +
  `PANEL_MAX_BRIGHTNESS_NODE` only. **No `LED_BLINK_NODE`, no
  `BUTTON_BRIGHTNESS_NODE`** — that absence is exactly why the fork's
  no-op handler is unconditional (docs/re-lights.md §6.1 trap).

## What the workflow verifies (in order)

1. All 32 projects synced; `soong_config_set` defined; HAL `.bp` uses
   `samsung_header_path_defaults`; `clang-r536225` present.
2. Device files copied from the manifest repo.
3. Fork HEAD + `handleNotificationsNoOp` / `LightType::NOTIFICATIONS`
   present in the synced `Lights.cpp`; header has `PANEL_BRIGHTNESS_NODE`
   and does **not** define `LED_BLINK_NODE`; BoardConfig sets the soong
   config path.
4. `m android.hardware.light-service.samsung` succeeds.
5. Output binary exists, is AArch64 ELF, and the **unstripped** copy
   contains the `handleNotificationsNoOp` symbol (proof the fork's code
   compiled in).
6. Artifact `lights-hal-m51` (14 days): the binary, its `.rc`, its VINTF
   fragment, `build-lights.log`, `BUILD_INFO.txt` (fork SHA, size, sha256).

## Known failure modes (first things to try)

| Symptom | Likely cause | Fix |
|---|---|---|
| `repo init`: manifest not found | `build-lights/manifest.xml` not uploaded to the fork yet | Upload it (see table above) |
| `repo sync` fails on one project | Flaky fetch / rate limit | Workflow retries 3×; if a project 404s, its pin (branch/tag) moved — re-verify with `git ls-remote` |
| `Build lights HAL` fails in 0s: `vendor/lineage/build/envsetup.sh: No such file or directory` (run #4) | LineageOS `build/envsetup.sh` ends with an **unguarded** `. $ANDROID_BUILD_TOP/vendor/lineage/build/envsetup.sh`, and the minimal manifest deliberately does not sync `vendor/lineage` | The workflow's "Stub vendor/lineage envsetup.sh" step creates a stub with the real file's only top-level side effect (the `CLANG_VERSION` / `LLVM_AOSP_PREBUILTS_VERSION` export); do **not** sync the whole `vendor/lineage` tree for this |
| `Build lights HAL` fails: `Invalid lunch combo: yuzora_lights-userdebug` / `Valid combos must be of the form <product>-<release>-<variant>` (run #6) | LineageOS 22.2's `lunch()` (`build/envsetup.sh`) requires a **three-part** combo `<product>-<release>-<variant>`; the workflow used the old two-part `product-variant` form, so the variant parsed empty and lunch failed before compiling anything | Lunch `yuzora_lights-trunk_staging-userdebug` (workflow build step + `COMMON_LUNCH_CHOICES` in `AndroidProducts.mk`); `trunk_staging` is the default release |
| `lunch` fails `check_product: command not found`, then `roomservice.py: No such file or directory` (run #6 latent — would have hit right after the combo fix) | Both live only in the real `vendor/lineage` tree, which the minimal manifest deliberately does not sync; the run #4 stub only covered the top-level export | The stub step now also defines `check_product` (verbatim from LineageOS `vendor/lineage/build/envsetup.sh`) and creates a no-op `vendor/lineage/build/tools/roomservice.py` (exits 0; the real script fetches missing device repos, which this build-only product never needs) |
| `No release config found for TARGET_RELEASE: trunk_staging` (run #6 latent) | Release configs live in `build/release` (`LineageOS/android_build_release`), which was not in the manifest — with no map, `ALL_RELEASE_CONFIGS_FOR_PRODUCT` is empty | Manifest now syncs `build/release` (34 MB); the verify step checks the map + `trunk_staging.textproto` exist |
| `Build lights HAL` fails in 5s: `Failed to find deps of android/soong/cmd/soong_ui: Error parsing directory .../external/golang-protobuf/proto: no such file or directory` (run #9) | Soong's `soong_ui` binary imports `google.golang.org/protobuf/proto` (`android/soong/ui/metrics`); the minimal manifest did not sync the Go protobuf runtime | Manifest now syncs `external/golang-protobuf` (AOSP `platform/external/golang-protobuf`, tag `android-15.0.0_r32`); the verify step checks `external/golang-protobuf/proto` exists. NOTE: the original row claimed protobuf was the only missing Go module — run #12 proved that wrong (starlark was missing too), and run #24 proved it wrong again in a different dimension: `build/soong/go.mod` needs exactly three Go modules (blueprint, protobuf, starlark), but `golang-protobuf`'s own `Android.gen.bp` needs a fourth Go module, `go-cmp`, as a blueprint-level dep — see the run #24 row |
| `Build lights HAL` fails: `No config file found for TARGET_DEVICE yuzora_lights` (run #15) | `build/make/core/board_config.mk` looks up the board config with a wildcard `device/*/$(TARGET_DEVICE)/BoardConfig.mk` — the leaf directory name MUST equal `TARGET_DEVICE`. The device files lived in `device/yuzora/lights/` while `PRODUCT_DEVICE` is `yuzora_lights`, so the lookup found nothing. (Runs #9/#12 never reached this: Soong's Go-module bootstrap failed first.) | Device directory renamed to `device/yuzora/yuzora_lights/` (BoardConfig `soong_config_set` path, workflow checks and README updated to match); the old `device/yuzora/lights/` directory was deleted |
| `Build lights HAL` fails 7s in: `fixup_common_out_dir: command not found` (run #23) | `_lunch_meat()` (`build/envsetup.sh` line 559) calls `fixup_common_out_dir`, which is defined ONLY in the real `vendor/lineage/build/envsetup.sh` — the minimal manifest deliberately does not sync `vendor/lineage`, and the run #4 stub did not define it | The stub step now also defines `fixup_common_out_dir` verbatim from LineageOS `vendor/lineage/build/envsetup.sh` (it (re)creates `out/target/common`; `LINEAGE_FIXUP_COMMON_OUT` is unset here, so it takes the plain `mkdir` branch) |
| `Build lights HAL` fails 18s in: `error: external/golang-protobuf/Android.gen.bp:559:1: "golang-protobuf-internal-order" depends on undefined module "go-cmp"` (run #24, 12m33s) | `external/golang-protobuf/Android.gen.bp` defines `golang-protobuf-internal-order` with a blueprint dep on the `go-cmp` Go module (`github.com/google/go-cmp/cmp`); the minimal manifest synced `external/golang-protobuf` but not `external/go-cmp`. The dep is blueprint-level, not a Go import — the earlier `.go`-import grep that claimed protobuf was the only Go module needed could not see it | Manifest now syncs `external/go-cmp` (AOSP `platform/external/go-cmp`, tag `android-15.0.0_r32`); the verify step checks `external/go-cmp/cmp` exists. The module is defined by `external/go-cmp/Android.gen.bp` itself (`bootstrap_go_package "go-cmp"`); all of its deps are internal to the repo, so no further project is needed |
| `Build lights HAL` fails 13s in: `error: hardware/interfaces/compatibility_matrices/build/Android.bp:24:1: `"vintf-compatibility-matrix-soong-rules" depends on undefined module "kernel-config-soong-rules"` (+ `soong-selinux`, + five `spdx-tools-*` modules for `compliance_sbom`) (run #27, 12m0s; runs #25/#26 failed the same way) | Soong bootstrap parses every synced `.bp` file, and `hardware/interfaces/compatibility_matrices/build/Android.bp` + `build/make/tools/compliance/Android.bp` reference Soong plugin modules from projects the minimal manifest never synced. Blueprint-level deps again — no `.go`-import grep can see them | Manifest now syncs `kernel/configs` (top-level repo; defines `kernel-config-soong-rules` in `build/Android.bp`), `system/sepolicy` (defines `soong-selinux` in `build/soong/Android.bp`) and `external/spdx-tools` (defines all five `spdx-tools-*` modules; every spdx-tools `.bp` dep is another spdx-tools module in the same repo or `go-cmp`, already synced); the verify step checks all three. The closure is only proven by a green bootstrap |
| `Build lights HAL` fails 32s in: `error: hardware/interfaces/Android.bp:31:1: unrecognized module type "hidl_package_root"` (+ `hardware/google/interfaces/Android.bp:8:1` and eleven `unrecognized module type "hidl_interface"` in `hardware/google/interfaces/*`) (run #30, 13m46s) | `hidl_interface` + `hidl_package_root` are registered only by the `hidl-soong-rules` Soong plugin in `system/tools/hidl/build/` (`hidl_interface.go` `init()`); the minimal manifest never synced `system/tools/hidl`, so `soong_build` was built without the plugin. Bootstrap itself completed all 112 steps (the run #27 fix worked) — the failure is at ninja-file generation, one layer deeper | Manifest now syncs `system/tools/hidl` (AOSP `platform/system/tools/hidl`, tag `android-15.0.0_r32`); the verify step checks `hidl-soong-rules` is in `system/tools/hidl/build/Android.bp` and `hidl_interface` is registered in `hidl_interface.go`. This project also provides the `hidl-gen` host tool the plugin invokes |
| `Build lights HAL` fails 22s in: `error: kernel/configs/xsd/approvedBuild/Android.bp:24:1: unrecognized module type "xsd_config"` (+ 13 more in `kernel/configs/xsd/*`, `hardware/interfaces/tv/tuner/config`, `hardware/interfaces/audio/*`, `hardware/interfaces/bluetooth/audio/utils`, `system/apex/apexd`) (run #33, 13m32s; runs #31/#32 failed the same way on the same fix code) | `xsd_config` is registered only by the `xsdc-soong-rules` Soong plugin in `system/tools/xsdc/build/` (`build/xsdc.go` `init()` calls `android.RegisterModuleType("xsd_config", ...)`); the minimal manifest never synced `system/tools/xsdc`, so `soong_build` was built without the plugin. Bootstrap itself completed all 113 steps (the run #30 hidl fix worked) — the failure is at ninja-file generation, one layer deeper. CAUTION: an early read of the #33 log page rendered wrong error lines (a phantom `lights-service.samsung.so` link failure with `hidl-gen` / `lights@2.0`); the verbatim re-read is authoritative — the log never mentions the `.so`, and all 14 errors are `unrecognized module type "xsd_config"` | Manifest now syncs `system/tools/xsdc` (AOSP `platform/system/tools/xsdc`, tag `android-15.0.0_r32`); the verify step checks `xsdc-soong-rules` is in `system/tools/xsdc/build/Android.bp` and `xsd_config` is registered in `build/xsdc.go`. The `xsdc` host tool itself is only built if an `xsd_config` module is in the build closure — it is not, so no Java deps are needed |
| `lunch` cannot find `yuzora_lights-trunk_staging-userdebug` | device files not copied (manifest repo layout) | Check the "Install device files" step log; `device/*/AndroidProducts.mk` must exist before `lunch` |
| Soong: `samsung_header_path_defaults` unknown / `target_specific_header_path` unset | BoardConfig `soong_config_set` call missing or misspelled | Compare with `device/yuzora/yuzora_lights/BoardConfig.mk`; the namespace is `samsungVars`, the variable is `target_specific_header_path` |
| Soong: clang version dir not found | prebuilts/clang pin drifted from soong's `ClangDefaultVersion` | Check `cc/config/global.go` in the synced soong; set `LLVM_PREBUILTS_VERSION` or re-pin prebuilts/clang |
| `aidl` build fails on missing `libgtest_prod_headers` | `external/googletest` not synced | It is in the manifest — check the sync verification step |
| Link error: `libapexsupport` / Rust crate missing | `prebuilts/rust` or `android-crates-io` not synced | Both are in the manifest; check sync step |
| `handleNotificationsNoOp` not in unstripped binary | Synced `hardware/samsung` is upstream, not the fork | Check the fork-HEAD line in the log; `hardware/samsung` must be `kkisdevil/android_hardware_samsung` |
| Disk full during build | Runner disk smaller than expected | The workflow already frees ~10 GB first; if still short, the only safe cut is `prebuilts/go` docs — do not cut clang/rust (both required) |
| `m` fails demanding Java | A java module crept into the closure | Not expected for this module set; add `openjdk-17-jdk-headless` to the apt step if it ever happens |

## What this build does NOT prove

- That the HAL **runs**: the binary is only verified as AArch64 ELF
  containing the fork's symbol. First-boot logcat on the m51 settles
  which lights service starts, whether `getLights()` reports id 4, and
  whether Xiaomi's padding loop behaves with a real (ordinal 0)
  NOTIFICATIONS light (docs/re-lights.md §3.7, §8).
- That brightness is correct: the RRO overlay with the stock a71-common
  brightness tables is separate work (re-lights §6.3).
