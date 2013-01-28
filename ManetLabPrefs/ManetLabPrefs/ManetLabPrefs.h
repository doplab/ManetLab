//
//  ManetLabPrefs.h
//  ManetLabPrefs
//
//  Created by François Vessaz on 9/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

#include <asl.h>

@class WLANManager;
@class MondoSwitch;

@interface ManetLabPrefs : NSPreferencePane <NSNetServiceBrowserDelegate> {
    
    MondoSwitch* mainSwitch;                    // Main switch, TimeMachine prefs style 
    NSPopUpButton *adhocInterfaceSelector;      // Popup for adhoc interface
    NSPopUpButton *controlInterfaceSelector;    // Popup for control interface
    NSComboBox *controllerSelector;             // ComboBox for controller
    aslmsg logmsg;                              // log msg structure
    aslclient logclient;                        // log client
    CFSocketRef sockCF;                         // UNIX socket to call mllauncherd
    NSMutableDictionary* prefs;                 // cache of stored preferences
    BOOL errorOnInit;                           // Flag YES if unable to connect pref socket
    WLANManager* wlan;                          // get wlan interfaces names
    NSNetServiceBrowser* browser;               // Browser for ML controller availables
    NSPopUpButton* channelSelector;             // adhoc network channel
    NSTextField* wlanNameSelector;              // name (SSID) for adhoc network
    NSSecureTextField* passwordSelector;        // password for adhoc network
    NSTextField* onLabel;                       // label "ON" near main switch
    BOOL _on;                                   // cache of switch state
    
}

@property (nonatomic, retain) IBOutlet NSTextField* onLabel;
@property (nonatomic, retain) IBOutlet MondoSwitch* mainSwitch;
@property (nonatomic, retain) IBOutlet NSPopUpButton* adhocInterfaceSelector;
@property (nonatomic, retain) IBOutlet NSPopUpButton *controlInterfaceSelector;
@property (nonatomic, retain) IBOutlet NSComboBox *controllerSelector;
@property (nonatomic, retain) IBOutlet NSSegmentedControl *roleSelector;
@property (nonatomic, retain) IBOutlet NSPopUpButton* channelSelector;
@property (nonatomic, retain) IBOutlet NSTextField* wlanNameSelector;
@property (nonatomic, retain) IBOutlet NSSecureTextField* passwordSelector;
@property (getter = isOn, setter = setOn:) BOOL on;

-(void)mainViewDidLoad;
-(void)updateDisplay;
-(IBAction)onChange:(id)sender;
-(void)sendPrefs;

@end