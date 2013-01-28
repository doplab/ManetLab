//
//  MLNetworkController.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <dns_sd.h>

#import "MLController.h"
#import "MLAgentProxy.h"
#import "ManetLabFramework+Internal.h"
#import "MLUNIXSocketServer.h"
#import "MLTask.h"
#import <SystemConfiguration/SystemConfiguration.h>

#define CONTROLLER_PORT 7777
#define CONTROLLER_SERVICE "_manetlab._tcp"
#define APP_ID "ch.unil.doplab.mlcontrol"
#define SOCKET_PATH @"/var/tmp/ch.unil.doplab.manetlab/guisocket"

@interface MLController() <MLUNIXSocketServerDelegate>
{
    
    CFSocketRef mainListener;               // Socket of ML network controller on control interface
    DNSServiceRef mlService;                // Bonjour reference of the service
    NSMutableSet* connections;              // Connections to controller from MLAgent
    NSString* interface;                    // Interface used by server
    BOOL waitForIp;                         // flag YES if no ip on control interface
    SCDynamicStoreRef store;                // system config store
    MLUNIXSocketServer* guiSocket;          // UNIX socket with GUI
    NSMutableDictionary* tasksList;         // list of tasks
    NSString* activeTask;                   // current task selected in GUI that needs an active refresh
    NSMutableDictionary* availableLayers;   // list of available layers for set stack
    
}

-(BOOL)initTCPserver;
-(NSArray*)sslCertificatesArray;
-(void)checkConfigCallback:(NSArray*)keys;
-(BOOL)initUNIXsocket;
-(void)sendDictionnary:(NSDictionary*)dict toAgents:(NSArray*)agents;
-(void)sendTasksList;
-(void)sendTaskDetails:(NSString*)taskId;
-(void)addConnection:(MLAgentProxy*)newAgent;

void newConnectionCallback(CFSocketRef s,CFSocketCallBackType callbackType,CFDataRef address,const void *data,void *info);
void systemConfigCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info);

@end

@implementation MLController

/*
 * Init ML network controller on a given interface
 */
-(id)initWithInterface:(NSString*)anInterface {
    self = [super init];
    if (self) {
        
        // Init connections (MLAgentProxy) set
        connections = [[NSMutableSet set] retain];
        interface = [anInterface retain];
        waitForIp = YES;
        guiSocket = nil;
        tasksList = [[NSMutableDictionary dictionary] retain];
        activeTask = nil;
        availableLayers = nil;
        
        // Monitor system configuration of control interface
        SCDynamicStoreContext ctx = {0, self, NULL, NULL, NULL};
        store = SCDynamicStoreCreate(NULL, CFSTR(APP_ID), systemConfigCallback, &ctx);
        NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",interface];
        if (SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef)[NSArray arrayWithObject:pattern])){
            CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
            if (rls == NULL) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create runloop source for Dynamic Store keys to monitor"];
                return nil;
            } else {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
                CFRelease(rls);
            }
        } else {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to register control interface Dynamic Store key to monitor"];
            return nil;
        }
        if (![self initTCPserver]){
            return nil;
        }
        if (![self initUNIXsocket]) {
            return nil;
        }
    }
    return self;
}

/*
 * Init a new TCP server on a specific port on control interface
 */
