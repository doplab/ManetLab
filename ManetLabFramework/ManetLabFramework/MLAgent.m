//
//  MLControlInterface.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLAgent.h"
#import "ManetLabFramework+Internal.h"
#import "MLStack.h"
#import "MLStreamsUtility.h"
#import "MLStackLayersList.h"
#import "MLTask.h"
#import "MLLowestLayer.h"

#include <sys/stat.h>

#define CONTROLLER_PORT 7777
#define PLUGIN_FOLDER @"file://localhost/Library/Application%20Support/ManetLab/Plugins/"
#define APP_SUPPORT_FOLDER_PATH "/Library/Application Support/ManetLab"
#define PLUGIN_FOLDER_PATH "/Library/Application Support/ManetLab/Plugins"
#define LOCATIOND_CLIENTS_FILE @"/var/db/locationd/clients.plist"
#define LOCATIOND_BUNDLE @"com.apple.locationd.executable-/usr/local/libexec/mllauncherd"
#define LOCATIOND_EXEC @"/usr/local/libexec/mllauncherd"

@interface MLAgent() <MLStreamsUtilityDelegate> {
    
    MLStreamsUtility* streams;      // TCP streams to ML controller
    NSDictionary* wlanSettings;     // Settings to use for wlan session
    CLLocationManager* locManager;  // Location provider
    CLLocation* lastLoc;            // Last updated location
    MLStack* stack;                 // Ad-hoc stack
    NSTimer* initSendTimer;         // Timer for repeated send
    int repeatCounter;              // repeat send counter to decrement
    int logCounter;                 // Log line number
    unsigned int lastTask;          // last task for which something was logged
    
    NSDateFormatter* dateFormatter;
    
}

-(void)initCommon;
-(void)initiateSend:(NSTimer*)timer;
-(void)logFor:(MLMessage*)msg withStatus:(MLTaskAgentStatus)status event:(NSString*)event, ...;

@end

@implementation MLAgent

@synthesize wlanSettings, lastLoc;

/*
 * Init method with a service discovered by Bonjour.
 */
