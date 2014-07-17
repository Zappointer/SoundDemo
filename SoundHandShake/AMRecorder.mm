//
//  AMRecorder.m
//  AudioModem
//
//  Created by Tarek Belkahia on 11/01/13.
//
//

#import "AMRecorder.h"
#import "LDPCGenerator.h"

using namespace std;

static float * barker;
static float * fBuffer;
static float * integral;
static float * corr;
static float * smallFBuffer;
static AUDIO_INPUT_TYPE *copiedSampleBuffer;
static AUDIO_INPUT_TYPE *frameBuffer;
static AUDIO_INPUT_TYPE *tempSamples;
static int frameBufferSize;
static const UInt32 fftFrame = 256;
static const double secondPerCode = 0.01;//SR/(double)fftFrame;
static const UInt32 framesPerCode = SR*secondPerCode;
static NSMutableArray *freqs = [NSMutableArray new];

void initReceiver(void) {
    long bufSize = SR;
    copiedSampleBuffer = (AUDIO_INPUT_TYPE *)malloc(bufSize*sizeof(AUDIO_INPUT_TYPE));
    fBuffer = (float *)calloc(bufSize, sizeof(float));
    smallFBuffer = (float *)calloc(bufSize, sizeof(float));
    integral = (float *)calloc(bufSize/SAMPLE_PER_BIT, sizeof(float));
    corr = (float *)calloc(bufSize + BARKER_LEN*SAMPLE_PER_BIT, sizeof(float));
    barker = (float *)calloc(BARKER_LEN*SAMPLE_PER_BIT, sizeof(float));
    frameBuffer = (AUDIO_INPUT_TYPE *)calloc(bufSize,sizeof(AUDIO_INPUT_TYPE));
    tempSamples = (AUDIO_INPUT_TYPE *)calloc(bufSize*2,sizeof(AUDIO_INPUT_TYPE));
}

void ConvertInt16ToFloat(AQRecordState *AQState, void *buf, float *outputBuf, size_t capacity) {
    AudioConverterRef converter;
    OSStatus err;
    
    size_t bytesPerSample = sizeof(float);
    AudioStreamBasicDescription outFormat = {0};
    outFormat.mFormatID = kAudioFormatLinearPCM;
    outFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    outFormat.mBitsPerChannel = 8 * bytesPerSample;
    outFormat.mFramesPerPacket = 1;
    outFormat.mChannelsPerFrame = 1;
    outFormat.mBytesPerPacket = bytesPerSample * outFormat.mFramesPerPacket;
    outFormat.mBytesPerFrame = bytesPerSample * outFormat.mChannelsPerFrame;
    outFormat.mSampleRate = AQState->mDataFormat.mSampleRate;
    
    const AudioStreamBasicDescription inFormat = AQState->mDataFormat;
    
    UInt32 inSize = capacity*sizeof(AUDIO_INPUT_TYPE);
    UInt32 outSize = capacity*sizeof(float);
    err = AudioConverterNew(&inFormat, &outFormat, &converter);
    err = AudioConverterConvertBuffer(converter, inSize, buf, &outSize, outputBuf);
}

float MagnitudeSquared2(float x, float y) {
    return ((x*x) + (y*y));
}

