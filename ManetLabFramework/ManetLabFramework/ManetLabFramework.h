//
//  ManetLabFramework.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

@interface ManetLabFramework : NSObject

+(ManetLabFramework*)sharedInstance;
-(void)checkPrefsUpdates;

@end