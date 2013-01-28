//
//  main.m
//  mllauncherd
//
//  Created by Francois Vessaz on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLLauncherDaemon.h"

void sig_handler(int sig);

static MLLauncherDaemon* daemonInstance = nil;

/*
 * Main function of daemon, call with -debug to run in terminal
 */
int main (int argc, const char * argv[])
{
    
    BOOL debug = NO;
    
    // Parameters
    if (argc > 1) {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-debug") == 0) {
                debug = YES;
            }
        }
    }
    
    // Handle signals
    signal(SIGTERM, sig_handler);
    signal(SIGKILL, sig_handler);
    signal(SIGINT, sig_handler);
    signal(SIGPIPE, SIG_IGN);
    
    // Lyfecycle
    int retval = 0;
    daemonInstance = [[MLLauncherDaemon alloc] initWithDebug:debug];
    if (daemonInstance != nil) {
        retval = [daemonInstance run];
        [daemonInstance release];
    } else {
        retval = 1; // ERROR code 1: error on daemon init
    }
    
    return retval;
}

/*
 * System signal handler
 */
void sig_handler(int sig)
{
    [daemonInstance stopWithSignal:sig];
}