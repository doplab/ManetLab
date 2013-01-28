//
//  MLStackLayer.h
//  MLStackAPI
//
//  Created by Francois Vessaz on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "MLMessage.h"

typedef enum {
    kMLSendSuccess          = 0,    // msg sent
    kMLSendError            = -1,   // undefined error
    kMLSendTooBig           = -2,   // msg too big, you need to fragment it
    kMLSendTimeout          = -3,   // unable to send msg before timeout
    kMLSendNotImplemented   = -4    // send method not implemented
} MLSendResult;

NSString* MLstringForSendResult(MLSendResult);  // textual representation of MLSendResult

/*
 * A layer in the adhoc stack. You need to herit from this class and override send & deliver to have a valid layer.
 */
@interface MLStackLayer : NSObject

-(MLSendResult)send:(MLMessage*)msg;            // override this method to send a message
-(void)deliver:(MLMessage*)msg;                 // override this method to handle incoming messages
-(MLSendResult)sendFurther:(MLMessage*)msg;     // request next layer to send message (do down, to network)
-(void)deliverFurther:(MLMessage*)msg;          // request next layer to deliver message (go up, to user)

-(void)logFor:(MLMessage*)msg event:(NSString*)event, ...;  // log event related to msg task id
-(CLLocation*)currentLocation;                              // host's current location
-(NSString*)hostAddress;                                    // host's MAC address

@end
