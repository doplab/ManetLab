//
//  MLLauncherDaemon.h
//  mllauncherd
//
//  Created by Francois Vessaz on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

@interface MLLauncherDaemon : NSObject

-(id)initWithDebug:(BOOL)debug;
-(int)run;
-(void)stopWithSignal:(int)sig;
-(void)logWithLevel:(int)level andMsg:(NSString*)format, ...;

@end