-(BOOL)initTCPserver {
    if (waitForIp) {
        // Check if IP is available for control interface
        NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",interface];
        NSDictionary* ipConfig = SCDynamicStoreCopyValue(store, (CFStringRef)pattern);
        NSArray* ips = [ipConfig valueForKey:@"Addresses"];
        if ([ips count] > 0) {
            waitForIp = NO;
            NSString* ip = [ips objectAtIndex:0];
            
            // Create TCP server socket on control interface
            CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
            mainListener = NULL;
            mainListener = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, newConnectionCallback, &socketCtxt);
            if (mainListener== NULL) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ML controller unable to create socket"];
                [ipConfig release];
                return NO;
            }
            int yes = 1;
            setsockopt(CFSocketGetNative(mainListener), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
            
            // Bind socket to contol interface IPv4 address
            struct sockaddr_in addr4;
            memset(&addr4, 0, sizeof(addr4));
            addr4.sin_len = sizeof(addr4);
            addr4.sin_family = AF_INET;
            addr4.sin_addr.s_addr = inet_addr([ip UTF8String]);
            addr4.sin_port = htons(CONTROLLER_PORT);
            NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
            if (kCFSocketSuccess != CFSocketSetAddress(mainListener, (CFDataRef)address4)) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ML controller unable to set socket address"];
                [ipConfig release];
                return NO;
            }
            
            // Add socket to run loop
            CFRunLoopSourceRef rls = NULL;
            rls = CFSocketCreateRunLoopSource(NULL, mainListener, 0);
            if (rls == NULL) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ML controller unable to create socket RLS"];
                CFSocketInvalidate(mainListener);
                CFRelease(mainListener);
                [ipConfig release];
                return NO;
            }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
            CFRelease(rls);
            
            // Register service in Bonjour
            if (DNSServiceRegister(&mlService, 0, if_nametoindex([interface UTF8String]), NULL, CONTROLLER_SERVICE, NULL, NULL, htons(CONTROLLER_PORT), 0, NULL, NULL, NULL) != kDNSServiceErr_NoError){
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ML controller unable to register service in Bonjour"];
                CFSocketInvalidate(mainListener);
                CFRelease(mainListener);
                [ipConfig release];
                return NO;
            }
            
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML local network controller initialized on %@",interface];
            [[ManetLabFramework sharedInstance] connectController];
        } else {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Waiting for IP address on control interface."];
        }
        [ipConfig release];
    }
    return YES;
}

/*
 * Init UNIX socket with controller GUI.
 */
-(BOOL)initUNIXsocket {
    guiSocket = [[MLUNIXSocketServer alloc] initWithPath:SOCKET_PATH andDelegate:self];
    return (guiSocket != nil);
}

/*
 * UNIX socket (GUI) callback
 */
-(void)onData:(NSDictionary*)newData {
    NSString* command = [newData valueForKey:@"action"];
    if ([command isEqualToString:@"checkin"]) {
        [self agentsList];
        [self sendTasksList];
    } else if ([command isEqualToString:@"newTask"]) {
        MLTask* newTask = [[MLTask alloc] initWithDictionnary:newData];
        [tasksList setValue:newTask forKey:newTask.taskId];
        [self sendTasksList];
        
        NSMutableDictionary* newDataMutable = [newData mutableCopy];
        [newDataMutable setValue:newTask.taskLabel forKey:@"action"];
        [newDataMutable setValue:newTask.taskId forKey:@"taskId"];
        [self sendDictionnary:newDataMutable toAgents:[newData valueForKey:@"toAgents"]];
        
        [newDataMutable release];
        [newTask release];
    } else if ([command isEqualToString:@"tasksList"]) {
        [self sendTasksList];
    } else if ([command isEqualToString:@"taskDetails"]) {
        activeTask = [newData valueForKey:@"taskId"];
        [self sendTaskDetails:activeTask];
    } else if ([command isEqualToString:@"getLayersList"]) {
        if (availableLayers != nil) {
            [availableLayers release];
        }
        availableLayers = [[NSMutableDictionary dictionary] retain];
        for (NSString* agentName in [newData valueForKey:@"toAgents"]) {
            [availableLayers setValue:[NSNull null] forKey:agentName];
        }
        [self sendDictionnary:newData toAgents:[newData valueForKey:@"toAgents"]];
    } else if ([command isEqualToString:@"getTaskLog"]) {
        MLTask* taskToLog = [tasksList valueForKey:[newData valueForKey:@"taskId"]];
        [guiSocket sendData:[NSDictionary dictionaryWithObjectsAndKeys:@"taskLog",@"action",
                                                                        [taskToLog getLog],@"log",
                                                                        [newData valueForKey:@"taskId"],@"taskId",nil]];
    } else {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unknow command '%@'",command];
    }
}

/*
 * Send a dictionnary to selected agents
 */
