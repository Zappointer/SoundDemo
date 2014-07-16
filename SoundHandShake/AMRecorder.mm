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

//static const bool ParityTable256[256] =
//{
//#   define P2(n) n, n^1, n^1, n
//#   define P4(n) P2(n), P2(n^1), P2(n^1), P2(n)
//#   define P6(n) P4(n), P4(n^1), P4(n^1), P4(n)
//    P6(0), P6(1), P6(1), P6(0)
//};
//
//static float bpf[SAMPLE_PER_BIT+1] = {
//    +0.0055491, -0.0060955, +0.0066066, -0.0061506, +0.0033972, +0.0028618,
//    -0.0130922, +0.0265188, -0.0409498, +0.0530505, -0.0590496, +0.0557252,
//    -0.0414030, +0.0166718, +0.0154256, -0.0498328, +0.0804827, -0.1016295,
//    +0.1091734, -0.1016295, +0.0804827, -0.0498328, +0.0154256, +0.0166718,
//    -0.0414030, +0.0557252, -0.0590496, +0.0530505, -0.0409498, +0.0265188,
//    -0.0130922, +0.0028618, +0.0033972, -0.0061506, +0.0066066, -0.0060955,
//    +0.0055491
//};
//
//static float lpf[SAMPLE_PER_BIT+1] = {
//    0.0025649, 0.0029793, 0.0039200, 0.0054457, 0.0075875, 0.0103454,
//    0.0136865, 0.0175452, 0.0218251, 0.0264022, 0.0311308, 0.0358496,
//    0.0403893, 0.0445807, 0.0482632, 0.0512926, 0.0535482, 0.0549392,
//    0.0554092, 0.0549392, 0.0535482, 0.0512926, 0.0482632, 0.0445807,
//    0.0403893, 0.0358496, 0.0311308, 0.0264022, 0.0218251, 0.0175452,
//    0.0136865, 0.0103454, 0.0075875, 0.0054457, 0.0039200, 0.0029793,
//    0.0025649
//};

static float barkerbin[BARKER_LEN] = {
    +1.0f, +1.0f, +1.0f, +1.0f, +1.0f, -1.0f, -1.0f, +1.0f, +1.0f, -1.0f, +1.0f, -1.0f, +1.0f
};

static char strbuf[BIT_RATE] = {'\n'};

static float * barker;
static float * fBuffer;
static float * integral;
static float * corr;
static float * smallFBuffer;
static SInt16 *frameBuffer;
static SInt16 *tempSamples;
static int frameBufferSize;
static const UInt32 fftFrame = 256;
static const double secondPerCode = 0.01;//SR/(double)fftFrame;
static const UInt32 framesPerCode = SR*secondPerCode;


