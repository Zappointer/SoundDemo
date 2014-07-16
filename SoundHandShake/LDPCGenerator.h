//
//  LDPCGenerator.h
//  SoundHandShake
//
//  Created by Jason Chang on 7/14/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <itpp/itcomm.h>
#import <itpp/base/math/elem_math.h>

using namespace itpp;

@interface LDPCGenerator : NSObject {
    @public
    LDPC_Parity_Irregular H;
    LDPC_Code C;
    LDPC_Generator_Systematic G;
}

+ (instancetype) sharedGenerator;
- (void) setup;

@property (nonatomic,assign) double signal0Frequency;
@property (nonatomic,assign) double signal1Frequency;
@property (nonatomic,assign) double startSignalFrequency;
@property (nonatomic,assign) int characterLength;
@property (nonatomic,assign) BOOL ready;

@end