- (id)initWithService:(NSNetService*)service {
    self = [super init];
    if (self) {
        NSInputStream* streamIn = NULL;
        NSOutputStream* streamOut = NULL;
        if ([service getInputStream:&streamIn outputStream:&streamOut]){
            // SSL settings
            NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
                                      kCFNull,kCFStreamSSLPeerName,
                                      kCFStreamSocketSecurityLevelTLSv1, kCFStreamSSLLevel,
                                      nil];
            CFReadStreamSetProperty((CFReadStreamRef)streamIn, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
            CFWriteStreamSetProperty((CFWriteStreamRef)streamOut, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
            [settings release];
            
            streams = [[MLStreamsUtility alloc] initWithInputStream:streamIn andOutputStream:streamOut delegate:self];
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Control interface connected to bonjour service on %@",[service name]];
        } else {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Control interface unable to connect bonjour service on  %@",[service name]];
            return nil;
        }
        [self initCommon];
    }
    return self;
}

/*
 * Init method to connect to a specific host.
 */
- (id)initWithHost:(NSHost*)host {
    self = [super init];
    if (self) {
        NSInputStream* streamIn = NULL;
        NSOutputStream* streamOut = NULL;
        
        [NSStream getStreamsToHost:host port:CONTROLLER_PORT inputStream:&streamIn outputStream:&streamOut];
        if (streamIn != NULL && streamOut != NULL){
            // SSL settings
            NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
                                      kCFNull,kCFStreamSSLPeerName,
                                      kCFStreamSocketSecurityLevelTLSv1, kCFStreamSSLLevel,
                                      nil];
            CFReadStreamSetProperty((CFReadStreamRef)streamIn, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
            CFWriteStreamSetProperty((CFWriteStreamRef)streamOut, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
            [settings release];
            
            streams = [[MLStreamsUtility alloc] initWithInputStream:streamIn andOutputStream:streamOut delegate:self];
            
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Control interface connected to host %@",[host name]];
        } else {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Control interface unable to connect host %@",[host name]];
            return nil;
        }
        [self initCommon];
    }
    return self;
}

/*
 * Tasks for both init methods
 */
-(void)initCommon {
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
    logCounter = 0;
    lastTask=0;
    
    //appTrick = nil;
    if (kCFCoreFoundationVersionNumber < 744.0) {
        // Before Mountain Lion... (for 10.7.x)
        
        NSDictionary* plist = [NSDictionary dictionaryWithContentsOfFile:@"/var/folders/zz/zyxvpxvq6csfxvn_n00000sm00006d/C/clients.plist"];
        if (plist != nil) {
            plist = [plist mutableCopy];
        } else {
            plist = [[NSMutableDictionary dictionary] retain];
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_WARNING andMsg:@"Warning: Unable to get locationd clients. Assuming file clients.plist does not exist."];
        }
        NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithBool:YES],@"Authorized",
                                  @"/usr/local/libexec/mllauncherd",@"Executable",
                                  [NSNumber numberWithBool:YES],@"PromptedSettings",nil];
        [plist setValue:settings forKey:@"com.apple.locationd.executable-/usr/local/libexec/mllauncherd"];
        if (![plist writeToFile:@"/var/folders/zz/zyxvpxvq6csfxvn_n00000sm00006d/C/clients.plist" atomically:YES]){
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR: Unable to register/authorize mllauncherd to locationd."];
        }
        [plist release];
    } else {
        // 10.8.x
        
        NSDictionary* base = [NSDictionary dictionaryWithContentsOfFile:LOCATIOND_CLIENTS_FILE];
        if (base != nil) {
            if ([base valueForKey:LOCATIOND_BUNDLE] == nil) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Will initializing %@.",LOCATIOND_CLIENTS_FILE];
                int res = system("launchctl unload /System/Library/LaunchDaemons/com.apple.locationd.plist");
                if (res == 0) {
                    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_WARNING andMsg:@"Locationd stopped by mllauncherd."];
                    NSMutableDictionary* curSettings = [[NSDictionary dictionaryWithContentsOfFile:LOCATIOND_CLIENTS_FILE] mutableCopy];
                    NSDictionary* toAdd = [NSDictionary dictionaryWithObjectsAndKeys:
                                           LOCATIOND_BUNDLE,@"BundleId",
                                           [NSNumber numberWithBool:YES],@"Authorized",
                                           LOCATIOND_EXEC,@"Executable",nil];
                    [curSettings setValue:toAdd forKey:LOCATIOND_BUNDLE];
                    if (![curSettings writeToFile:LOCATIOND_CLIENTS_FILE atomically:YES]){
                        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while writing to file %@",LOCATIOND_CLIENTS_FILE];
                    }
                    [curSettings release];
                    int res = system("launchctl load /System/Library/LaunchDaemons/com.apple.locationd.plist");
                    if (res == 0) {
                        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"%@ successfully initialized",LOCATIOND_CLIENTS_FILE];
                    } else {
                        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR: Unable to restart locationd."];
                    }
                } else {
                    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR: Unable to stop locationd."];
                }
            } else {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"%@ already initialized",LOCATIOND_CLIENTS_FILE];
            }
        } else {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR: Unable to read file %@.",LOCATIOND_CLIENTS_FILE];
        }
        
    }
    
    locManager = nil;
    if ([CLLocationManager locationServicesEnabled]) {
        locManager = [[CLLocationManager alloc] init];
        locManager.delegate = self;
        locManager.desiredAccuracy = kCLLocationAccuracyBest;
        lastLoc = nil;
        [locManager startUpdatingLocation];
    } else {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_WARNING andMsg:@"Location service not enabled on this agent."];
    }
    stack = nil;
    
    [[ManetLabFramework sharedInstance] addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:NULL];
}

/*
 * Observe framework state modification
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSDictionary* agentData = [NSDictionary dictionaryWithObjectsAndKeys:@"stateupdate", @"action",[NSNumber numberWithInt:[ManetLabFramework sharedInstance].state],@"state", nil];
    [streams sendData:agentData];
}

/*
 * Register agent to controller
 */
-(void)checkinWithAdhocInterface:(NSString*)adhocInterface {
    NSDictionary* checkinData = [NSDictionary dictionaryWithObjectsAndKeys:@"checkin", @"action", [MLLowestLayer getMACOfInterface:adhocInterface], @"name",[NSNumber numberWithInt:[ManetLabFramework sharedInstance].state],@"state", nil];
    [streams sendData:checkinData];
}

/*
 * Disconnect from controller
 */
-(void)disconnect {
    [streams close];
}

/*
 * Streams callback
 */