void HandleInputBuffer(void * inUserData,
                       AudioQueueRef inAQ,
                       AudioQueueBufferRef inBuffer,
                       const AudioTimeStamp * inStartTime,
                       UInt32 inNumPackets,
                       const AudioStreamPacketDescription * inPacketDesc) {
    AQRecordState * pRecordState = (AQRecordState *)inUserData;
    AMRecorder *recorder = ((AMRecorder *)pRecordState->mSelf);
    if (inNumPackets == 0 && pRecordState->mDataFormat.mBytesPerPacket != 0) {
        inNumPackets = inBuffer->mAudioDataByteSize / pRecordState->mDataFormat.mBytesPerPacket;
    }
    if (!pRecordState->mIsRunning || inNumPackets == 0) {
        return;
    }
    [recorder displayBuffer: inBuffer];
    
    COMPLEX_SPLIT A = recorder->A;
    uint32_t log2n = recorder->log2n;
    uint32_t n = recorder->n;
    uint32_t nOver2 = recorder->nOver2;
    FFTSetup fftSetup = recorder->fftSetup;
    uint32_t stride = 1;
    
    
    UInt32 sampleStart = pRecordState->mCurrentPacket;
    UInt32 sampleEnd = pRecordState->mCurrentPacket + inBuffer->mAudioDataByteSize / pRecordState->mDataFormat.mBytesPerPacket - 1;
    UInt32 nsamples = sampleEnd - sampleStart + 1;
    AUDIO_INPUT_TYPE *samples;
    if(frameBufferSize > 0) {
        samples = tempSamples;
        memcpy(samples,frameBuffer,frameBufferSize*sizeof(AUDIO_INPUT_TYPE));
        memcpy(samples+frameBufferSize,inBuffer->mAudioData,nsamples*sizeof(AUDIO_INPUT_TYPE));
        nsamples += frameBufferSize;
        frameBufferSize = 0;
    } else {
        samples = (AUDIO_INPUT_TYPE *)inBuffer->mAudioData;
    }
//    [freqs removeAllObjects];
    UInt64 codeFrames = nsamples / (UInt64)fftFrame;
    UInt32 trimSize = nsamples % fftFrame;
    nsamples -= trimSize;
    if(trimSize > 0) {
        printf("trim size : %u\n", (unsigned int)trimSize);
        memcpy(frameBuffer,samples+(codeFrames*fftFrame),trimSize*sizeof(AUDIO_INPUT_TYPE));
        frameBufferSize = trimSize;
    } else {
        frameBufferSize = 0;
    }

//    printf("%ld %ld %ld buffered with %d\n", sampleStart, sampleEnd,nsamples,frameBufferSize);
    /*************** FFT ***************/
    ConvertInt16ToFloat(pRecordState, samples, fBuffer, (size_t)nsamples);
    /**
     Look at the real signal as an interleaved complex vector by casting it.
     Then call the transformation function vDSP_ctoz to get a split complex
     vector, which for a real signal, divides into an even-odd configuration.
     */
    NSMutableString *frequencies = [NSMutableString new];

    for(int codeFrameIndex = 0; codeFrameIndex < codeFrames; codeFrameIndex++) {
        memcpy(smallFBuffer, fBuffer+(codeFrameIndex*fftFrame), fftFrame*sizeof(float));
        vDSP_ctoz((COMPLEX*)smallFBuffer, 2, &A, 1, nOver2);
        vDSP_fft_zrip(fftSetup, &A, stride, log2n, FFT_FORWARD);
        vDSP_ztoc(&A, 1, (COMPLEX *)smallFBuffer, 2, nOver2);
        float dominantFrequency = 0;
        int bin = -1;
        for (int i=0; i<n; i+=2) {
            float curFreq = MagnitudeSquared2(smallFBuffer[i], smallFBuffer[i+1]);
            if (curFreq > dominantFrequency) {
                dominantFrequency = curFreq;
                bin = (i+1)/2;
            }
        }
        float frequency = bin*((double)SR/recorder->bufferCapacity);
//        [freqs addObject: @(frequency)];
        if(!pRecordState->mSignalFound && frequency > pRecordState->fq3-200 && frequency < pRecordState->fq3+200) {
            pRecordState->mSignalFound = true;
            pRecordState->mCodeReceived.clear();
            pRecordState->mCodeLength = 0;
            printf("found start decoding\n");
            if(recorder.delegate) {
                [recorder.delegate startDecoding];
            }
        } else {
        }
    }
    
//    for(int codeFrameIndex = 0; codeFrameIndex < codeFrames; codeFrameIndex++) {
//        memcpy(smallFBuffer, fBuffer+(codeFrameIndex*framesPerCode), framesPerCode*sizeof(float));
//        vDSP_ctoz((COMPLEX*)smallFBuffer, 2, &A, 1, nOver2);
//        vDSP_fft_zrip(fftSetup, &A, stride, log2n, FFT_FORWARD);
//        vDSP_ztoc(&A, 1, (COMPLEX *)smallFBuffer, 2, nOver2);
//        float dominantFrequency = 0;
//        int bin = -1;
//        for (int i=0; i<n; i+=2) {
//            float curFreq = MagnitudeSquared2(smallFBuffer[i], smallFBuffer[i+1]);
//            if (curFreq > dominantFrequency) {
//                dominantFrequency = curFreq;
//                bin = (i+1)/2;
//            }
//        }
//        float frequency = bin*((double)SR/recorder->bufferCapacity);
//        [frequencies appendFormat: @" %f",frequency];
//        if(!pRecordState->mSignalFound && frequency > pRecordState->fq3-200 && frequency < pRecordState->fq3+200) {
//            pRecordState->mSignalFound = true;
//            pRecordState->mCodeReceived.clear();
//            pRecordState->mCodeLength = 0;
//            printf("found start decoding\n");
//            if(recorder.delegate) {
//                [recorder.delegate startDecoding];
//            }
//        } else {
//            if(pRecordState->mSignalFound) {
//                if(frequency > pRecordState->fq3-200 && frequency < pRecordState->fq3+200) {
//                    if(pRecordState->mCodeLength > 0) {
//                        pRecordState->mCodeReceived.set_subvector( 1, pRecordState->mCodeReceived);
//                        pRecordState->mCodeReceived.set(0, 0.0);
//                        pRecordState->mCodeLength++;
//                        if(pRecordState->mCodeLength >= [LDPCGenerator sharedGenerator].characterLength * 8 * 2) {
//                            cout << pRecordState->mCodeReceived << endl;
//                            if([recorder decode]) {
//                                pRecordState->mSignalFound = true;
//                                break;
//                            }
//                            pRecordState->mSignalFound = true;
//                            
//                        }
//                    } else {
//                        pRecordState->mCodeReceived.set(0, 0.0);
//                        pRecordState->mCodeLength++;
//                    }
//                }else if(frequency < 2400){//frequency > pRecordState->fq1-200 && frequency < pRecordState->fq1+200) {
//                    pRecordState->mCodeReceived.set(pRecordState->mCodeLength, 1.0);
//                    pRecordState->mCodeLength++;
//                } else if(frequency > 5800 && frequency < 8200){//frequency > pRecordState->fq2-200 && frequency < pRecordState->fq2+200) {
//                    pRecordState->mCodeReceived.set(pRecordState->mCodeLength, -1.0);
//                    pRecordState->mCodeLength++;
//                } else {
//                    pRecordState->mCodeReceived.set(pRecordState->mCodeLength, 1.0);//(arc4random()/(double)UINT_FAST32_MAX)*2-1);
//                    pRecordState->mCodeLength++;
//                }
//                printf("."); //printf(" %i ",pRecordState->mCodeLength);
////
//                if(pRecordState->mCodeLength >= [LDPCGenerator sharedGenerator].characterLength * 8 * 2) {
//                    cout << pRecordState->mCodeReceived << endl;
//                    [recorder decode];
//                    break;
//                }
//            }
//        }
//    } // end for
    
//    [recorder frequenciesUpdated: freqs];
    
    AudioQueueEnqueueBuffer(pRecordState->mQueue, inBuffer, 0, NULL);
    pRecordState->mCurrentPacket += inNumPackets;

}

