//
//  MLControlInterface.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <CoreLocation/CoreLocation.h>
#import "MLTask.h"

@interface MLAgent : NSObject <CLLocationManagerDelegate>

@property (readonly) NSDictionary* wlanSettings;
@property (readonly) CLLocation* lastLoc;

-(id)initWithHost:(NSHost*)host;
-(id)initWithService:(NSNetService*)service;
-(void)checkinWithAdhocInterface:(NSString*)adhocInterface;
-(void)disconnect;
-(void)reconnectStack;
-(void)logToTask:(unsigned int)taskId event:(NSString*)event withStatus:(MLTaskAgentStatus)status;

@end
