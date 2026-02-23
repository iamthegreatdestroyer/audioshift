#pragma once

#include <media/EffectApi.h>
#include <hardware/audio_effect.h>
#include <memory>
#include <cstdint>

namespace android {

// AudioShift 432Hz Effect UUID
static constexpr char kAudioShift432EffectUUID[] =
    "f22a9ce0-7a11-11ee-b962-0242ac120002";

class AudioShift432Effect {
public:
    AudioShift432Effect();
    ~AudioShift432Effect();

    // Process audio buffer
    int32_t process(int16_t* buffer, uint32_t frameCount);

    // Effect command handler
    int32_t command(uint32_t cmdCode, uint32_t cmdSize, void* pCmdData,
                    uint32_t* replySize, void* pReplyData);

    // Get effect descriptor
    int32_t getDescriptor(effect_descriptor_t* pDescriptor);

    // Factory functions
    static int32_t effectCreate(const effect_uuid_t* uuid,
                                int32_t sessionId,
                                int32_t ioId,
                                effect_handle_t* pHandle);
    static int32_t effectRelease(effect_handle_t handle);

private:
    class Impl;
    std::unique_ptr<Impl> pImpl_;
};

// C-linkage effect library interface
extern "C" {
    audio_effect_library_t AUDIO_EFFECT_LIBRARY_INFO_SYM;
}

}  // namespace android
