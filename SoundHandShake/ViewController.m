//
//  ViewController.m
//  SoundHandShake
//
//  Created by Jason Chang on 6/25/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import "ViewController.h"
#import "RIOInterface.h"
#import "KeyHelper.h"
#import "Synth.h"
#import "MHAudioBufferPlayer.h"

typedef struct {
    CGFloat frequency;
    NSTimeInterval timeStamp;
} soundPacket;

#define STARTSEQUENCE_MAX_DIFF 0.5
#define INDIVIDUAL_DIFF 0.2
// 60 c, 61 db,62 d,63 db,64 e,65 f,66 gb ,67 g,68 ab,69 a,70 bb, 71 b
#define STARTNOTE 60
#define ENDNOTE 60
#define STARTCHAR @"C"
#define ENDCHAR @"C"

@interface ViewController () <ListernerDelegate>
{
    BOOL foundStart;
    BOOL foundSignal;
    BOOL foundA;
    NSTimeInterval foundATime;
    BOOL foundB;
    NSString *sequence;
    int sequenceLength;
    NSTimeInterval foundBTime;
}

@property (nonatomic,assign) CGFloat currentFrequency;
@property (nonatomic,weak) IBOutlet UILabel *frequencyLabel;
@property (nonatomic,weak) IBOutlet UILabel *statucLabel;
@property (nonatomic,weak) IBOutlet UILabel *codeLabel;
@property (nonatomic,strong) NSLock *synthLock;
@property (nonatomic,strong) Synth *synth;
@property (nonatomic,strong) MHAudioBufferPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    RIOInterface *rioRef = [RIOInterface sharedInstance];
	[rioRef setSampleRate:44100];
	[rioRef setFrequency:294];
	[rioRef initializeAudioSession];
    self.statucLabel.text = @"scanning...";
    [self setUpAudioBufferPlayer];
}

- (NSLock *) synthLock {
    if(!_synthLock) {
        _synthLock = [[NSLock alloc] init];
    }
    return _synthLock;
}

- (void)setUpAudioBufferPlayer
{
	// We need a lock because we update the Synth's state from the main thread
	// whenever the user presses a button, but we also read its state from an
	// audio thread in the MHAudioBufferPlayer callback. Doing both at the same
	// time is a bad idea and the lock prevents that.
    if(!_synthLock) {
        _synthLock = [[NSLock alloc] init];
    }
    
	// The Synth and the MHAudioBufferPlayer must use the same sample rate.
	// Note that the iPhone is a lot slower than a desktop computer, so choose
	// a sample rate that is not too high and a buffer size that is not too low.
	// For example, a buffer size of 800 packets and a sample rate of 16000 Hz
	// means you need to fill up the buffer in less than 0.05 seconds. If it
	// takes longer, the sound will crack up.
	float sampleRate = 16000.0f;
    
	_synth = [[Synth alloc] initWithSampleRate:sampleRate];
    
	_player = [[MHAudioBufferPlayer alloc] initWithSampleRate:sampleRate
													 channels:1
											   bitsPerChannel:16
											 packetsPerBuffer:1024];
	_player.gain = 0.9f;
    
	__weak typeof(self) weakSelf = self;
	_player.block = ^(AudioQueueBufferRef buffer, AudioStreamBasicDescription audioFormat)
	{
		__strong typeof(weakSelf) blockSelf = weakSelf;
		if (blockSelf != nil)
		{
			// Lock access to the synth. This callback runs on an internal
			// Audio Queue thread and we don't want to allow any other thread
			// to change the Synth's state while we're still filling up the
			// audio buffer.
			[blockSelf->_synthLock lock];
            
			// Calculate how many packets fit into this buffer. Remember that a
			// packet equals one frame because we are dealing with uncompressed
			// audio; a frame is a set of left+right samples for stereo sound,
			// or a single sample for mono sound. Each sample consists of one
			// or more bytes. So for 16-bit mono sound, each packet is 2 bytes.
			// For stereo it would be 4 bytes.
			int packetsPerBuffer = buffer->mAudioDataBytesCapacity / audioFormat.mBytesPerPacket;
            
			// Let the Synth write into the buffer. The Synth just knows how to
			// fill up buffers in a particular format and does not care where
			// they come from.
			int packetsWritten = [blockSelf->_synth fillBuffer:buffer->mAudioData frames:packetsPerBuffer];
            
			// We have to tell the buffer how many bytes we wrote into it.
			buffer->mAudioDataByteSize = packetsWritten * audioFormat.mBytesPerPacket;
            
			[blockSelf->_synthLock unlock];
		}
	};
    
	[_player start];
}


- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    [[RIOInterface sharedInstance] startListening: self];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    [[RIOInterface sharedInstance] stopListening];
}

- (void) frequencyChangedWithValue:(float)newFrequency {
    self.currentFrequency = newFrequency;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        KeyHelper *helper = [KeyHelper sharedInstance];
        NSString *closestChar = [helper closestCharForFrequency:newFrequency];
        if(closestChar.length > 0) {
            strongSelf.frequencyLabel.text = closestChar;
            [strongSelf detectStart: newFrequency withChar: closestChar];
            [strongSelf recordSequence: closestChar];
        }
    });
}

- (void) recordSequence:(NSString *)closestChar {
    if(foundStart && !foundSignal) {
        foundATime = [[NSDate date] timeIntervalSince1970];
        if(foundATime - foundBTime > INDIVIDUAL_DIFF) {
            sequence = [NSString stringWithFormat: @"%@%@",sequence,closestChar];
            self.statucLabel.text = [NSString stringWithFormat:@"start sequence founded: %@",sequence];
            foundBTime = foundATime;
            sequenceLength++;
            if(sequenceLength >= 4) {
                foundSignal = YES;
            }
        }
    }
}

- (void) detectStart:(float)newFrequency withChar:(NSString*) closestChar {
    if(!foundStart) {
        if([closestChar isEqualToString: STARTCHAR]) {
            if(!foundB && !foundA) {
                foundA = YES;
                foundATime = [[NSDate date] timeIntervalSince1970];
                NSLog(@"foundStart Note with time: %f", foundATime);
            }
        }
        if([closestChar isEqualToString: ENDCHAR]) {
            if(foundA && !foundB) {
                foundBTime = [[NSDate date] timeIntervalSince1970];
                NSLog(@"foundEnd Note with time: %f", foundBTime);
                NSLog(@"diff %f", foundBTime - foundATime);
                if(foundBTime - foundATime < STARTSEQUENCE_MAX_DIFF) {
                    foundB = YES;
                    foundStart = YES;
                    sequence = @"";
                    sequenceLength = 0;
                    self.statucLabel.text = @"start sequence founded";
                } else {
                    foundA = NO;
                }
            }
        }
    }
}

- (IBAction) restart:(id)sender {
    self.statucLabel.text = @"scanning...";
    sequence = @"";
    foundStart = NO;
    foundB = NO;
    foundA = NO;
    foundSignal = NO;
    sequenceLength = 0;
}

- (IBAction) createRandomCode:(id)sender {
    [self restart: nil];
    // random code
    int note[4];
    note[0] = arc4random() %12 + 60;
    note[1] = arc4random() %12 + 60;
    note[2] = arc4random() %12 + 60;
    note[3] = arc4random() %12 + 60;
    self.codeLabel.text = [NSString stringWithFormat: @"%@-%@-%@-%@",
                           [[KeyHelper sharedInstance] noteStringFromMapping: note[0]],
                           [[KeyHelper sharedInstance] noteStringFromMapping: note[1]],
                           [[KeyHelper sharedInstance] noteStringFromMapping: note[2]],
                           [[KeyHelper sharedInstance] noteStringFromMapping: note[3]]];
    // start code
    CGFloat delay = 0;
    [self performSelector: @selector(playNote:)  withObject: @(STARTNOTE) afterDelay: delay];
    delay += 0.25;
    [self performSelector: @selector(playNote:)  withObject: @(ENDNOTE) afterDelay: delay];
    delay += 0.2;
    [self performSelector: @selector(playNote:)  withObject: @(note[0]) afterDelay: delay];
    delay += 0.21;
    [self performSelector: @selector(playNote:)  withObject: @(note[1]) afterDelay: delay];
    delay += 0.22;
    [self performSelector: @selector(playNote:)  withObject: @(note[2]) afterDelay: delay];
    delay += 0.23;
    [self performSelector: @selector(playNote:)  withObject: @(note[3]) afterDelay: delay];
}

- (void) playNote:(NSNumber *)note {
    [self.synthLock lock];
	[self.synth playNote:[note integerValue]];
	[self.synthLock unlock];
}

@end
