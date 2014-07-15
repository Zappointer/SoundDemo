//
//  LDPCGenerator.m
//  SoundHandShake
//
//  Created by Jason Chang on 7/14/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import "LDPCGenerator.h"

@implementation LDPCGenerator

+ (instancetype) sharedGenerator {
    static LDPCGenerator *_sharedGenerator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedGenerator = [[LDPCGenerator alloc] init];
    });
    return _sharedGenerator;
}

- (void) setup {
    self.ready = NO;
    if(self.characterLength <= 0) {
        return;
    }
    const int bytepercharacter = 1;
    const int bitperbyte = 8;
    int bits = self.characterLength * bytepercharacter * bitperbyte * 2;
    __weak typeof(self) weakMe = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
        __strong typeof(self) strongMe = weakMe;
        LDPC_Parity_Irregular lH = strongMe->H;
        lH.generate(bits,
                   "0 0.27684 0.28342 0 0 0 0 0 0.43974",
                   "0 0 0 0 0 0.01568 0.85244 0.13188",
                   "rand",   // random unstructured matrix
                   "500 8"); // optimize girth
        strongMe->G = LDPC_Generator_Systematic(&lH);
        strongMe->C = LDPC_Code(&lH, &strongMe->G);
        strongMe->C.set_exit_conditions(2500);
        strongMe.ready = YES;
    });
}

@end
