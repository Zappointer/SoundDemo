//
//  AMPlayer.m
//  AudioModem
//
//  Created by Tarek Belkahia on 11/01/13.
//
//

#import "AMPlayer.h"
#import <sstream>
#import "LDPCGenerator.h"

#define AUDIO_CHANNEL_TYPE Float32

using namespace std;

static const unsigned char ParityTable256[256] =
{
#   define P2(n) n, n^1, n^1, n
#   define P4(n) P2(n), P2(n^1), P2(n^1), P2(n)
#   define P6(n) P4(n), P4(n^1), P4(n^1), P4(n)
    P6(0), P6(1), P6(1), P6(0)
};

static unsigned char barkerbin[BARKER_LEN] = {
    0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0
};

void HandleOutputBuffer(void * inUserData,
                       AudioQueueRef inAQ,
                       AudioQueueBufferRef inBuffer) {
    AQPlayState * pPlayState = (AQPlayState *)inUserData;

    if ( ! pPlayState->mIsRunning) {
        return;
    }

    // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    UInt32 numBytesToPlay = inBuffer->mAudioDataBytesCapacity;
    UInt32 numPackets = numBytesToPlay/pPlayState->mDataFormat.mBytesPerPacket;

	AUDIO_CHANNEL_TYPE * buffer = (AUDIO_CHANNEL_TYPE *)inBuffer->mAudioData;

    printf("playing from : %1.5f (#%lld)\n", pPlayState->mCurrentPacket/(float)SR, pPlayState->mCurrentPacket);
    printf("message length: %d samples\n", pPlayState->mMessageLength);
    const double amplitude = 1;
    const double TWOPI = 2.0*M_PI;
    double freq = 18000.0;
    double step = SR/freq;
    double single_theta = TWOPI * freq / SR;
    double freq2 = 19000.0;
    double single_theta2 = TWOPI * freq2 / SR;
    double step2 = SR/freq2;
    UInt32 size = pPlayState->bufferByteSize/sizeof(AUDIO_CHANNEL_TYPE);
    int mul = 0;
    int framestep = ceil_i(step);
    for(UInt32 frame = 0; frame < size; frame++) {
        double mod = single_theta;
        if(pPlayState->mMessage[(frame/framestep)] == -1) {
            mod = single_theta2;
        }
        double theta = mod * frame;
        if (theta > TWOPI) {
            mul = theta / TWOPI;
            theta = theta - mul * TWOPI;
        }
        
        buffer[frame] = (AUDIO_CHANNEL_TYPE)sin(theta) * 2;
//        double theta = single_theta * frame;
//        if (theta > TWOPI) {
//            mul = theta / TWOPI;
//            theta = theta - mul * TWOPI;
//        }
//
//        double mod = 0;
//        if(mul*3 < pPlayState->mMessageLength) {
//            mod = pPlayState->mMessage[(mul/3)] == 1 ? 0 : M_PI_2;
//        }
//        buffer[frame] = (AUDIO_CHANNEL_TYPE)sin((theta+mod)) * amplitude;
//        mul = 0;
        //        printf("%ld %f %ld\n",frame, theta, mul);
    }
    
//	for(SInt64 i = pPlayState->mCurrentPacket; i < pPlayState->mCurrentPacket + numPackets; i++) {
////        long idx = i % pPlayState->mMessageLength;
////        short encoding =  pPlayState->mMessage[idx];
////        Float32 encoding =  pPlayState->mMessage2[idx];
////        printf("%d\n",(SInt16)(sin(2 * M_PI * FREQ * i / SR) * SHRT_MAX * encoding));
//		buffer[i-pPlayState->mCurrentPacket] = (AUDIO_CHANNEL_TYPE)(sin(2 * M_PI * FREQ * i / SR) * SHRT_MAX);
//	}

    // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    inBuffer->mAudioDataByteSize = pPlayState->bufferByteSize;//numPackets * 2;
    AudioQueueEnqueueBuffer(pPlayState->mQueue, inBuffer, 0, NULL);
    pPlayState->mCurrentPacket += numPackets;
}