void initReceiver(void) {
    long bufSize = SR;
    fBuffer = (float *)calloc(bufSize, sizeof(float));
    smallFBuffer = (float *)calloc(framesPerCode, sizeof(float));
    integral = (float *)calloc(bufSize/SAMPLE_PER_BIT, sizeof(float));
    corr = (float *)calloc(bufSize + BARKER_LEN*SAMPLE_PER_BIT, sizeof(float));
    barker = (float *)calloc(BARKER_LEN*SAMPLE_PER_BIT, sizeof(float));
    frameBuffer = (SInt16 *)calloc(bufSize,sizeof(SInt16));
    tempSamples = (SInt16 *)calloc(bufSize*2,sizeof(SInt16));

    for (int i = 0; i < BARKER_LEN; i++) {
        vDSP_vfill(barkerbin+i, barker+i*SAMPLE_PER_BIT, 1, SAMPLE_PER_BIT);
    }
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
    
    UInt32 inSize = capacity*sizeof(SInt16);
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
    COMPLEX_SPLIT A = recorder->A;
    uint32_t log2n = recorder->log2n;
    uint32_t n = recorder->n;
    uint32_t nOver2 = recorder->nOver2;
    FFTSetup fftSetup = recorder->fftSetup;
    uint32_t stride = 1;
    
    if (inNumPackets == 0 && pRecordState->mDataFormat.mBytesPerPacket != 0) {
        inNumPackets = inBuffer->mAudioDataByteSize / pRecordState->mDataFormat.mBytesPerPacket;
    }

    if (!pRecordState->mIsRunning || inNumPackets == 0) {
        return;
    }

    
    UInt32 sampleStart = pRecordState->mCurrentPacket;
    UInt32 sampleEnd = pRecordState->mCurrentPacket + inBuffer->mAudioDataByteSize / pRecordState->mDataFormat.mBytesPerPacket - 1;
    UInt32 nsamples = sampleEnd - sampleStart + 1;
    SInt16 * samples;
    if(frameBufferSize > 0) {
        samples = tempSamples;
        memcpy(samples,frameBuffer,frameBufferSize*sizeof(SInt16));
        memcpy(samples+frameBufferSize,inBuffer->mAudioData,nsamples*sizeof(SInt16));
        nsamples += frameBufferSize;
        frameBufferSize = 0;
    } else {
        samples = (SInt16 *)inBuffer->mAudioData;
    }
    UInt64 codeFrames = nsamples / (UInt64)framesPerCode;
    UInt32 trimSize = nsamples % framesPerCode;
    nsamples -= trimSize;
    if(trimSize > 0) {
        memcpy(frameBuffer,samples+(codeFrames*framesPerCode),trimSize*sizeof(SInt16));
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
        memcpy(smallFBuffer, fBuffer+(codeFrameIndex*framesPerCode), framesPerCode*sizeof(float));
//        int bufferIndex = framesPerCode;
//        int frameleft = fftFrame - framesPerCode;
//        while(frameleft > 0) {
//            int copySize = framesPerCode;
//            if(frameleft < copySize) {
//                copySize = frameleft;
//            }
//            int add = (128-frameleft);
//            memcpy(smallFBuffer+add,smallFBuffer,copySize*sizeof(float));
//            frameleft = frameleft - framesPerCode;
//        }
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
        [frequencies appendFormat: @" %f",frequency];
        if(!pRecordState->mSignalFound && frequency > 18400 && frequency < 18600) {
            pRecordState->mSignalFound = true;
            pRecordState->mCodeReceived.clear();
            pRecordState->mCodeLength = 0;
            printf("found start decoding\n");
            if(recorder.delegate) {
                [recorder.delegate startDecoding];
            }
        } else {
            if(pRecordState->mSignalFound) {
                if(frequency > 18300 && frequency < 18700) {
                    if(pRecordState->mCodeLength > 0) {
                        pRecordState->mCodeReceived.set_subvector( 1, pRecordState->mCodeReceived);
                        pRecordState->mCodeReceived.set(0, 0.0);
                        pRecordState->mCodeLength++;
                        if(pRecordState->mCodeLength >= [LDPCGenerator sharedGenerator].characterLength * 8 * 2) {
                            cout << pRecordState->mCodeReceived << endl;
                            [recorder decode];
                            pRecordState->mSignalFound = true;
                        }
                    } else {
                        pRecordState->mCodeReceived.set(0, 0.0);
                        pRecordState->mCodeLength++;
                    }
                }else if(frequency > 17800 && frequency < 18200) {
                    pRecordState->mCodeReceived.set(pRecordState->mCodeLength, 1.0);
                    pRecordState->mCodeLength++;
                } else if(frequency > 18800 && frequency < 19200) {
                    pRecordState->mCodeReceived.set(pRecordState->mCodeLength, -1.0);
                    pRecordState->mCodeLength++;
                } else {
                    pRecordState->mCodeReceived.set(pRecordState->mCodeLength, 1.0);//(arc4random()/(double)UINT_FAST32_MAX)*2-1);
                    pRecordState->mCodeLength++;
                }
                printf(".");
//                printf(" %i ",pRecordState->mCodeLength);
#ifdef LDPC
                if(pRecordState->mCodeLength >= [LDPCGenerator sharedGenerator].characterLength * 8 * 2) {
#else
                if(pRecordState->mCodeLength == 252) {
#endif
                    cout << pRecordState->mCodeReceived << endl;
                    [recorder decode];
                }
            }
        }
        
    }
    
    [recorder frequenciesUpdated: frequencies];
    
//    vec softbits = Mod.demodulate_soft_bits(x, N0);
    // Decode the received bits
    
//    vDSP_ctoz((COMPLEX*)fBuffer, 2, &A, 1, nOver2);
//    
//    // Carry out a Forward FFT transform.
//    vDSP_fft_zrip(fftSetup, &A, stride, log2n, FFT_FORWARD);
//    
//    // The output signal is now in a split real form. Use the vDSP_ztoc to get
//    // a split real vector.
//    vDSP_ztoc(&A, 1, (COMPLEX *)fBuffer, 2, nOver2);
//    
//    // Determine the dominant frequency by taking the magnitude squared and
//    // saving the bin which it resides in.
//    float dominantFrequency = 0;
//    int bin = -1;
//    for (int i=0; i<n; i+=2) {
//        float curFreq = MagnitudeSquared2(fBuffer[i], fBuffer[i+1]);
//        if (curFreq > dominantFrequency) {
//            dominantFrequency = curFreq;
//            bin = (i+1)/2;
//        }
//    }
//    
//    recorder.frequency = bin*((double)SR/recorder->bufferCapacity);
//    
//    if(!pRecordState->mSignalFound && recorder.frequency > 18400 && recorder.frequency < 18600) {
//        pRecordState->mSignalFound = true;
//        pRecordState->mCodeReceived.clear();
//        pRecordState->mCodeLength = 0;
//        printf("found start decoding\n");
//    } else {
//        if(pRecordState->mSignalFound) {
//            if(recorder.frequency > 18400 && recorder.frequency < 18600) {
//                
//            }else if(recorder.frequency > 17900 && recorder.frequency < 18100) {
//                pRecordState->mCodeReceived.set(pRecordState->mCodeLength, 1.0);
//                pRecordState->mCodeLength++;
//            } else if(recorder.frequency > 18900 && recorder.frequency < 19100) {
//                pRecordState->mCodeReceived.set(pRecordState->mCodeLength, -1.0);
//                pRecordState->mCodeLength++;
//            } else {
//                pRecordState->mCodeReceived.set(pRecordState->mCodeLength, (arc4random()/(double)UINT_FAST32_MAX)*2-1);
//            }
//            if(pRecordState->mCodeLength == [LDPCGenerator sharedGenerator].characterLength * 8 * 2) {
//                cout << pRecordState->mCodeReceived << endl;
//                [recorder decode];
//            }
//        }
//    }
    
//    printf("Dominant frequency: %f %f bin: %d \n", dominantFrequency, bin*((double)SR/recorder->bufferCapacity),bin);
    
    AudioQueueEnqueueBuffer(pRecordState->mQueue, inBuffer, 0, NULL);
    pRecordState->mCurrentPacket += inNumPackets;
}

//void HandleInputBuffer(void * inUserData,
//                       AudioQueueRef inAQ,
//                       AudioQueueBufferRef inBuffer,
//                       const AudioTimeStamp * inStartTime,
//                       UInt32 inNumPackets,
//                       const AudioStreamPacketDescription * inPacketDesc) {
//    AQRecordState * pRecordState = (AQRecordState *)inUserData;
//
//    if (inNumPackets == 0 && pRecordState->mDataFormat.mBytesPerPacket != 0) {
//        inNumPackets = inBuffer->mAudioDataByteSize / pRecordState->mDataFormat.mBytesPerPacket;
//    }
//
//    if ( ! pRecordState->mIsRunning) {
//        return;
//    }
//
//    long sampleStart = pRecordState->mCurrentPacket;
//    long sampleEnd = pRecordState->mCurrentPacket + inBuffer->mAudioDataByteSize / pRecordState->mDataFormat.mBytesPerPacket - 1;
//    printf("buffer received : %1.6f from %1.6f (#%07ld) to %1.6f (#%07ld)\n", (sampleEnd - sampleStart + 1)/44100.0, sampleStart/44100.0, sampleStart, sampleEnd/44100.0, sampleEnd);
//
//    // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//
//    short * samples = (short *)inBuffer->mAudioData;
//    long nsamples = sampleEnd - sampleStart + 1;
//    bool found = NO;
//    bool write = NO;
//
//    // Convert to float
//    for (long i = 0; i < nsamples; i++) {
//        fBuffer[i] = samples[i] / (float)SHRT_MAX;
//    }
//
//    // BPF
//    vDSP_desamp(fBuffer, 1, bpf, fBuffer, nsamples, SAMPLE_PER_BIT+1);
//
//    // Carrier present ?
//    float m = 1.0f, max = 0.0f, mean = 0.0f;
//    vDSP_meamgv(fBuffer, 1, &mean, nsamples);
//    printf("mean %1.9f\n", mean);
//
//    if (mean > 10e-5) {
//
//        max = mean;
//        vDSP_maxmgv(fBuffer, 1, &max, nsamples);
//        printf("max  %1.9f\n", max);
//        printf("max/mean %1.9f\n", max/mean);
//
//
//        // Delay Multiply
//        vDSP_vmul(fBuffer, 1, fBuffer+SAMPLE_PER_BIT, 1, fBuffer, 1, nsamples-SAMPLE_PER_BIT);
//
//        // LPF
//        vDSP_desamp(fBuffer, 1, lpf, fBuffer, nsamples, SAMPLE_PER_BIT+1);
//
//        // Time sync
//        m = 1/max;
//        vDSP_vsmul(barker, 1, &m, barker, 1, BARKER_LEN*SAMPLE_PER_BIT);
//
//    #define FILTERS_DELAY (BARKER_LEN+2)*SAMPLE_PER_BIT
//        vDSP_conv(fBuffer, 1, barker, 1, corr, 1, nsamples-FILTERS_DELAY, BARKER_LEN*SAMPLE_PER_BIT);
//
//
//    #ifdef SHOW_CORR
//        for (long i = 0; i < nsamples-FILTERS_DELAY; i++) {
//            printf("%+1.8f\n", corr[i]);
//        }
//    #endif
//
//        float cc = -1.0f;
//        unsigned long cci = 0;
//        vDSP_vsmul(corr, 1, &cc, corr, 1, nsamples-FILTERS_DELAY);
//        vDSP_maxv(corr, 1, &cc, nsamples-FILTERS_DELAY);
//        cc *= CORR_MAX_COEFF;
//        vDSP_vthrsc(corr, 1, &cc, &cc, corr, 1, nsamples-FILTERS_DELAY);
//        vDSP_maxvi(corr, 1, &cc, &cci, nsamples-FILTERS_DELAY);
//        printf("corr %1.9f\n", cc);
//        printf("idx  %lu\n", cci);
//
//        long j = -1;
//        for (long i = 0; i < nsamples; i++) {
//            if (corr[i] > 0) {
//                if (j != i-1) {
//                    printf("Found frame starting at index %ld\n", i);
//                }
//                j = i;
//            }
//        }
//
//        // Integration
//        for (long i = 0; i < nsamples/SAMPLE_PER_BIT; i++) {
//            if(cci+i*SAMPLE_PER_BIT < nsamples) {
//                vDSP_sve(fBuffer+cci+i*SAMPLE_PER_BIT, 1, integral+i, SAMPLE_PER_BIT);
//            }
//        }
//
//        // Decision
//    #ifdef SHOW_FRAMES
//        for (long i = 13; i < nsamples/SAMPLE_PER_BIT; i += 12) {
//            if (integral[i]>0 || integral[i+10]>0 || integral[i+11]>0) {
//                break;
//            }
//            printf("%d ", integral[i]>0);
//            for (int j = i+1; j < i+9; j++) {
//                printf("%d", integral[j]>0);
//            }
//            printf(" %d ", integral[i+9]>0);
//            printf("%d", integral[i+10]>0);
//            printf("%d", integral[i+11]>0);
//            printf("\n");
//        }
//    #endif
//
//        int i = 13;
//        char ch;
//        short p;
//        while (integral[i]<0 && integral[i+10]<0 && integral[i+11]<0) {
//            ch = 0;
//            for (int j = i+1; j < i+9; j++) {
//                ch |= (integral[j]>0) << (8-j+i);
//            }
//            p = ParityTable256[ch];
//            printf("%c", ch);
//            strbuf[(i-13)/12] = ch;
//            i += 12;
//        }
//        int charfound = (i-13)/12;
//        printf("\n%d characters decoded\n", charfound);
//        if(charfound == 0) {
//            write = NO;
//            found = NO;
//        } else if(strbuf[0] != strbuf[charfound-1]) {
//            write = NO;
//            found = NO;
//        } else {
//            write = YES;
//            found = YES;
//        }
//        strbuf[(i-13)/12] = '\0';
//        
//    } else {
//        strbuf[0] = '(';
//        strbuf[1] = 'N';
//        strbuf[2] = 'o';
//        strbuf[3] = ' ';
//        strbuf[4] = 's';
//        strbuf[5] = 'i';
//        strbuf[6] = 'g';
//        strbuf[7] = 'n';
//        strbuf[8] = 'a';
//        strbuf[9] = 'l';
//        strbuf[10] = ')';
//        strbuf[11] = '\0';
//        write = YES;
//    }
//
//    if(write) {
//        [(AMRecorder *)pRecordState->mSelf performSelectorOnMainThread:@selector(updateTextView) withObject:nil waitUntilDone:NO];
//    }
//
//    // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//
//    pRecordState->mCurrentPacket += inNumPackets;
//
//    AudioQueueEnqueueBuffer(pRecordState->mQueue, inBuffer, 0, NULL);
//    
//    if (pRecordState->mIsRunning && found) {
//        [(AMRecorder *)pRecordState->mSelf stopRecording];
//    }
//}

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

- (void) decode {
#ifdef LDPC
    QLLRvec llr;
//    BPSK Mod;
//    vec softbits = Mod.demodulate_soft_bits(_recordState.mCodeReceived, 0);
//    [LDPCGenerator sharedGenerator]->C.decode(_recordState->mCodeReceived);
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

    } else {
        NSLog(@"tried decoding but failed with %i", it);
        if(self.delegate) {
            [self.delegate decodedStringFound: @"decode failed"];
        }
        llr.clear();
//        vec temp = zeros(_recordState.mCodeLength);
//        temp.set_subvector(0, _recordState.mCodeReceived);
//        temp.set(0,1);
//        it = [LDPCGenerator sharedGenerator]->C.bp_decode([LDPCGenerator sharedGenerator]->C.get_llrcalc().to_qllr(temp), llr);
//        vec temp2 = zeros(_recordState.mCodeLength);
//        temp2.set_subvector(0, _recordState.mCodeReceived);
//        temp2.set(0,-1);
//        int it2 = [LDPCGenerator sharedGenerator]->C.bp_decode([LDPCGenerator sharedGenerator]->C.get_llrcalc().to_qllr(temp), llr);
//        if(it >= 1 || it2 >= 1) {
//            NSLog(@"shift worked");
//        }
        frameBufferSize = 0;
    }
#else
    int m = 3;                //Reed-Solomon parameter m
    int t = 2;                //Reed-Solomon parameter t
    Reed_Solomon rs = Reed_Solomon(m, t);
    bvec bout = zeros_b(_recordState.mCodeLength);
    for(int i = 0; i < _recordState.mCodeLength; i++) {
        if(_recordState.mCodeReceived.get(i) == -1.0) {
            bout.set(i, bin(1));
        }else {
            bout.set(i,bin(0));
        }
    }
    bvec answer = rs.decode(bout);
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
    NSLog(@"answer = %@", [NSString stringWithCString: final encoding: NSASCIIStringEncoding]);
    if(self.delegate) {
        [self.delegate decodedStringFound: [NSString stringWithCString: final encoding: NSASCIIStringEncoding]];
    }
#endif
    _recordState.mCodeLength = 0;
    _recordState.mCodeReceived.clear();
    _recordState.mSignalFound = false;
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
    NSAssert(framesPerCode > fftFrame, @"not enought fft frame to detect frequency per signal");
    [self _setupAudioFormat];
    _recordState.mCurrentPacket = 0;
    _recordState.mSelf = self;
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

- (void) frequenciesUpdated:(NSString *)frequencies {
//    NSLog(@"%@",frequencies);
    if(self.delegate && [self.delegate respondsToSelector: @selector(frequencyStringUpdated:)]) {
        [self.delegate frequencyStringUpdated: frequencies];
    }
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
    _recordState.mDataFormat.mBitsPerChannel = 16;
    _recordState.mDataFormat.mChannelsPerFrame = 1;
    _recordState.mDataFormat.mFramesPerPacket = 1;
    _recordState.mDataFormat.mBytesPerFrame = _recordState.mDataFormat.mBytesPerPacket = _recordState.mDataFormat.mChannelsPerFrame * sizeof(SInt16);
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