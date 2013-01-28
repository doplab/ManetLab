//
//  MLControllerStream.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


/*
 * MLControllerStream delegate protocol
 */
@protocol MLStreamsUtilityDelegate <NSObject>

-(void)onData:(NSDictionary*)newData;   // New dict of data from peer callback
-(void)onClose;                         // Streams closed callback
-(void)onError;                         // Streams error

@end

@interface MLStreamsUtility : NSObject <NSStreamDelegate> {
    
    NSInputStream* streamIn;                    // IN stream
    NSOutputStream* streamOut;                  // OUT stream
    NSMutableData* bufferOut;                   // OUT buffer
    NSMutableData* bufferIn;                    // IN buffer
    id<MLStreamsUtilityDelegate> delegate;      // delegate   
}

-(id)initWithInputStream:(NSInputStream*)ins andOutputStream:(NSOutputStream*)outs delegate:(id<MLStreamsUtilityDelegate>)del;
-(void)sendData:(NSDictionary*)dictToSend;
-(void)close;

@end
