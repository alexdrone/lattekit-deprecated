//
//  LTParser.m
//  Latte
//
//  Created by Alex Usbergo on 5/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "LTPrefixes.h"

@interface LTParser ()

//caches the tree structure
@property (strong) NSCache *cache;

@end

@implementation LTParser

#pragma mark Singleton initialization code

+ (LTParser*)sharedInstance
{
    static dispatch_once_t pred;
    static LTParser *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[LTParser alloc] init];
    });
    
    return shared;
}

- (id)init
{
    if (self = [super init]) {
        _cache = [[NSCache alloc] init];
        _sharedStyleSheetCache = [[NSMutableDictionary alloc] init];
        _useJSONMarkup = YES;
    }        
    
    return self;
}

#pragma mark Cache

/* Replaces the current caches for a given key */
- (void)replaceCacheForFile:(NSString*)key withNode:(LTNode*)node
{
    NSLog(@"Cache: Replacing key - %@", key);
    [self.cache setObject:node forKey:key];
}

- (LTNode*)parseFile:(NSString*)filename;
{
    LTNode *node;
    if ((node = [self.cache objectForKey:filename]))
        return node;
    
    NSError *error = nil;
    
    NSString *extension = self.useJSONMarkup ? @"json" : @"latte";
    NSString *input = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:filename ofType:extension]
												encoding:NSUTF8StringEncoding 
												   error:&error];
    if (!error) {
        node = [self parseMarkup:input];
        
        if (DEBUG)
            NSLog(@"Cache: Recreating key for %@", filename);
        
        [self.cache setObject:node forKey:filename];
        return node;  
    }
    
    else return nil;
}

#pragma mark Parsing

/* Create the tree structure from a given legal .lt markup */
- (LTNode*)parseMarkup:(NSString*)markup
{
    LTNode *result;
    
    if (self.useJSONMarkup)
        result = [self parseJSONMarkup:markup];
    else
        result = [self parseLatteMarkup:markup];
	    
    return result;
}

#pragma mark JSON

- (LTNode*)parseJSONMarkup:(NSString*)markup
{
	//Due to compatibility with the latte format,
	//the given JSON markup support also comments in the form of
	//-#comment
	NSMutableString *cleaned = [[NSMutableString alloc] init];
	for (NSString *l in [markup componentsSeparatedByString:@"\n"]) {
		
		//removes all the whitespaces
		NSString *trimmed = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		//skip all the comments
		if (![trimmed hasPrefix:@"-#"])
			[cleaned appendString:trimmed];
	}
	
	markup = cleaned;
	
    NSMutableDictionary *json = [markup mutableObjectFromJSONString];
    LTNode *rootNode = [[LTNode alloc] init];

    for (NSMutableDictionary *jsonRootNode in json[@"layout"]) {
        
        //the child node is initialized a recursively created
        LTNode *node = [[LTNode alloc] init];
        LTJSONCreateTreeStructure (jsonRootNode, node);
        
        //set the father of the node
        node.father = rootNode;
        [rootNode.children addObject:node];
    }
	
	//set the autolayout constraints if defined
	rootNode.constraints = json[@"constraints"];

    return rootNode;
}

/* Recursively create the node structure from the JSON file */
void LTJSONCreateTreeStructure(NSMutableDictionary *jsonNode, LTNode *node)
{
    NSArray *subiews = jsonNode[@"subviews"];
    [jsonNode removeObjectForKey:@"subviews"];
    
    node.data = jsonNode;
    
    for (NSMutableDictionary *jsonChildNode in subiews) {
        
        //the child node is initialized a recursively created
        LTNode *childNode = [[LTNode alloc] init];
        LTJSONCreateTreeStructure(jsonChildNode, childNode);
        
        //set the father of the node
        childNode.father = node;
        [node.children addObject:childNode];
    }
}


#pragma mark Latte markup

