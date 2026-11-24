# YuZora minimal lights-HAL build product.
#
# This is a build-only product: it exists so `lunch yuzora_lights-userdebug`
# can configure Soong for a single-module build of
# android.hardware.light-service.samsung. It is NOT a device definition and
# must never be used to build a system image — it inherits no device tree,
# no vendor blobs, no kernel.
#
# The only job of the product is to set the samsungVars soong config
# namespace (target_specific_header_path) so the HAL's
# samsung_header_path_defaults resolves include_dirs to our vendored
# include/samsung_lights.h (the a71-common override header: PANEL nodes
# only, no LED_BLINK_NODE — see docs/re-lights.md §1.2 and the #ifdef
# LED_BLINK_NODE trap in docs/re-lights.md §6.1).

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/yuzora_lights.mk

COMMON_LUNCH_CHOICES := \
    yuzora_lights-userdebug
