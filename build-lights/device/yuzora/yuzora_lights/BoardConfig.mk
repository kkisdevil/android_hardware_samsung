# YuZora minimal lights-HAL build — BoardConfig.
#
# The single thing this file must do: set the samsungVars soong config
# namespace so the HAL's samsung_header_path_defaults (defined in
# hardware/samsung/Android.bp as a soong_config_module_type over the
# samsungVars namespace, variable target_specific_header_path) resolves
# include_dirs to our vendored override header.
#
# How it works:
#   hardware/samsung/Android.bp defines:
#     soong_config_module_type { name: "samsung_header_path",
#       config_namespace: "samsungVars",
#       value_variables: ["target_specific_header_path"], ... }
#     samsung_header_path { name: "samsung_header_path_defaults",
#       soong_config_variables: { target_specific_header_path:
#         { include_dirs: ["%s"] } } }
#   hardware/samsung/aidl/light/Android.bp uses
#     defaults: ["samsung_header_path_defaults"]
#   soong_config_set (defined in build/make/core/config.mk, line ~315 —
#   a standard make function; the a71-common tree uses the identical call
#   at BoardConfigCommon.mk:148) registers the namespace + variable.
#
# The header itself is device/yuzora/yuzora_lights/include/samsung_lights.h — a
# verbatim copy of the a71-common override (PANEL_BRIGHTNESS_NODE and
# PANEL_MAX_BRIGHTNESS_NODE only; NO LED_BLINK_NODE, NO
# BUTTON_BRIGHTNESS_NODE). That absence is exactly why the fork's
# no-op NOTIFICATIONS handler is unconditional (docs/re-lights.md §6.1
# trap): anything inside #ifdef LED_BLINK_NODE never compiles for m51.
#
# TARGET_ARCH must be arm64: the HAL is a vendor module built for the
# device, not the host. aosp_arm64.mk sets the product arch; these two
# lines pin the board side explicitly so a future product change cannot
# silently flip the HAL to a host build.

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a

$(call soong_config_set,samsungVars,target_specific_header_path,device/yuzora/yuzora_lights/include)
