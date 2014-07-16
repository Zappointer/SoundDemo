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
//        lH.generate(bits,
//                    "0 0.21991 0.23328 0.02058 0 0.08543 0.06540 0.04767 0.01912 "
//                    "0 0 0 0 0 0 0 0 0 0.08064 0.22798",
//                    "0 0 0 0 0 0 0 0.64854 0.34747 0.00399",
//                    "rand",
//                    "200 6");
        
        
        lH.generate(bits,
                   "0 0.27684 0.28342 0 0 0 0 0 0.43974",
                   "0 0 0 0 0 0.01568 0.85244 0.13188",
                   "rand",   // random unstructured matrix
                   "200 6"); // optimize girth
        lH.display_stats();
        std::cout << "c:" << lH.get_nvar() << " r:" << lH.get_ncheck() << std::endl;
        strongMe->G = LDPC_Generator_Systematic(&lH);
        strongMe->C = LDPC_Code(&lH, &strongMe->G);
//        strongMe->C.set_exit_conditions(2500);
        strongMe->C.set_llrcalc(LLR_calc_unit(12,0,7));
        
        
        
        strongMe.ready = YES;
        
        
    });
}

@end
