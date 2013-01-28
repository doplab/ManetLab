//
//  MLMessage.h
//  MLStackAPI
//
//  Created by Francois Vessaz on 4/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * Message used by MLStackLayer to pass data between two layers.
 */
@interface MLMessage : NSObject

@property (readonly) NSString* from;        // sender
@property (readonly) NSString* to;          // receiver
@property (readonly) unsigned int taskId;   // message task id (useful for ML to log ops related to this msg)
@property (readonly) NSData* msgData;       // msg content (data&headers)

// init method:
-(id)initWithData:(NSData*)data from:(NSString*)aSender to:(NSString*)aDestination andTask:(NSString*)aTaskId;

// add, read, remove headers before msg data
-(void)addHeader:(const void *)header length:(NSUInteger)length;
-(void)readHeader:(void *)header length:(NSUInteger)length;
-(void)readAndRemoveHeader:(void *)header length:(NSUInteger)length;
-(void)removeHeaderOflength:(NSUInteger)length;

@end
