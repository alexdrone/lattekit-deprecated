//
//  NSWindow+CanBecomeWindowKey.m
//  Latte
//
//  Created by Alex Usbergo on 7/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSWindow+CanBecomeWindowKey.h"

@implementation NSWindow (CanBecomeWindowKey)

//This is to fix a bug with 10.7 where an NSPopover with a text field cannot be edited if its parent window won't become key
//The pragma statements disable the corresponding warning for overriding an already-implemented method
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
- (BOOL)canBecomeKeyWindow
{
    return YES;
}
#pragma clang diagnostic pop


@end
