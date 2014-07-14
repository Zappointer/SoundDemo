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

@interface BSPKViewController () <RecorderDelegate>

@property (nonatomic,strong) AMRecorder *bspkRecorder;
@property (nonatomic,strong) AMPlayer *bspkPlayer;
@property (nonatomic,strong) IBOutlet UITextField *textField;
@property (nonatomic,strong) IBOutlet UILabel *statusLabel;
@property (nonatomic,strong) IBOutlet UIButton *sendButton;
@property (nonatomic,strong) IBOutlet UIButton *stopButton;
@property (nonatomic,strong) IBOutlet UIButton *listenButton;
@property (nonatomic,strong) IBOutlet UILabel *listenStatusLabel;

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
    self.textField.text = @"ab123456789012";
}

- (IBAction) sendMessage:(id)sender {
    if(self.bspkPlayer.playState.mIsRunning) {
        NSAssert(true, @"should never get here");
        return;
    }
    if(self.textField.text.length > 0 && self.textField.text.length <= MAXCODECHARACTER) {
        [self.bspkPlayer play: self.textField.text];
        self.sendButton.enabled = NO;
        self.statusLabel.text = [NSString stringWithFormat: @"sending %@",self.textField.text];
    }
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
        [self.bspkRecorder startRecording];
        self.listenButton.selected = YES;
        self.listenStatusLabel.text = @"Listening";
    }
}

- (void) frequencyDetected:(CGFloat)frequency {
    self.listenStatusLabel.text = [@(frequency) stringValue];
}

@end