@interface AMRecorder ()
{
}

- (void)_setupAudioFormat;
- (void)_deriveBufferSize:(Float64)seconds;

@end

@implementation AMRecorder

- (id) init {
    self = [super init];
    if(self) {
        [self realFFTSetup];
    }
    return self;
}
    
- (void) displayBuffer:(AudioQueueBufferRef) audioQueueReference {
    UInt32 byteSize = audioQueueReference->mAudioDataByteSize;
    UInt32 size = audioQueueReference->mAudioDataByteSize/sizeof(AUDIO_INPUT_TYPE);
    AUDIO_INPUT_TYPE *samples = (AUDIO_INPUT_TYPE *)malloc(byteSize);
    memcpy(samples,audioQueueReference->mAudioData,byteSize);
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) sSelf = weakSelf;
        if(sSelf.delegate && [sSelf.delegate respondsToSelector: @selector(bufferUpdatedWithData:size:)]) {
            [sSelf.delegate bufferUpdatedWithData: samples size: size];
        }
    });
}
    
- (BOOL) decode {
    BOOL found = NO;
    QLLRvec llr;
    int it = [LDPCGenerator sharedGenerator]->C.bp_decode([LDPCGenerator sharedGenerator]->C.get_llrcalc().to_qllr(_recordState.mCodeReceived), llr);
    if(it >= 1) {
        bvec bitsout = llr < 0;
        bvec answer = llr.get(0, [LDPCGenerator sharedGenerator].characterLength*8-1) < 0;
        cout << answer << endl;
        char *final = (char*)calloc([LDPCGenerator sharedGenerator].characterLength,sizeof(char));
        for(int i = 0; i < [LDPCGenerator sharedGenerator].characterLength; i++) {
            for(int bitIndex = 0; bitIndex < 8; bitIndex++) {
                bin b = answer.get(i*8+bitIndex);
                if(b == 1) {
                    final[i] |= 1 << abs(bitIndex-7);
                }
            }
        }
        NSLog(@"%i", it);
        NSLog(@"answer = %@", [NSString stringWithCString: final encoding: NSASCIIStringEncoding]);
        if(self.delegate) {
            [self.delegate decodedStringFound: [NSString stringWithCString: final encoding: NSASCIIStringEncoding]];
        }
        found = YES;

    } else {
        NSLog(@"tried decoding but failed with %i", it);
        if(self.delegate) {
            [self.delegate decodedStringFound: @"decode failed"];
        }
        llr.clear();
        frameBufferSize = 0;
        found = NO;
    }
    _recordState.mCodeLength = 0;
    _recordState.mCodeReceived.clear();
    _recordState.mSignalFound = false;
    return found;
}