-(void)onData:(NSDictionary*)newData {
    NSString* action = nil;
    action = [newData valueForKey:@"action"];
    if ([action isEqualToString:@"wlan-settings"]) {
        wlanSettings = [[newData valueForKey:@"settings"] retain];
        [[ManetLabFramework sharedInstance] connectWLAN];
    } else if ([action isEqualToString:@"addPlugin"]) {
        NSData* pluginData = [newData valueForKey:@"pluginData"];
        NSString* pluginName = [newData valueForKey:@"pluginName"];
        int errNb = mkdir(APP_SUPPORT_FOLDER_PATH, 0775);
        if (errNb != 0 && errno != EEXIST){
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create folder %s: mkdir error %i",APP_SUPPORT_FOLDER_PATH,errno];
        }
        errNb = mkdir(PLUGIN_FOLDER_PATH, 0775);
        if (errNb != 0 && errno != EEXIST){
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create folder %s: mkdir error %i",PLUGIN_FOLDER_PATH,errno];
        }
        NSFileWrapper* fw = [[NSFileWrapper alloc] initWithSerializedRepresentation:pluginData];
        NSError* err = nil;
        if (![fw writeToURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@",PLUGIN_FOLDER,pluginName]] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&err]){
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while writing plugin: %@",[err localizedDescription]];
            [streams sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                               @"taskUpdate",@"action",
                               [newData valueForKey:@"taskId"],@"taskId",
                               [NSNumber numberWithInt:kMLTaskAgentFailure],@"status",nil]];
            [fw release];
            return;
        }
        [fw release];
        [streams sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                           @"taskUpdate",@"action",
                           [newData valueForKey:@"taskId"],@"taskId",
                           [NSNumber numberWithInt:kMLTaskAgentSuccess],@"status",nil]];
    } else if ([action isEqualToString:@"getLayersList"]) {
        NSError* err = nil;
        NSArray* pluginsPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL URLWithString:PLUGIN_FOLDER] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:&err];
        if (err != nil) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while listing plugins in folder: %@",[err localizedDescription]];
        }
        NSMutableArray* allLayers = [NSMutableArray array];
        for (NSURL* url in pluginsPaths) {
            NSBundle* plugin = nil;
            plugin = [NSBundle bundleWithURL:url];
            if (plugin == nil) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get bundle for plugin %@",[url absoluteString]];
                break;
            }
            if ([plugin isLoaded]) {
                [plugin unload];
            }
            Class principalClass = nil;
            principalClass = [plugin principalClass];
            if (principalClass == nil) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get principal class for %@",[url absoluteString]];
                break;
            }
            if ([principalClass isSubclassOfClass:[MLStackLayersList class]]){
                MLStackLayersList* layersList = nil;
                layersList = [[principalClass alloc] init];
                if (layersList != nil) {
                    [allLayers addObjectsFromArray:[layersList layersList]];
                } else {
                    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to instantiate principal class for %@",[url absoluteString]];
                }
                [layersList release];
            } else {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Principal class of %@ is not a subclass of MLStackLayersList",[url absoluteString]];
            }
        }
        [streams sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                           @"pluginsList",@"action",
                           allLayers,@"availablePlugins", nil]];
    } else if ([action isEqualToString:@"setStack"]) {
        if (stack != nil) {
            [stack release];
            stack = nil;
        }
        NSArray* layers = [newData valueForKey:@"stack"];
        if ([layers count] > 0){
            stack = [[MLStack alloc] initWithLayers:layers andAgent:self];
        }
        if (stack == nil) {
            [streams sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                               @"taskUpdate",@"action",
                               [newData valueForKey:@"taskId"],@"taskId",
                               [NSNumber numberWithInt:kMLTaskAgentFailure],@"status",nil]];
        } else {
            [streams sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                               @"taskUpdate",@"action",
                               [newData valueForKey:@"taskId"],@"taskId",
                               [NSNumber numberWithInt:kMLTaskAgentSuccess],@"status",nil]];
        }
    } else if ([action isEqualToString:@"send"]) {
        int repeat = [[newData valueForKey:@"repeat"] intValue];
        if (initSendTimer != nil) {
            [initSendTimer invalidate];
            [initSendTimer release];
            initSendTimer = nil;
        }
        repeatCounter = repeat;
        double pause = [[newData valueForKey:@"pause"] doubleValue];
        initSendTimer = [[NSTimer scheduledTimerWithTimeInterval:pause target:self selector:@selector(initiateSend:) userInfo:newData repeats:YES] retain];
    }
}

