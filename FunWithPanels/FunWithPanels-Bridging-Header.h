//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NSWindow (Private)
- (void )_setPreventsActivation:(bool)preventsActivation;
@end
