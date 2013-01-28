//
//  MLStackLayer.m
//  MLStackAPI
//
//  Created by Francois Vessaz on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MLStackLayer+Internal.h"
#import "MLMessage+Internal.h"
#import "MLStack.h"
#include <stdarg.h>

NSString* MLstringForSendResult(MLSendResult code) {
    switch (code) {
        case kMLSendSuccess:
            return @"Message sent successfully.";
        case kMLSendError:
            return @"Error while sending message.";
        case kMLSendTooBig:
            return @"Error: too big message, unable to send it.";
        case kMLSendTimeout:
            return @"Error: timeout occurs while sending.";
        case kMLSendNotImplemented:
            return @"Error: a layer is not yet implemented.";
        default:
            return [NSString stringWithFormat:@"Unknown send result code: %i",code];
    }
}

@interface MLStackLayer () {
    
    MLStackLayer* _upperLayer;  // Upper layer (to user)
    MLStackLayer* _lowerLayer;  // Lower layer (to network)
    MLStack* _stack;            // Stack, container of the layers hierarchy
    
}

@end

@implementation MLStackLayer

- (id)init
{
    self = [super init];
    if (self) {
        _upperLayer = nil;
        _lowerLayer = nil;
        _stack = nil;
    }
    return self;
}

// You need to override this method!
-(MLSendResult)send:(MLMessage*)msg {
    [self logFor:msg event:@"WARNING 'send' method not implemented in layer %@",[self className]];
    return kMLSendNotImplemented;
}

// You need to override this method!
-(void)deliver:(MLMessage*)msg {
    [self logFor:msg event:@"WARNING 'deliver' method not implemented in layer %@",[self className]];
}

// Pass msg to lower layer
-(MLSendResult)sendFurther:(MLMessage*)msg {
    return [_lowerLayer send:msg];
}

// Pass msg to upper layer.
-(void)deliverFurther:(MLMessage*)msg {
    [_upperLayer deliver:msg];
}

// Log event related to msg task id.
-(void)logFor:(MLMessage*)msg event:(NSString*)event, ... {
    va_list args;
    va_start(args, event);
    NSString* res = [[NSString alloc] initWithFormat:event arguments:args];
    [_stack logToTask:msg.taskId event:res];
    [res release];
    va_end(args);
}

// Host's current location.
-(CLLocation*)currentLocation {
    return [_stack currentLocation];
}

// Host's MAC address
-(NSString*)hostAddress {
    return [_stack hostAddress];
}

@end

@implementation MLStackLayer (Internal)

-(void)setStack:(MLStack*)stack {
    _stack = stack;
}

-(void)setUpperLayer:(MLStackLayer*)upperLayer {
    _upperLayer = upperLayer;
}

-(void)setLowerLayer:(MLStackLayer*)lowerLayer {
    _lowerLayer = lowerLayer;
}

@end