@interface AMPlayer (Private)
- (void)_setupAudioFormat;
- (void)_deriveBufferSize:(Float64)seconds;
- (void)_encodeMessage:(NSString *)message;
- (void)_encodeMessageflat:(NSString *)message;
@end

@implementation AMPlayer
- (void)dealloc {
    AudioQueueDispose(_playState.mQueue, true);
}

- (void) stop {
    if (_playState.mIsRunning) {
        AudioQueueStop(_playState.mQueue, true);
    }
    _playState.mIsRunning = false;
}

- (void)play:(NSString *)message {

    [self _setupAudioFormat];
    _playState.mCurrentPacket = 0;

    [self _encodeMessageflat: message];
//    [self _encodeMessage:message];

    [self _deriveBufferSize:1.0f];

    OSStatus status = noErr;
    status = AudioQueueNewOutput(&_playState.mDataFormat,
                                HandleOutputBuffer,
                                &_playState,
                                NULL,
                                NULL,
                                0,
                                &_playState.mQueue);

    NSAssert(noErr == status, @"Count not create queue.");

    _playState.mIsRunning = YES;
    for (int i = 0; i < kNumberBuffers; i++) {
        AudioQueueAllocateBuffer(_playState.mQueue, _playState.bufferByteSize, &_playState.mBuffers[i]);
        HandleOutputBuffer(&_playState, _playState.mQueue, _playState.mBuffers[i]);
    }

    NSAssert(noErr == status, @"Could not allocate buffers.");

    status = AudioQueueStart(_playState.mQueue, NULL);

    NSAssert(noErr == status, @"Could not start playing.");
}

@end

@implementation AMPlayer (Private)
- (void)_setupAudioFormat {
    const int eight_bit_per_byte = 8;
    _playState.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    _playState.mDataFormat.mSampleRate = 44100.0f;
    _playState.mDataFormat.mBitsPerChannel = eight_bit_per_byte * sizeof(AUDIO_CHANNEL_TYPE);
    _playState.mDataFormat.mChannelsPerFrame = 1;
    _playState.mDataFormat.mFramesPerPacket = 1;
    _playState.mDataFormat.mBytesPerFrame = _playState.mDataFormat.mBytesPerPacket = _playState.mDataFormat.mChannelsPerFrame * sizeof(AUDIO_CHANNEL_TYPE);
    _playState.mDataFormat.mReserved = 0;
    _playState.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsNonInterleaved | kAudioFormatFlagsNativeFloatPacked;
//    _playState.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsNonInterleaved | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked ;
}

- (void)_deriveBufferSize:(Float64)seconds {
    static const int maxBufferSize = 0x50000;

    int maxPacketSize = _playState.mDataFormat.mBytesPerPacket;

    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty(_playState.mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &maxVBRPacketSize);
    }

    Float64 numBytesForTime = std::round((double)(_playState.mDataFormat.mSampleRate * maxPacketSize * seconds));
    _playState.bufferByteSize = (UInt32) MIN(numBytesForTime, maxBufferSize);
}

