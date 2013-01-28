//
//  WLANController.h
//  ManetLab
//
//  Created by François Vessaz on 8/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <CoreWLAN/CoreWLAN.h>

@interface MLWLANController : NSObject {
    
    CWInterface* selectedInteface;  // could be private, SL compatibility
    int selectedChannel;            // could be private, SL compatibility
}

-(BOOL)checkSelectedInterfaceForIBSS;   // could be private, SL compatibility
-(BOOL)waitForIpaddress; // could be private, SL compatibility

-(BOOL)checkIfParamsAreEqualTo:(NSString*)ssidName andInterface:(NSString*)interfaceName andChannel:(int)channelNb;

-(NSArray*)getAvailableInterfaces; // returns all WLAN available interfaces
-(BOOL)selectInterface:(NSString*)interfaceName; // use another WLAN interface than the default one (generally en1)
-(NSString*)selectedInterface; //returns current WLAN interface;
-(void)selectDefaultChannel:(int)channel; // use another channel than the default one (11)

-(BOOL)startAdHocSession:(NSString*)sessionName; // starts without security
-(BOOL)startAdHocSecureSession:(NSString*)sessionName withPassword:(NSString*)password; // starts with WEP140 security, password must be 13 characters
-(void)disconnect; // disconnects from IBSS

@end