/* Create the tree structure from a given legal .lt markup */
- (LTNode*)parseLatteMarkup:(NSString*)markup
{
    NSArray *markups = [markup componentsSeparatedByString:@"@end"];
    NSUInteger idx = 0;
    
    if (markups.count > 1)
        [self parseStylesheet:markups[idx++]];
    
    markup = markups[idx];
    
    //nodes
    LTNode *rootNode, *currentNode, *fatherNode;
    rootNode = currentNode = [[LTNode alloc] init];
    fatherNode = nil;
    
    //syntax elements counters;
    NSInteger tabc = 0, tabo = -1;
    
    for (NSString *l in [markup componentsSeparatedByString:@"\n"]) {
        
        //skip all the empty lines and the comments
		NSString *trimmed = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([trimmed isEqualToString:@""] || [trimmed hasPrefix:@"-#"] || [trimmed hasPrefix:@"@layout"]) continue;
        
        //tab counts
        tabc = 0;
		for (int i = 0; i < l.length; i++)
            if ([l characterAtIndex:i] == '\t') tabc++;
			else break;
        
        //invalid indentation
		if (tabc >  tabo + 1) goto parse_err;
		
		//nested element
		if (tabc == tabo + 1)
            fatherNode = currentNode;
		
		if (tabc < tabo)
			for (NSInteger i = 0; i < tabo-tabc; i++)
				fatherNode = fatherNode.father;
        
		tabo = tabc;
        
        //text can be put as nested element
		if (![trimmed hasPrefix:@"%"]) {
            NSString *text = [NSString stringWithFormat:@"%@\n%@", fatherNode.data[@"text"], l];
            fatherNode.data[@"text"] = text;
            
            continue;
        }
        
        //update the nodes hierarchy
        currentNode = [[LTNode alloc] init];
        currentNode.father = fatherNode;
        
        if (fatherNode) [fatherNode.children addObject:currentNode];
        
        //node content
		NSError *error = nil;
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"%([a-zA-z0-9]*)(\.[a-zA-z0-9]*)(\#[a-zA-z0-9]*)*\\{(.*)\\}"
																			   options:NSRegularExpressionCaseInsensitive
																				 error:&error];
        if (error) goto parse_err;
        
        //iterating all the matches for the current line
        for (NSTextCheckingResult *match in [regex matchesInString:l options:0 range:NSMakeRange(0, l.length)]) {
            
            NSString *latteIsa = [l substringWithRange:[match rangeAtIndex:1]];
            
			NSUInteger index = 2;
			NSString *latteClass = nil;
			if (match.numberOfRanges > index &&  [[l substringWithRange:[match rangeAtIndex:index]] hasPrefix:@"."])
				latteClass = [l substringWithRange:[match rangeAtIndex:index++]];
			
			NSString *latteId = nil;
			if (match.numberOfRanges > index &&  [[l substringWithRange:[match rangeAtIndex:index]] hasPrefix:@"#"])
				latteId = [l substringWithRange:[match rangeAtIndex:index++]];
			
			NSString *json = nil;
			if (match.numberOfRanges > index)
				json = [l substringWithRange:[match rangeAtIndex:index]];
            
            NSMutableDictionary *data = [NSMutableDictionary dictionary];
            
            
            //get the values from the stylesheet
            [data addEntriesFromDictionary:self.sharedStyleSheetCache[latteClass]];
            [data addEntriesFromDictionary:self.sharedStyleSheetCache[[NSString stringWithFormat:@"%@%@", latteClass, latteId]]];
            
            //and the values defined in the layout
            [data addEntriesFromDictionary:[[NSString stringWithFormat:@"{%@}",json] mutableObjectFromJSONString]];
            
            currentNode.data = data;
            
            if (nil != latteClass)
                currentNode.data[@"LT_class"] = latteClass;
            
			if (nil != latteId)
                currentNode.data[@"LT_id"] = latteId;
            
            if (nil != latteIsa)
                currentNode.data[@"LT_isa"] = latteIsa;
            
            else goto parse_err;
        }
    }
    
    return rootNode;
    
    //something went wrong
parse_err:
    NSLog(@"The markup is not latte compliant.");
    return nil;
}

/* Parses the style section of the markup and initilizes LTStylesheet */
- (void)parseStylesheet:(NSString*)markup
{
    //clear the cache
    [self.sharedStyleSheetCache removeAllObjects];
    
    @try {
        for (NSString *l in [markup componentsSeparatedByString:@"\n"]) {
            
            //skip all the empty lines and the comments
            NSString *trimmed = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed isEqualToString:@""] || [trimmed hasPrefix:@"-#"] || [trimmed hasPrefix:@"@style"]) continue;
            
            NSArray *comps = [trimmed componentsSeparatedByString:@"{"];
            
            NSString *selector = comps[0];
            NSDictionary *values = [[NSString stringWithFormat:@"{%@", [comps lastObject]] mutableObjectFromJSONString];
            
            self.sharedStyleSheetCache[selector] = values;
        }
    }
    
    @catch (NSException *exception) {
        NSLog(@"Corrupted stylesheet data");
    }
}

#pragma mark Helper functions

/* Returns the possible condition value associated to the given string */
BOOL LTGetContextConditionFromString(LTContextValueTemplate **contextCondition, NSString* source)
{
    LTContextValueTemplate *obj = [LTContextValueTemplate createFromString:source];
    
    if (nil != obj) 
        (*contextCondition) = obj;
    else 
        (*contextCondition) = nil;
    
    return (nil != (*contextCondition));
}

/* Returns all the associated keypaths and a formatted (printable) string 
 * from a given source string with the format 
 * "This is a template #{obj.keypath} for #{otherkeypath}.." */
BOOL LTGetKeypathsAndTemplateFromString(NSArray **keypaths, NSString **template, NSString *source)
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"#\\{([a-zA-Z0-9\\.\\@\\(\\)\\_]*)\\}"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    
    NSArray *matches = [regex matchesInString:source options:0 range:NSMakeRange(0, source.length)];
    if (!matches.count) return NO;
    
    *keypaths = [NSMutableArray array];
    
    //iterating all the matches for the current line
    for (NSTextCheckingResult *match in matches)
        [(NSMutableArray*)*keypaths addObject:[source substringWithRange:[match rangeAtIndex:1]]];
    
    *template = [NSMutableString stringWithString:source];
    
    for (NSString *keypath in *keypaths)
        [(NSMutableString*)*template replaceOccurrencesOfString:[NSString stringWithFormat:@"#{%@}", keypath] 
                                                     withString:@"%@" 
                                                        options:NSLiteralSearch 
                                                          range:NSMakeRange(0, (*template).length)];
    
    return YES;
}


@end