- (void)_encodeMessageflat:(NSString *)message {
    message = @"ab123456789012";
    const char * estr = [message cStringUsingEncoding:NSASCIIStringEncoding];
    bvec strVec = zeros_b(message.length * 8);
    for(int i = 0; i < message.length; i++) {
        char c = estr[i];
        for(int bitIndex = 0; bitIndex < 8; bitIndex++) {
            strVec.set(i*8+bitIndex, bin((c >> abs(bitIndex-7)) & 1));
        }
    }
    
//    cout << strVec << endl;
    if([LDPCGenerator sharedGenerator].ready) {
        bvec ldpcVec = [LDPCGenerator sharedGenerator]->C.encode(strVec);
        NSLog(@"ldpc encoded");
//        cout << ldpcVec << endl;
        int encodedLength = ldpcVec.length();
        char *bpsk = (char *)calloc(encodedLength * SAMPLE_PER_BIT, sizeof(char));
        BPSK Mod;
        vec s = Mod.modulate_bits(ldpcVec);
        for (int i = 0; i < encodedLength; i++) {
            for (int j = 0; j < SAMPLE_PER_BIT; j++) {
                bpsk[i*SAMPLE_PER_BIT+j] = s.get(i);
            }
        }
//        Mod.demodulate_soft_bits(s);
//        cout << s << endl;
        _playState.mMessageLength = encodedLength * SAMPLE_PER_BIT;
        _playState.mMessage = bpsk;
//        NSMutableString * outputString = [NSMutableString new];
//        for(int i = 0; i < _playState.mMessageLength; i++) {
//            [outputString appendFormat: @"%1.0f ", bpsk[i]];
//        }
//        NSLog(@"%@",outputString);
//        cout << s << endl;
//        vec EbN0db = "0.6:0.2:5";
//        double N0 = pow(10.0, -EbN0db(1) / 10.0) / [LDPCGenerator sharedGenerator]->C.get_rate();
//
//        AWGN_Channel chan(N0 / 2);
//        vec x = chan(s);
//        cout << x << endl;
    }
    
    
}

- (void)_encodeMessage:(NSString *)message {
    const char * estr = [message cStringUsingEncoding:NSASCIIStringEncoding];
    int add = 1;
    char *str = (char*)calloc(message.length+add+1,sizeof(char));
    str[0] = (int)strtol([[@(message.length) stringValue] cStringUsingEncoding: NSASCIIStringEncoding] , NULL, 16);
    for(int i = add; i < message.length+add; i++) {
        str[i] = estr[i-add];
    }
    str[message.length+add] = str[0];
    UInt32 length = message.length+add+1;
    UInt32 encodedLength = length * 12 + BARKER_LEN + 1;
    unsigned char * encodedMessage = (unsigned char *)calloc(encodedLength, sizeof(unsigned char));
    char * bpsk = (char *)calloc(encodedLength * BIT_RATE, sizeof(char));

    // encode messages are in bit
    encodedMessage[0] = 1;
    int startIndex = 1;
    for (int i = startIndex; i < BARKER_LEN+1; i++) {
        encodedMessage[i] = 1& ~(barkerbin[i-1] ^ encodedMessage[i-1]);
    }
    startIndex = BARKER_LEN+startIndex;
    for (int i = startIndex; i < encodedLength; i++) {
        int currentbit = (i-BARKER_LEN-1)%12;
        int strindex = (i-BARKER_LEN-1)/12;
//        NSLog(@"index: %i switch: %i str: %i",i,currentbit,strindex);
        switch (currentbit) {
            case 0:
            case 10:
            case 11:
            {
                // (bitwise xor the byte in previous index with 0 and not it) then bitwise and it with 1
                encodedMessage[i] = 1& ~(0 ^ encodedMessage[i-1]);
                // bitwise and it with 1 always.. so its always 0 or 1
                break;
            }
            case 9:
                encodedMessage[i] = 1& ~(ParityTable256[str[strindex]] ^ encodedMessage[i-1]);
                break;
            default:
                encodedMessage[i] = 1& ~((((unsigned char)str[strindex] >> (8-currentbit) & 0x01)) ^ encodedMessage[i-1]);
                break;
        }
    }

//#define SHOW_ENCODED
#ifdef SHOW_ENCODED
    for (int i = 0; i < encodedLength; i++) {
        printf("%d", encodedMessage[i]);
    }
    printf("\n");
#endif

    for (int i = 0; i < encodedLength; i++) {
        for (int j = 0; j < SAMPLE_PER_BIT; j++) {
            bpsk[i*SAMPLE_PER_BIT+j] = 2* encodedMessage[i] - 1;
        }
    }

//#define SHOW_BASEBAND
#ifdef SHOW_BASEBAND
    for (int i = 0; i < SAMPLE_PER_BIT * encodedLength; i++) {
        printf("%+d\n", bpsk[i]);
    }
#endif

    _playState.mMessageLength = encodedLength * SAMPLE_PER_BIT;
    _playState.mMessage = bpsk;
}
@end