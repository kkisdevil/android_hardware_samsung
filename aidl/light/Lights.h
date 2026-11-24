/*
 * Copyright (C) 2021 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * YuZora fork note (2026-11-24, kkisdevil/android_hardware_samsung,
 * fork point LineageOS/android_hardware_samsung lineage-22.2
 * 0365e8bd547af2644c6c06d903e212ce141587ca):
 * Declares handleNotificationsNoOp — the no-op NOTIFICATIONS handler
 * for the Galaxy M51 (no notification LED). Design: docs/re-lights.md
 * §5.2a + §6.1. The declaration is UNCONDITIONAL on purpose: the
 * a71-common override header defines no LED_BLINK_NODE, so a
 * declaration inside #ifdef LED_BLINK_NODE would never compile for
 * this tree (see the matching note in Lights.cpp).
 */

#pragma once

#include <aidl/android/hardware/light/BnLights.h>
#include <samsung_lights.h>

#include <functional>
#include <unordered_map>

using ::aidl::android::hardware::light::HwLightState;
using ::aidl::android::hardware::light::HwLight;

namespace aidl {
namespace android {
namespace hardware {
namespace light {

class Lights : public BnLights {
public:
    Lights();

    ndk::ScopedAStatus setLightState(int32_t id, const HwLightState& state) override;
    ndk::ScopedAStatus getLights(std::vector<HwLight> *_aidl_return) override;

private:
    void handleBacklight(const HwLightState& state);

    // YuZora fork: no-op NOTIFICATIONS handler (m51 has no LED).
    // Unconditional — must NOT sit inside #ifdef LED_BLINK_NODE, which
    // the a71-common override header never defines for this tree.
    void handleNotificationsNoOp(const HwLightState& state);

#ifdef BUTTON_BRIGHTNESS_NODE
    void handleButtons(const HwLightState& state);
#endif /* BUTTON_BRIGHTNESS_NODE */
#ifdef LED_BLINK_NODE
    void handleBattery(const HwLightState& state);
    void handleNotifications(const HwLightState& state);
    void handleAttention(const HwLightState& state);
    void setNotificationLED();
    uint32_t calibrateColor(uint32_t color, int32_t brightness);

    HwLightState mAttentionState;
    HwLightState mBatteryState;
    HwLightState mNotificationState;
#endif /* LED_BLINK_NODE */

    uint32_t rgbToBrightness(const HwLightState& state);

    std::mutex mLock;
    std::unordered_map<LightType, std::function<void(const HwLightState&)>> mLights;
};

} // namespace light
} // namespace hardware
} // namespace android
} // namespace aidl
