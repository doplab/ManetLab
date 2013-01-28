//
//  ManetLabFramework+Internal.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#include <asl.h>

#import "ManetLabFramework.h"

//Current state of the framework
typedef enum {
    kMLStopped              = 0,
    kMLWaitingController    = 1,
    kMLWaitingWLAN          = 2,
    kMLStarted              = 3,
    kMLStopping             = 4,
    kMLError                = 5
} MLState;

@class MLLowestLayer;

@interface ManetLabFramework (Internal) 

@property MLState state;

-(void)logWithLevel:(int)level andMsg:(NSString*)format, ...;
-(void)goIntoErrorMode;
-(void)connectWLAN;
-(NSDictionary*)getPrefs;
-(void)connectController;
-(MLLowestLayer*)getLowestLayer;

@end