- (void)dealloc {
    AudioQueueDispose(_recordState.mQueue, true);
}

- (void)realFFTSetup {
    UInt32 maxFrames = fftFrame;
    dataBuffer = (void*)malloc(maxFrames * sizeof(SInt16));
    outputBuffer = (float*)malloc(maxFrames *sizeof(float));
    log2n = log2f(maxFrames);
    n = 1 << log2n;
    assert(n == maxFrames);
    nOver2 = maxFrames/2;
    bufferCapacity = maxFrames;
    index = 0;
    A.realp = (float *)malloc(nOver2 * sizeof(float));
    A.imagp = (float *)malloc(nOver2 * sizeof(float));
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX5);
}

- (void)startRecording {
//    NSAssert(framesPerCode > fftFrame, @"not enought signal for fft frame to detect frequency");
    [self _setupAudioFormat];
    _recordState.mCurrentPacket = 0;
    _recordState.mSelf = self;
    _recordState.fq1 = [LDPCGenerator sharedGenerator].signal0Frequency;
    _recordState.fq2 = [LDPCGenerator sharedGenerator].signal1Frequency;
    _recordState.fq3 = [LDPCGenerator sharedGenerator].startSignalFrequency;
    _recordState.mSignalFound = false;
    _recordState.mCodeReceived = zeros([LDPCGenerator sharedGenerator]->C.get_nvar());
    _recordState.mCodeLength = 0;
    frameBufferSize = 0;
    initReceiver();

    OSStatus status = noErr;
    status = AudioQueueNewInput(&_recordState.mDataFormat,
                                HandleInputBuffer,
                                &_recordState,
                                NULL,
                                NULL,
                                0,
                                &_recordState.mQueue);

//    ADAssert(noErr == status, @"Could not create queue.");

    [self _deriveBufferSize:1.0f];

    for (int i = 0; i < kNumberBuffers; i++) {
        AudioQueueAllocateBuffer(_recordState.mQueue, _recordState.bufferByteSize, &_recordState.mBuffers[i]);
        AudioQueueEnqueueBuffer(_recordState.mQueue, _recordState.mBuffers[i], 0, NULL);
    }

//    ADAssert(noErr == status, @"Could not allocate buffers.");

    _recordState.mIsRunning = YES;
    status = AudioQueueStart(_recordState.mQueue, NULL);

//    ADAssert(noErr == status, @"Could not start recording.");

//    _receiverTextView.text = @"(Recording...)";
}

