//
//  MLUNIXConnection.m
//  mllauncherd
//
//  Created by Francois Vessaz on 12/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#import "ManetLabFramework+Internal.h"
#import "MLUNIXSocketServer.h"

@interface MLUNIXSocketServer(){
    
    int socketFD;                           // socket file descriptor
    CFSocketRef socketCF;                   // main listener socket
    id<MLUNIXSocketServerDelegate> delegate;// delegate to notify
    NSURL* path;                            // UNIX socket path
    MLStreamsUtility* streams;              // streams from/to connection (only 1)
    
}

-(void)setStreams:(MLStreamsUtility*)newStreams;

void newUNIXConnectionCallback (CFSocketRef s,CFSocketCallBackType callbackType,CFDataRef address,const void *data,void *info);
    
@end

@implementation MLUNIXSocketServer

/*
 * init method
 */
-(id)initWithPath:(NSString*)aPath andDelegate:(id<MLUNIXSocketServerDelegate>)del {
    if (del == nil) {
        return nil;
    }
    delegate = del;
    path = [[NSURL URLWithString:aPath] retain];
    streams = nil;
    
    // Open UNIX socket to communicate with pref pane 
    struct sockaddr_un bindReq;      // Bind request for pref socket
    int err;                         // detailed UNIX error
    
    socketFD = -1;
    socketFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (socketFD < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create FD for UNIX socket %@ (socket error %i)",path,errno];
        return nil;
    }
    err = mkdir([[[path URLByDeletingLastPathComponent] absoluteString] UTF8String], 0755);
    if (err != 0 && errno != EEXIST){
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create parent folder for UNIX socket %@ (mkdir error %i)",path,errno];
        return nil;
    }
    // chmod 777 for our pref socket
    mode_t oldUmask = umask(0);
    // if it was not cleaned...
    (void) unlink([[path absoluteString] UTF8String]);
    bindReq.sun_len    = sizeof(bindReq);
    bindReq.sun_family = AF_UNIX;
    strcpy(bindReq.sun_path, [[path absoluteString] UTF8String]);
    err = bind(socketFD, (struct sockaddr *) &bindReq, (socklen_t)SUN_LEN(&bindReq));
    if (err < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to bind UNIX socket %@ (bind error %i)",path,errno];
        return nil;
    }
    (void) umask(oldUmask);
    err = listen(socketFD, 1);
    if (err < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to listen UNIX socket %@ (listen error %i)",path,errno];
        return nil;
    }
    socketCF = NULL;
    CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
    socketCF = CFSocketCreateWithNative(NULL,(CFSocketNativeHandle) socketFD,kCFSocketAcceptCallBack,newUNIXConnectionCallback,&socketCtxt);
    if (socketCF == NULL) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create CFSocketRef for UNIX socket %@",path];
        return nil;
    }
    
    // Schedule the listening socket on our runloop.
    CFRunLoopSourceRef  rls;
    rls = CFSocketCreateRunLoopSource(NULL, socketCF, 0);
    if (rls == NULL) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to create runloop source for UNIX socket %@",path];
        return nil;
    } else {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        CFRelease(rls);
    }
    
    return self;
}

/*
 * Incoming connection from UNIX socket
 */
void newUNIXConnectionCallback (CFSocketRef s,CFSocketCallBackType callbackType,CFDataRef address,const void *data,void *info)
{
    if (callbackType == kCFSocketAcceptCallBack){
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        MLUNIXSocketServer* unixSocketServer = (MLUNIXSocketServer*)info;
        int sockFD = (*(int *) data);
        if (sockFD == -1) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Invalid socket file descriptor for new connection on UNIX socket"];
            return;
        }
        // Set the file descriptor non blocking
        int flags = fcntl(sockFD, F_GETFL, NULL);
        int err = fcntl(sockFD, F_SETFL, flags | O_NONBLOCK);
        if (err == -1) {
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to set non blocking FD for new connection on UNIX socket (fcntl error %i)",errno];
            return;
        }
        
        CFReadStreamRef streamIn = nil;
        CFWriteStreamRef streamOut = nil;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, sockFD, &streamIn, &streamOut);
        if (streamIn && streamOut) {
            CFReadStreamSetProperty((CFReadStreamRef)streamIn, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty((CFWriteStreamRef)streamOut, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            MLStreamsUtility* util = [[MLStreamsUtility alloc] initWithInputStream:(NSInputStream*)streamIn andOutputStream:(NSOutputStream*)streamOut delegate:unixSocketServer];
            [unixSocketServer setStreams:util];
            [util release];
            CFRelease(streamIn);
            CFRelease(streamOut);
        }
        [pool release];
    }
}

/*
 * Set streams object when connection is established and accepted.
 */
-(void)setStreams:(MLStreamsUtility*)newStreams {
    if (streams == nil) {
        streams = [newStreams retain];
    } else {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Connection on UNIX socket %@ not accepted: only one is allowed.",[path description]];
    }
}

/*
 * New data
 */
-(void)onData:(NSDictionary*)newData {
    [delegate onData:newData];
}

/*
 * Connection closed by remote process
 */
-(void)onClose {
    [streams release];
    streams = nil;
    [delegate onClose];
}

/*
 * On streams error.
 */
-(void)onError {
    [streams release];
    streams = nil;
    [delegate onClose];
}

/*
 * send data to client
 */
-(BOOL)sendData:(NSDictionary*)newData {
    if (streams != nil) {
        [streams sendData:newData];
        return YES;
    }
    return NO;
}

/*
 * close current connection
 */
-(void)close {
    [streams close];
    [streams release];
    streams = nil;
}

/*
 * cleanup
 */
- (void)dealloc {
    if (streams != nil) {
        [streams release];
    }
    if (socketCF != NULL) {
        CFSocketInvalidate(socketCF);
        CFRelease(socketCF);
    }
    if ( (socketFD != -1) && (socketCF == NULL) ) {
        close(socketFD);
    }
    (void) unlink([[path absoluteString] UTF8String]);
    [path release];
    
    [super dealloc];
}

@end