/*
 * Sends a message on adhoc interface via adhoc stack
 */
-(void)initiateSend:(NSTimer*)timer {
    NSData* taskData = [timer userInfo];
    MLMessage* msg = [[MLMessage alloc] initWithData:[taskData valueForKey:@"data"] from:[stack hostAddress] to:[taskData valueForKey:@"dataTo"] andTask:[taskData valueForKey:@"taskId"]];
    if (stack == nil) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"SEND ERROR no layer in stack"];
        [self logFor:msg withStatus:kMLTaskAgentFailure event:@"No layers in stack"];
    } else {
        MLSendResult res = [stack send:msg];
        if (res != kMLSendSuccess) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"SEND ERROR in adhoc stack (%@)",MLstringForSendResult(res)];
            [self logFor:msg withStatus:kMLTaskAgentFailure event:MLstringForSendResult(res)];
        }
    }
    repeatCounter--;
    if (repeatCounter == 0) {
        [self logFor:msg withStatus:kMLTaskAgentSuccess event:@"AGENT task %@ send done",[taskData valueForKey:@"taskId"]];
        [initSendTimer invalidate];
        [initSendTimer release];
        initSendTimer = nil;
    }
    [msg release];
}

-(void)logFor:(MLMessage*)msg withStatus:(MLTaskAgentStatus)status event:(NSString*)event, ... {
    va_list args;
    va_start(args, event);
    NSString* res = [[NSString alloc] initWithFormat:event arguments:args];
    [self logToTask:msg.taskId event:res withStatus:status];
    [res release];
    va_end(args);
}

/*
 * Log event (to controller) via control link.
 */
-(void)logToTask:(unsigned int)taskId event:(NSString*)event withStatus:(MLTaskAgentStatus)status {
    if (taskId > lastTask) {
        lastTask = taskId;
        logCounter = 0;
    }
    [streams sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                       @"taskUpdate",@"action",
                       [NSString stringWithFormat:@"%i",taskId],@"taskId",
                       [NSNumber numberWithInt:status],@"status",
                       event,@"event",
                       [NSDate date],@"time",
                       [NSNumber numberWithInt:logCounter++],@"line",nil]];
}

/*
 * Ask MLStack to recreate link between stack and lowest layer (WLAN access).
 * After a loss of connection for example...
 */
-(void)reconnectStack {
    [stack reconnect];
}

/*
 * Streams callback
 */
-(void)onClose {
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Disconnected from ML controller due to connection close"];
    [[ManetLabFramework sharedInstance] goIntoErrorMode];
}

/*
 * Streams callback
 */
-(void)onError {
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Disconnected from ML controller due to error"];
    [[ManetLabFramework sharedInstance] goIntoErrorMode];
}

/*
 * Location manager delegate method
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if (lastLoc != nil) {
        [lastLoc release];
    }
    lastLoc = [newLocation retain];
    NSDictionary* locationData = [NSDictionary dictionaryWithObjectsAndKeys:@"locupdate", @"action", [NSNumber numberWithDouble:lastLoc.coordinate.latitude],@"lat",[NSNumber numberWithDouble:lastLoc.coordinate.longitude],@"long", nil];
    [streams sendData:locationData];
}

/*
 * Location manager delegate method
 */
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Location error: %@",[error localizedDescription]];
}

/*
 * Location manager delegate method
 */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_WARNING andMsg:@"Location authorization changed... CLAuthorizationStatus = %i",status];
}

/*
 * Cleanup
 */
- (void)dealloc {
    [[ManetLabFramework sharedInstance] removeObserver:self forKeyPath:@"state"];
    if (initSendTimer != nil) {
        [initSendTimer invalidate];
        [initSendTimer release];
        initSendTimer = nil;
    }
    if (stack != nil) {
        [stack release];
    }
    if (locManager != nil) {
        [locManager stopUpdatingLocation];
        [locManager setDelegate:nil];
        [locManager release];
    }
    if (lastLoc != nil) {
        [lastLoc release];
    }
    if (wlanSettings != nil) {
        [wlanSettings release];
    }
    [streams release];
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML local agent destroyed"];
    [super dealloc];
}

@end
