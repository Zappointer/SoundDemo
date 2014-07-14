//
//  AMConstants.h
//  SoundHandShake
//
//  Created by Jason Chang on 7/11/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#ifndef __AM_CONSTANTS_h__
#define __AM_CONSTANTS_h__

#define str_(x) #x
#define str2_(x) str_(x)
#define cat_(x,y) x ## y
#define cat2_(x,y) cat_(x,y)
//#define ENVIRONMENT_HEADER str2_(cat2_(AudioModem_, CONFIGURATION.h))
//#include ENVIRONMENT_HEADER

#define kNumberBuffers 3

#define SR 44100
#define FREQ 1800.0//(SR*8/18)
#define BIT_RATE (SR/1)//(SR/36)
#define SAMPLE_PER_BIT 1//36//(SR/BIT_RATE)
#define SAMPLE_PER_BYTE (8 * SAMPLE_PER_BIT)
#define BARKER_LEN 13
#define CORR_MAX_COEFF 0.9

#endif