- (void)stopRecording {
    if (_recordState.mIsRunning) {
        AudioQueueStop(_recordState.mQueue, true);
        _recordState.mIsRunning = false;
    }
}

- (void) frequenciesUpdated:(NSArray *)frequencies {
    __weak typeof(self) weakSelf = self;
    NSArray *copy = [NSArray arrayWithArray: frequencies];
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) sSelf = weakSelf;
        
        float max = -MAXFLOAT;
        float min = MAXFLOAT;
        float average = 0;
        NSMutableDictionary *bins = [NSMutableDictionary new];
        for(NSNumber * num in copy) {
            float value = [num floatValue];
            if(value > max) {
                max = value;
            }
            if(value < min) {
                min = value;
            }
            average += value;
            if(!bins[@(value)]) {
                bins[@(value)] = @(0);
            } else {
                bins[@(value)] = @([(NSNumber *)bins[@(value)] intValue] + 1);
            }
        }
        int targetCount = SR/fftFrame*0.1;
        average = average/copy.count;
        for(NSNumber *f in bins) {
            if([bins[f] intValue] > targetCount) {
                printf("%u %f: %f\n",[bins[f] intValue], [bins[f] intValue]/(float)(SR/fftFrame), [f floatValue]);
            }
        }
        printf("max: %f\nmin: %f\nsum: %f\n",max, min,average);
        
//        if(sSelf.delegate && [sSelf.delegate respondsToSelector: @selector(frequencyStringUpdated:)]) {
//            [sSelf.delegate frequencyStringUpdated: frequencies];
//        }
    });
    
}

- (IBAction)recordMessage:(id)sender {
    [self startRecording];
//    _playButton.enabled = NO;
//    _recordButton.enabled = NO;
}

- (void) setFrequency:(CGFloat)frequency {
    _frequency = frequency;
    if(self.delegate) {
        [self.delegate frequencyDetected: frequency];
    }
}

- (void)_setupAudioFormat {
    _recordState.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    _recordState.mDataFormat.mSampleRate = 44100.0;
    _recordState.mDataFormat.mBitsPerChannel = sizeof(AUDIO_INPUT_TYPE)*8;
    _recordState.mDataFormat.mChannelsPerFrame = 1;
    _recordState.mDataFormat.mFramesPerPacket = 1;
    _recordState.mDataFormat.mBytesPerFrame = _recordState.mDataFormat.mBytesPerPacket = _recordState.mDataFormat.mChannelsPerFrame * sizeof(AUDIO_INPUT_TYPE);
    _recordState.mDataFormat.mReserved = 0;
    _recordState.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsNonInterleaved | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked ;//| kLinearPCMFormatFlagIsBigEndian;
}

- (void)_deriveBufferSize:(Float64)seconds {
    static const int maxBufferSize = 0x50000;

    int maxPacketSize = _recordState.mDataFormat.mBytesPerPacket;

    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty(_recordState.mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &maxVBRPacketSize);
    }

    Float64 numBytesForTime = std::round(_recordState.mDataFormat.mSampleRate * maxPacketSize * seconds);
    _recordState.bufferByteSize = (UInt32) MIN(numBytesForTime, maxBufferSize);
}

@end