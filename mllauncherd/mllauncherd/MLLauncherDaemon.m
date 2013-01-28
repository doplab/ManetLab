//
//  MLLauncherDaemon.m
//  mllauncherd
//
//  Created by Francois Vessaz on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#include <asl.h>

#import "MLLauncherDaemon.h"
#import <ManetLabFramework/ManetLabFramework.h>

#define EXEC_NAME "mllauncherd"
#define EXEC_IDENTIFIER "ch.unil.doplab.mllauncherd"

// Private methods
@interface MLLauncherDaemon() {
    
    aslclient logclient;                // log client
    aslmsg logmsg;                      // log msg
    ManetLabFramework* framework;       // framework singleton
    BOOL keepRunning;                   // flag if should continue runloop
    NSRunLoop *runLoop;                 // run loop
    
}

-(BOOL)initLogging:(BOOL)debug;
    
@end

@implementation MLLauncherDaemon

-(id)initWithDebug:(BOOL)debug {
    self = [super init];
    if (self) {
        
        keepRunning = YES;
        
        // Initialize logging
        if(![self initLogging:debug]){
            return nil;
        }
    }
    return self;
}

-(void)logWithLevel:(int)level andMsg:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString* res = [[NSString alloc] initWithFormat:format arguments:args];
    asl_log(logclient, logmsg, level, "%s",[res UTF8String]);
    [res release];
    va_end(args);
}

-(BOOL)initLogging:(BOOL)debug {
    logclient = NULL;
    logmsg = NULL;
    u_int32_t logopts = 0;
    if (debug) {
        logopts = ASL_OPT_STDERR;
    }
    logclient = asl_open(EXEC_NAME, EXEC_IDENTIFIER,logopts);
    logmsg = asl_new(ASL_TYPE_MSG);
    if (logclient == NULL || logmsg == NULL){
        return NO;
    }
    asl_set(logmsg, ASL_KEY_FACILITY, EXEC_IDENTIFIER);
    asl_set(logmsg, ASL_KEY_SENDER, EXEC_NAME);
    asl_log(logclient, logmsg, ASL_LEVEL_NOTICE, "%s (%s) started", EXEC_NAME, EXEC_IDENTIFIER);
    return YES;
}

-(int)run {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    // Check for startup
    framework = [[ManetLabFramework sharedInstance] retain];
    if (framework != nil){
        [framework checkPrefsUpdates];
    } else {
        [self logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to instantiate ML framework"];
    }
    [pool drain];
    
    runLoop = [NSRunLoop currentRunLoop];
    while (keepRunning && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
        [pool drain];
    }
    [pool release];
    return 0;
}

-(void)stopWithSignal:(int)sig {
    asl_log(logclient, logmsg, ASL_LEVEL_NOTICE, "Recieved signal %s",strsignal(sig));
    keepRunning = NO;
    
    // trick to activate runloop
    [self performSelectorOnMainThread:@selector(description) withObject:nil waitUntilDone:NO];
}

- (void)dealloc {
    [framework release];
    
    // Close logging
    asl_log(logclient, logmsg, ASL_LEVEL_NOTICE, "%s (%s) terminated", EXEC_NAME, EXEC_IDENTIFIER);
    asl_close(logclient);
     
    [super dealloc];
}

@end