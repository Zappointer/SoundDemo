//
//  BSPKViewController.m
//  SoundHandShake
//
//  Created by Jason Chang on 7/14/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import "BSPKViewController.h"
#import "AMPlayer.h"
#import "AMRecorder.h"
#import "LDPCGenerator.h"

@interface BSPKViewController () <RecorderDelegate, UITextFieldDelegate>

@property (nonatomic,strong) AMRecorder *bspkRecorder;
@property (nonatomic,strong) AMPlayer *bspkPlayer;
@property (nonatomic,strong) IBOutlet UITextField *textField;
@property (nonatomic,strong) IBOutlet UILabel *statusLabel;
@property (nonatomic,strong) IBOutlet UIButton *sendButton;
@property (nonatomic,strong) IBOutlet UIButton *stopButton;
@property (nonatomic,strong) IBOutlet UIButton *listenButton;
@property (nonatomic,strong) IBOutlet UILabel *listenStatusLabel;
@property (nonatomic,strong) IBOutlet UILabel *foundDecodeLabel;
@property (nonatomic,strong) IBOutlet UILabel *extraInfoLabel;
@property (nonatomic,strong) NSDate *startDate;

@end

@implementation BSPKViewController

- (AMRecorder *) bspkRecorder {
    if(!_bspkRecorder) {
        _bspkRecorder = [AMRecorder new];
        _bspkRecorder.delegate = self;
    }
    return _bspkRecorder;
}

- (AMPlayer *) bspkPlayer {
    if(!_bspkPlayer) {
        _bspkPlayer = [AMPlayer new];
    }
    return _bspkPlayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.listenStatusLabel.text = @"Not Listening";
    self.textField.text = @"1234";
    self.textField.delegate = self;
}

- (IBAction) sendMessage:(id)sender {
    if(self.bspkPlayer.playState.mIsRunning) {
        NSAssert(true, @"should never get here");
        return;
    }
    if(self.textField.text.length > 0 && self.textField.text.length <= [LDPCGenerator sharedGenerator].characterLength) {
        
        [self.bspkPlayer play: [self padString: self.textField.text toLength: [LDPCGenerator sharedGenerator].characterLength]];
        self.sendButton.enabled = NO;
        self.statusLabel.text = [NSString stringWithFormat: @"sending %@",self.textField.text];
    }
}

- (NSString *) padString:(NSString *)string toLength:(int) length {
    if(string.length != length) {
        int paddinglength = length - string.length;
        NSMutableString *mString = [NSMutableString new];
        for(int i = 0; i < paddinglength; i++) {
            [mString appendString: @" "];
        }
        return [string stringByAppendingString: mString];
    }
    return string;
}

- (IBAction) stopMessage:(id)sender {
    [self.bspkPlayer stop];
    self.sendButton.enabled = YES;
    self.statusLabel.text = @"";
}

- (IBAction) toggleListening:(id)sender {
    if(self.listenButton.selected) {
        [self.bspkRecorder stopRecording];
        self.listenButton.selected = NO;
        self.listenStatusLabel.text = @"Not Listening";
    } else {
        self.startDate = [NSDate date];
        [self.bspkRecorder startRecording];
        self.listenButton.selected = YES;
        self.listenStatusLabel.text = @"Listening";
    }
}

- (void) frequencyDetected:(CGFloat)frequency {
    self.listenStatusLabel.text = [@(frequency) stringValue];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void) decodedStringFound:(NSString *) string {
    self.foundDecodeLabel.text = [NSString stringWithFormat: @"Found String: %@",string];
    if(![string isEqualToString: @"decode failed"]) {
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate: self.startDate];
        self.extraInfoLabel.text = [NSString stringWithFormat: @"%1.2f used" ,interval];
        [self toggleListening: nil];
    }
}

- (void) startDecoding {
    self.listenStatusLabel.text = @"Listening, start decoding";
}



- (void) bufferUpdatedWithData:(void *)data size:(UInt32)size {
    AUDIO_INPUT_TYPE *samples = (AUDIO_INPUT_TYPE *)data;
    
}

@end
