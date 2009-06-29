//
//  GHNSURL+Utils.m
//
//  Created by Gabe on 3/19/08.
//  Copyright 2008 Gabriel Handford
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//


#import "GHNSURL+Utils.h"


@implementation NSURL (GHUtils)

- (NSMutableDictionary *)gh_queryDictionary {
	return [NSURL gh_queryStringToDictionary:[self query]];
}

+ (NSString *)gh_dictionaryToQueryString:(NSDictionary *)queryDictionary {
	return [self gh_dictionaryToQueryString:queryDictionary sort:NO];
}

+ (NSArray *)gh_dictionaryToQueryArray:(NSDictionary *)queryDictionary sort:(BOOL)sort encoded:(BOOL)encoded {
  if (!queryDictionary) return nil;
	if ([queryDictionary count] == 0) return [NSArray array];
  
  NSMutableArray *queryStrings = [NSMutableArray arrayWithCapacity:[queryDictionary count]];
	id enumerator = queryDictionary;
	if (sort) enumerator = [[queryDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
	
  for(NSString *key in enumerator) {
    id value = [queryDictionary valueForKey:key];
		NSString *valueDescription = nil;
		if ([value isKindOfClass:[NSArray class]]) {
			valueDescription = [value componentsJoinedByString:@","];
		} else {
			valueDescription = [value description];
		}
		
		NSAssert(valueDescription, @"No value description");
		
		if (encoded) key = [self gh_encodeComponent:key];
		if (encoded) valueDescription = [self gh_encodeComponent:valueDescription];
    [queryStrings addObject:[NSString stringWithFormat:@"%@=%@", key, valueDescription]];
  }
  return queryStrings;
}

+ (NSString *)gh_dictionaryToQueryString:(NSDictionary *)queryDictionary sort:(BOOL)sort {
  return [[self gh_dictionaryToQueryArray:queryDictionary sort:sort encoded:YES] componentsJoinedByString:@"&"];
}

+ (NSMutableDictionary *)gh_queryStringToDictionary:(NSString *)string {
	NSArray *queryItemStrings = [string componentsSeparatedByString:@"&"];
	
	NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionaryWithCapacity:[queryItemStrings count]];
	for(NSString *queryItemString in queryItemStrings) {
		NSRange range = [queryItemString rangeOfString:@"="];
		if (range.location != NSNotFound) {
			NSString *key = [NSURL gh_decode:[queryItemString substringToIndex:range.location]];
			NSString *value = [NSURL gh_decode:[queryItemString substringFromIndex:range.location + 1]];
			[queryDictionary setObject:value forKey:key];
		}
	}
	return queryDictionary;
}

- (NSString *)gh_sortedQuery {
	return [NSURL gh_dictionaryToQueryString:[self gh_queryDictionary] sort:YES];
}

- (NSURL *)gh_deriveWithQuery:(NSString *)query {
	NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://", [self scheme]];
	if ([self user] && [self password]) [urlString appendFormat:@"%@:%@@", [self user], [self password]];
	[urlString appendString:[self host]];
	if ([self port]) [urlString appendFormat:@":%d", [[self port] integerValue]];
	[urlString appendString:[self path]];
	if (query) [urlString appendFormat:@"?%@", query];
	if ([self fragment]) [urlString appendFormat:@"#%@", [self fragment]];	
	return [NSURL URLWithString:urlString];
}

- (NSURL *)gh_canonical {
	return [self gh_canonicalWithIgnore:nil];
}

- (NSURL *)gh_canonicalWithIgnore:(NSArray *)ignore {
	NSString *query = nil;
	if ([self query]) {
		NSMutableDictionary *queryParams = [self gh_queryDictionary];
		for(NSString *key in ignore) [queryParams removeObjectForKey:key];
		query = [NSURL gh_dictionaryToQueryString:queryParams sort:YES];
	}
	
	return [self gh_deriveWithQuery:query];
}

+ (NSString *)gh_encode:(NSString *)s {	
	// Characters to maybe leave unescaped? CFSTR("~!@#$&*()=:/,;?+'")
	return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)s, CFSTR("#"), CFSTR("%^{}[]\"\\"), kCFStringEncodingUTF8) autorelease];
}

+ (NSString *)gh_encodeComponent:(NSString *)s {  
	// Characters to maybe leave unescaped? CFSTR("~!*()'")
  return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)s, NULL, CFSTR("@#$%^&{}[]=:/,;?+\"\\"), kCFStringEncodingUTF8) autorelease];
}

+ (NSString *)gh_escapeAll:(NSString *)s {
	// Characters to escape: @#$%^&{}[]=:/,;?+"\~!*()'
  return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)s, NULL, CFSTR("@#$%^&{}[]=:/,;?+\"\\~!*()'"), kCFStringEncodingUTF8) autorelease];	
}

+ (NSString *)gh_decode:(NSString *)s {
	if (!s) return nil;
	return [(NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)s, CFSTR("")) autorelease];
}

#ifndef TARGET_OS_IPHONE

- (void)gh_copyLinkToPasteboard {  
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil] owner:self];
  [self writeToPasteboard:pasteboard]; // For NSURLPBoardType
  [pasteboard setString:[self absoluteString] forType:NSStringPboardType];
}

+ (BOOL)gh_openFile:(NSString *)path {
  NSString *fileURL = [NSString stringWithFormat:@"file://%@", [self gh_encode:path]];
  NSURL *url = [NSURL URLWithString:fileURL];
  return [[NSWorkspace sharedWorkspace] openURL:url];
}

+ (void)gh_openContainingFolder:(NSString *)path {
  BOOL isDir;
  if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir)
    [self gh_openFile:path];
  else
    [self gh_openFile:[path stringByDeletingLastPathComponent]];
}

#endif

@end
