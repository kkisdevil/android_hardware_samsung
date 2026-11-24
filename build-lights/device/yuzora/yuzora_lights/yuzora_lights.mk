# YuZora minimal lights-HAL build product.
#
# Build-only product for the single-module lights HAL build. Inherits only
# the bare AOSP arm64 product scaffolding (no device tree, no vendor blobs,
# no kernel) so `lunch yuzora_lights-userdebug` works with the minimal
# manifest. The HAL itself is vendor: true, so it lands in /vendor.

$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_arm64.mk)

PRODUCT_NAME := yuzora_lights
PRODUCT_DEVICE := yuzora_lights
PRODUCT_BRAND := YuZora
PRODUCT_MODEL := Lights HAL build product
PRODUCT_MANUFACTURER := YuZora

# The HAL is a vendor module; the product must be a vendor build for the
# module to be installable. aosp_arm64.mk already sets the product to
# vendor via its base inheritance; nothing else is needed here.
