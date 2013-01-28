//
//  MLAgentProxy.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLAgentProxy.h"
#import "MLController.h"
#import "ManetLabFramework+Internal.h"

@implementation MLAgentProxy

@synthesize agentName, agentAddress, agentLat, agentLong, agentState;

/*
 * Init proxy. Delegate streams task to MLControllerStreams
 */
-(id)initWithInputStream:(NSInputStream*)ins andOutputStream:(NSOutputStream*)outs address:(NSString*)anAddress server:(MLController*)aServer {
    self = [super init];
    if (self) {
        streams = [[MLStreamsUtility alloc] initWithInputStream:ins andOutputStream:outs delegate:self];
        server = aServer;
        agentAddress = [anAddress retain];
        agentName = nil;
        agentLong = [[NSNumber numberWithInt:0] retain];
        agentLat = [[NSNumber numberWithInt:0] retain];
    }
    return self;
}

/*
 * Disconnect agent from controller
 */
-(void)disconnect {
    [streams close];
}

/*
 * Request a state update from agent
 */
-(void)updateState {
    NSDictionary* request = [NSDictionary dictionaryWithObject:@"status" forKey:@"action"];
    [streams sendData:request];
}

/*
 * Streams to agent callback
 */
-(void)onData:(NSDictionary*)newData {
    NSString* action = nil;
    action = [newData valueForKey:@"action"];
    if ([action isEqualToString:@"checkin"] && agentName == nil) {
        agentName = [[newData valueForKey:@"name"] retain];
        agentState = [[newData valueForKey:@"state"] retain];
        
        // Answer settings
        NSMutableDictionary* wlanSettings = [NSMutableDictionary dictionary];
        NSDictionary* prefs = [[ManetLabFramework sharedInstance] getPrefs];
        [wlanSettings setValue:[prefs valueForKey:@"wlanName"] forKey:@"ssid"];
        [wlanSettings setValue:[prefs valueForKey:@"wlanPassword"] forKey:@"password"];
        [wlanSettings setValue:[prefs valueForKey:@"wlanChannel"] forKey:@"channel"];
        NSDictionary* wlanData = [NSDictionary dictionaryWithObjectsAndKeys:@"wlan-settings", @"action", wlanSettings, @"settings", nil];
        [streams sendData:wlanData];
    } else if ([action isEqualToString:@"locupdate"]) {
        if (agentLat != nil) {
            [agentLat release];
        }
        if (agentLong != nil) {
            [agentLong release];
        }
        agentLat = [(NSNumber*)[newData valueForKey:@"lat"] retain];
        agentLong = [(NSNumber*)[newData valueForKey:@"long"] retain];
    } else if ([action isEqualToString:@"stateupdate"]) {
        [agentState release];
        agentState = [[newData valueForKey:@"state"] retain];
        [server agentsList];
    } else if ([action isEqualToString:@"taskUpdate"]) {
        [server updateTask:[newData valueForKey:@"taskId"] ofAgent:agentName toState:[[newData valueForKey:@"status"] intValue] withEvent:[newData valueForKey:@"event"] at:[newData valueForKey:@"time"] line:[[newData valueForKey:@"line"] intValue]];
    } else if ([action isEqualToString:@"pluginsList"]) {
        [server announceLayers:[newData valueForKey:@"availablePlugins"] forAgent:agentName];
    }
}

/*
 * Forward send to strems
 */
-(void)sendData:(NSDictionary*)dataToSend {
    //NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [streams sendData:dataToSend];
    //[pool release];
}

/*
 * Streams to agent callback
 */
-(void)onClose {
    [server closeConnection:self];
}

/*
 * Streams callback
 */
-(void)onError {
    [server closeConnection:self];
}

/*
 * Cleanup
 */
- (void)dealloc {
    if (agentLat != nil) {
        [agentLat release];
    }
    if (agentLong != nil) {
        [agentLong release];
    }
    [agentState release];
    [streams release];
    [agentAddress release];
    [agentName release];
    [super dealloc];
}

@end
