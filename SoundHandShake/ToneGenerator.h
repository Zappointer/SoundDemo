//
//  ToneGenerator.h
//  SoundHandShake
//
//  Created by Jason Chang on 6/26/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ToneGenerator : NSObject {

@public
    double frequency;
    double sampleRate;
    double theta;

}

- (void) play;
- (void) stop;

@end