-(void)sendDictionnary:(NSDictionary*)dict toAgents:(NSArray*)agents {
    for (MLAgentProxy* agent in connections) {
        if ([agents containsObject:agent.agentName]) {
            [NSThread detachNewThreadSelector:@selector(sendData:) toTarget:agent withObject:dict];
        }
    }
}

/*
 * Update agent list of available layers.
 */
-(void)announceLayers:(NSArray*)layersList forAgent:(NSString*)agentName {
    [availableLayers setValue:layersList forKey:agentName];
    if (![[availableLayers allValues] containsObject:[NSNull null]]) {
        NSMutableArray* commonLayers = nil;
        for (NSString* agentName in availableLayers) {
            NSArray* agentLayers = [availableLayers valueForKey:agentName];
            if (commonLayers == nil) {
                commonLayers = [agentLayers mutableCopy];
            } else {
                NSMutableArray* toRemove = [NSMutableArray array];
                for (NSString* layerName in commonLayers) {
                    if (![agentLayers containsObject:layerName] && ![toRemove containsObject:layerName]) {
                        [toRemove addObject:layerName];
                    }
                }
                [commonLayers removeObjectsInArray:toRemove];
            }
        }
        [guiSocket sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                             @"commonLayersList",@"action",
                             commonLayers,@"layersList", nil]];
        [commonLayers release];
    }
}

/*
 * Updates an agent status for a task
 */
-(void)updateTask:(NSString*)aTask ofAgent:(NSString*)anAgent toState:(MLTaskAgentStatus)aState withEvent:(NSString*)event at:(NSDate*)time line:(int)line {
    MLTask* task = [tasksList valueForKey:aTask];
    [task updateStatusForAgent:anAgent toStatus:aState withEvent:event at:time line:line];
    [self sendTaskDetails:aTask];
}

/*
 * Send the list of active tasks to GUI
 */
-(void)sendTasksList {
    NSMutableDictionary* tasksIDandName = [NSMutableDictionary dictionary];
    for (NSString* taskId in tasksList) {
        MLTask* task = [tasksList valueForKey:taskId];
        [tasksIDandName setValue:task.taskLabel forKey:taskId];
    }
    NSDictionary* res = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"tasksList",@"action",
                         tasksIDandName,@"tasksList", nil];
    [guiSocket sendData:res];
}

/*
 * Send tasks details to GUI if action is selected.
 */
-(void)sendTaskDetails:(NSString*)taskId {
    if ([activeTask isEqualToString:taskId]) {
        MLTask* task = [tasksList valueForKey:taskId];
        [guiSocket sendData:[task getTaskDetails]];
    }
}

/*
 * refresh agents list and send it to the GUI
 */
-(void)agentsList {
    NSMutableArray* agents = [NSMutableArray array];
    for (MLAgentProxy* agent in connections) {
        NSArray* agentInfos = [NSArray arrayWithObjects:agent.agentName,agent.agentAddress,agent.agentLat,agent.agentLong,agent.agentState,nil];
        [agents addObject:agentInfos];
    }
    NSDictionary* answer = [NSDictionary dictionaryWithObjectsAndKeys:@"agents",@"action",agents,@"agentsList", nil];
    [guiSocket sendData:answer];
}

/*
 * UNIX socket (GUI) callback
 */
-(void)onClose {
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Controller GUI app closes connection."];
}

/*
 * Handle new connections to ML network controller, open streams with client.
 */
