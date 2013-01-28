//
//  MLStack.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 12/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLStack.h"
#import "ManetLabFramework+Internal.h"
#import "MLLowestLayer.h"
#import "MLStackLayersList.h"
#import "MLAgent.h"

#define PLUGIN_FOLDER @"file://localhost/Library/Application%20Support/ManetLab/Plugins/"

@interface MLStack () {
    
    NSMutableArray* layers;     // layers of the adhoc stack
    MLAgent* agent;             // agent creating the stack
    
}

-(Class)layerForName:(NSString*)layerName;

@end

@implementation MLStack

/*
 * Init a new stack
 */
-(id)initWithLayers:(NSArray*)aStack andAgent:(MLAgent*)anAgent
{
    self = [super init];
    if (self) {
        layers = [[NSMutableArray array] retain];
        agent = anAgent;
        
        // load layers
        for (NSString* layerName in aStack) {
            Class layerClass = NULL;
            layerClass = [self layerForName:layerName];
            MLStackLayer* newLayer = nil;
            if (layerClass != NULL) {
                newLayer = [[layerClass alloc] init];
            }
            if (newLayer == nil) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while setting layers in adhoc stack."];
                return nil;
            }
            [newLayer setStack:self];
            [layers addObject:newLayer];
            [newLayer release];
        }
        
        // connect stack to top layers
        [self setLowerLayer:[layers objectAtIndex:0]];
        [[layers objectAtIndex:0] setUpperLayer:self];
        
        [self reconnect];
        
        // connect ointermediate layers
        for (int i=1; i<[layers count]; i++) {
            MLStackLayer* layerA = [layers objectAtIndex:(i-1)];
            MLStackLayer* layerB = [layers objectAtIndex:i];
            [layerA setLowerLayer:layerB];
            [layerB setUpperLayer:layerA];
        }
    }
    return self;
}

/*
 * (re)connect the lowest layer (WLAN) to the stack
 * after a loss of WLAN for example
 */
-(void)reconnect {
    MLStackLayer* lastLayer = [layers lastObject];
    [lastLayer setLowerLayer:[[ManetLabFramework sharedInstance] getLowestLayer]];
    [[[ManetLabFramework sharedInstance] getLowestLayer] setUpperLayer:lastLayer];
}

/*
 * Get the layer corresponding to layerName in the available plugins or crash.
 */
-(Class)layerForName:(NSString*)layerName {
    NSError* err = nil;
    NSArray* pluginsPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL URLWithString:PLUGIN_FOLDER] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:&err];
    if (err != nil) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while listing plugins in folder: %@",[err localizedDescription]];
    }
    for (NSURL* url in pluginsPaths) {
        NSBundle* plugin = nil;
        plugin = [NSBundle bundleWithURL:url];
        if (plugin == nil) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get bundle for plugin %@",[url absoluteString]];
            break;
        }
        Class principalClass = nil;
        principalClass = [plugin principalClass];
        if (principalClass == nil) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get principal class for %@",[url absoluteString]];
            break;
        }
        if ([principalClass isSubclassOfClass:[MLStackLayersList class]]){
            MLStackLayersList* layersList = nil;
            layersList = [[[principalClass alloc] init] autorelease];
            if (layersList != nil) {
                Class layerClass = NULL;
                layerClass = [layersList layerForName:layerName];
                if (layerClass != NULL) {
                    return layerClass;
                }
            } else {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to instantiate principal class for %@",[url absoluteString]];
            }
        } else {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Principal class of %@ is not a subclass of MLStackLayersList",[url absoluteString]];
        }
    }
    return nil;
}

/*
 * Return last loacation of agent.
 */
-(CLLocation*)currentLocation {
    return agent.lastLoc;
}

/*
 * Returns IPv6 address
 */
-(NSString*)hostAddress {
    return [[[ManetLabFramework sharedInstance] getLowestLayer] hostAddress];
}

/*
 * Log an event of a message.
 */
-(void)logFor:(MLMessage*)msg event:(NSString*)event, ... {
    va_list args;
    va_start(args, event);
    NSString* res = [[NSString alloc] initWithFormat:event arguments:args];
    [self logToTask:msg.taskId event:res];
    [res release];
    va_end(args);
}

/*
 * Log an evant to controller via control link
 */
-(void)logToTask:(unsigned int)taskId event:(NSString*)event {
    [agent logToTask:taskId event:event withStatus:kMLTaskAgentUndetermined];
}

/*
 * Not available for stack.
 */
-(void)setUpperLayer:(MLStackLayer*)upperLayer {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Cannot set upper layer of stack."] userInfo:nil];
}

/*
 * Not available for stack.
 */
-(void)setStack:(MLStack*)stack {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Cannot set stack for stack"] userInfo:nil];
}

/*
 * Forward data to the first layer.
 */
-(MLSendResult)send:(MLMessage*)msg {
    [self logFor:msg event:@"AGENT SEND %@",[msg description]];
    return [self sendFurther:msg];
}

/*
 * Callback for incoming data. End of incoming chain!
 */
-(void)deliver:(MLMessage*)msg {
    [self logFor:msg event:@"AGENT DELIVER %@",[msg description]];
}

- (void)dealloc {
    [layers release];
    [super dealloc];
}

@end
