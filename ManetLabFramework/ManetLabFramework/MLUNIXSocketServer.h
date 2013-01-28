//
//  MLUNIXConnection.h
//  mllauncherd
//
//  Created by Francois Vessaz on 12/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLStreamsUtility.h"

@protocol MLUNIXSocketServerDelegate <NSObject>

-(void)onData:(NSDictionary*)newData;
-(void)onClose;

@end

@interface MLUNIXSocketServer : NSObject <MLStreamsUtilityDelegate>

-(id)initWithPath:(NSString*)aPath andDelegate:(id<MLUNIXSocketServerDelegate>)del;
-(void)close;
-(BOOL)sendData:(NSDictionary*)newData;

@end