void newConnectionCallback(CFSocketRef s,CFSocketCallBackType callbackType,CFDataRef address,const void *data,void *info) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    MLController *server = (MLController *)info;
    if (kCFSocketAcceptCallBack == callbackType) {
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        NSInputStream* streamIn = nil;
        NSOutputStream* streamOut = nil;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, (CFReadStreamRef*)&streamIn, (CFWriteStreamRef*)&streamOut);
        if (streamIn && streamOut) {
            CFReadStreamSetProperty((CFReadStreamRef)streamIn, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty((CFWriteStreamRef)streamOut, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            // SSL settings
            NSArray* certs = [server sslCertificatesArray];
            NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      [NSNumber numberWithBool:YES], kCFStreamSSLIsServer,
                                      certs, kCFStreamSSLCertificates,
                                      kCFNull,kCFStreamSSLPeerName,
                                      kCFStreamSocketSecurityLevelTLSv1, kCFStreamSSLLevel,
                                      nil];
            CFReadStreamSetProperty((CFReadStreamRef)streamIn, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
            CFWriteStreamSetProperty((CFWriteStreamRef)streamOut, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
            [settings release];
            struct sockaddr_in* addr = (struct sockaddr_in*) CFDataGetBytePtr(address);
            NSString* addrString = [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)];
            MLAgentProxy* proxy = [[MLAgentProxy alloc] initWithInputStream:streamIn andOutputStream:streamOut address:addrString server:server];
            [server addConnection:proxy];
            [proxy release];
        }
    }
    [pool release];
}

/*
 * System configuration callback when IP change on control interface
 */
-(void)checkConfigCallback:(NSArray*)keys {
    NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",interface];
    if ([keys containsObject:pattern] && waitForIp) {
        if (![self initTCPserver]){
            [[ManetLabFramework sharedInstance] goIntoErrorMode];
        }
    } else if ([keys containsObject:pattern] && !waitForIp) {
        NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",interface];
        NSDictionary* ipConfig = SCDynamicStoreCopyValue(store, (CFStringRef)pattern);
        NSArray* ips = [ipConfig valueForKey:@"Addresses"];
        if ([ips count] == 0) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Control link lost. No more IP address."];
            [[ManetLabFramework sharedInstance] goIntoErrorMode];
        }
        [ipConfig release];
    }
}

/*
 * Add a new valid connection
 */
-(void)addConnection:(MLAgentProxy*)newAgent {
    [connections addObject:newAgent];
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"New connection (%lu) from agent %@",[connections count],newAgent.agentAddress];
    [self agentsList];
}

/*
 * Remove a connection
 */
-(void)closeConnection:(MLAgentProxy*)agentToClose {
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Connection (%lu) closed from agent %@ (%@)",[connections count],agentToClose.agentName,agentToClose.agentAddress];
    [connections removeObject:agentToClose];
    [self agentsList];
}

/*
 * Returns certificate to use for SSL connection.
 */
-(NSArray*)sslCertificatesArray {
    NSArray* sslCertificatesArray = nil;
    if(!sslCertificatesArray) {
        OSStatus err = noErr;
        // Use the system identity
        SecIdentityRef systemIdentity = NULL;	 
        err = SecIdentityCopySystemIdentity(kSecIdentityDomainDefault, &systemIdentity, NULL);	 
        if(err != noErr) {	 
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get system identity certificates"];
        }
        sslCertificatesArray = [NSArray arrayWithObject:(id)systemIdentity];	 
        CFMakeCollectable(systemIdentity);
    }
    return sslCertificatesArray;
}

/*
 * Disconnect all agents and stop server
 */
-(void)stopServer {
    SCDynamicStoreSetNotificationKeys(store,NULL,NULL);
    CFSocketInvalidate(mainListener);
    for (MLAgentProxy* agent in connections) {
        [agent disconnect];
    }
    [connections removeAllObjects];
    DNSServiceRefDeallocate(mlService);
    [guiSocket release];
    guiSocket = nil;
}

/*
 * Cleanup
 */
- (void)dealloc {
    if (guiSocket != nil) {
        [guiSocket release];
        guiSocket = nil;
    }
    if (availableLayers != nil) {
        [availableLayers release];
    }
    CFRelease(store);
    [connections release];
    [interface release];
    if (mainListener != NULL) {
        CFSocketInvalidate(mainListener);
        CFRelease(mainListener);
    }
    if (mlService != NULL) {
        DNSServiceRefDeallocate(mlService);
    }
    [tasksList release];
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML main network controller destroyed"];
    [super dealloc];
}

/*
 * Callback from system configuration framework when properties are changed.
 */
void systemConfigCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [(MLController*)info checkConfigCallback:(NSArray*)changedKeys];
    [pool release];
}

@end
