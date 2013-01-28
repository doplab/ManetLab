//
//  MLMessage_Internal.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 10/11/12.
//
//

#import "MLMessage.h"

@interface MLMessage (Internal)

-(id)initWithBytes:(const void *)bytes length:(NSUInteger)length;
-(NSData*)getSerializedMessage:(NSString*)localMAC;

@end
