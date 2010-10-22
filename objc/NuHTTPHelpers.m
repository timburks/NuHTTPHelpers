/*!
@file NuHTTPHelpers.m
@discussion General utilities for the HTTP servers and clients. Relies on OpenSSL libcrypto.
@copyright Copyright (c) 2009 Neon Design Technology, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#import "NuHTTPHelpers.h"

#import <wctype.h>

#import <openssl/md5.h>
#import <openssl/sha.h>
#import <openssl/hmac.h>
#import <openssl/evp.h>
#import <openssl/bio.h>
#import <openssl/buffer.h>

static unichar char_to_int(unichar c)
{
    switch (c) {
        case '0': return 0;
        case '1': return 1;
        case '2': return 2;
        case '3': return 3;
        case '4': return 4;
        case '5': return 5;
        case '6': return 6;
        case '7': return 7;
        case '8': return 8;
        case '9': return 9;
        case 'A': case 'a': return 10;
        case 'B': case 'b': return 11;
        case 'C': case 'c': return 12;
        case 'D': case 'd': return 13;
        case 'E': case 'e': return 14;
        case 'F': case 'f': return 15;
    }
    return 0;                                     // not good
}

static char int_to_char[] = "0123456789ABCDEF";

@implementation NSString (NuHTTPHelpers)

// Daniel Dickison
// http://stackoverflow.com/questions/1105169/html-character-decoding-in-objective-c-cocoa-touch
- (NSString *)stringByDecodingXMLEntities
{
    NSUInteger myLength = [self length];
    NSUInteger ampIndex = [self rangeOfString:@"&" options:NSLiteralSearch].location;

    // Short-circuit if there are no ampersands.
    if (ampIndex == NSNotFound) {
        return self;
    }
    // Make result string with some extra capacity.
    NSMutableString *result = [NSMutableString stringWithCapacity:(myLength * 1.25)];

    // First iteration doesn't need to scan to & since we did that already, but for code simplicity's sake we'll do it again with the scanner.
    NSScanner *scanner = [NSScanner scannerWithString:self];
    do {
        // Scan up to the next entity or the end of the string.
        NSString *nonEntityString;
        if ([scanner scanUpToString:@"&" intoString:&nonEntityString]) {
            [result appendString:nonEntityString];
        }
        if ([scanner isAtEnd]) {
            goto finish;
        }
        // Scan either a HTML or numeric character entity reference.
        if ([scanner scanString:@"&amp;" intoString:NULL])
            [result appendString:@"&"];
        else if ([scanner scanString:@"&apos;" intoString:NULL])
            [result appendString:@"'"];
        else if ([scanner scanString:@"&quot;" intoString:NULL])
            [result appendString:@"\""];
        else if ([scanner scanString:@"&lt;" intoString:NULL])
            [result appendString:@"<"];
        else if ([scanner scanString:@"&gt;" intoString:NULL])
            [result appendString:@">"];
        else if ([scanner scanString:@"&#" intoString:NULL]) {
            BOOL gotNumber;
            unsigned charCode;
            NSString *xForHex = @"";

            // Is it hex or decimal?
            if ([scanner scanString:@"x" intoString:&xForHex]) {
                gotNumber = [scanner scanHexInt:&charCode];
            }
            else {
                gotNumber = [scanner scanInt:(int*)&charCode];
            }
            if (gotNumber) {
                [result appendFormat:@"%C", charCode];
            }
            else {
                NSString *unknownEntity = @"";
                [scanner scanUpToString:@";" intoString:&unknownEntity];
                [result appendFormat:@"&#%@%@;", xForHex, unknownEntity];
                NSLog(@"Expected numeric character entity but got &#%@%@;", xForHex, unknownEntity);
            }
            [scanner scanString:@";" intoString:NULL];
        }
        else {
            NSString *unknownEntity = @"";
            [scanner scanUpToString:@";" intoString:&unknownEntity];
            NSString *semicolon = @"";
            [scanner scanString:@";" intoString:&semicolon];
            [result appendFormat:@"%@%@", unknownEntity, semicolon];
            NSLog(@"Unsupported XML character entity %@%@", unknownEntity, semicolon);
        }
    }
    while (![scanner isAtEnd]);

    finish:
    return result;
}

+ (NSString *) stringWithUnicodeCharacter:(int) c
{
    return [[[NSString alloc] initWithCharacters:&c length:1] autorelease];
}

- (NSString *) urlEncode
{
    NSMutableString *result = [NSMutableString string];
    int i = 0;
    const char *source = [self cStringUsingEncoding:NSUTF8StringEncoding];
    int max = strlen(source);
    while (i < max) {
        unsigned char c = source[i++];
        if (c == ' ') {
            [result appendString:@"%20"];
        }
        else if (iswalpha(c) || iswdigit(c) || (c == '-') || (c == '.') || (c == '_') || (c == '~')) {
            [result appendFormat:@"%c", c];
        }
        else {
            [result appendString:[NSString stringWithFormat:@"%%%c%c", int_to_char[(c/16)%16], int_to_char[c%16]]];
        }
    }
    return result;
}

- (NSString *) urlDecode
{
    int i = 0;
    int max = [self length];
    char *buffer = (char *) malloc ((max + 1) * sizeof(char));
    int j = 0;
    while (i < max) {
        char c = [self characterAtIndex:i++];
        switch (c) {
            case '+':
                buffer[j++] = ' ';
                break;
            case '%':
                buffer[j++] =
                    char_to_int([self characterAtIndex:i])*16
                    + char_to_int([self characterAtIndex:i+1]);
                i = i + 2;
                break;
            default:
                buffer[j++] = c;
                break;
        }
    }
    buffer[j] = 0;
    NSString *result = [NSMutableString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    if (!result) result = [NSMutableString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    free(buffer);
    return result;
}

- (NSDictionary *) urlQueryDictionary
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *pairs = [self componentsSeparatedByString:@"&"];
    int i;
    int max = [pairs count];
    for (i = 0; i < max; i++) {
        NSArray *pair = [[pairs objectAtIndex:i] componentsSeparatedByString:@"="];
        if ([pair count] == 2) {
            NSString *key = [[pair objectAtIndex:0] urlDecode];
            NSString *value = [[pair objectAtIndex:1] urlDecode];
            [result setObject:value forKey:key];
        }
    }
    return result;
}

- (NSData *) dataUsingHexEncoding
{
    const char *encoding = [self cStringUsingEncoding:NSASCIIStringEncoding];

    int length = [self length] / 2;

    unsigned char *bytes = (unsigned char *) malloc (length * sizeof(unsigned char));
    int i;
    for (i = 0; i < length; i++) {
        bytes[i] = char_to_int(encoding[2*i])*16 + char_to_int(encoding[2*i+1]);
    }

    return [NSData dataWithBytesNoCopy:bytes length:length];
}

- (NSData *) dataUsingBase64Encoding
{
    BIO *b64, *bmem;

    // if our string doesn't end with a newline, conversion will fail.
    int length = [self length] + 1;
    NSData *data = [[self stringByAppendingString:@"\n"] dataUsingEncoding:NSASCIIStringEncoding];

    char *buffer = (char *)malloc(length);
    memset(buffer, 0, length);

    b64 = BIO_new(BIO_f_base64());
    bmem = BIO_new_mem_buf([data bytes], length);
    bmem = BIO_push(b64, bmem);

    int outputLength = BIO_read(bmem, buffer, length);
    BIO_free_all(bmem);

    return [NSData dataWithBytesNoCopy:buffer length:outputLength];
}

char *md5_crypt(const char *pw, const char *salt);

- (NSString *) md5HashWithSalt:(NSString *) salt;

{
    char *passwordString = strdup([self cStringUsingEncoding:NSUTF8StringEncoding]);
    const char *saltString = [salt cStringUsingEncoding:NSUTF8StringEncoding];

    size_t pw_maxlen = 256;

    /* truncate password if necessary */
    if ((strlen(passwordString) > pw_maxlen)) {
        passwordString[pw_maxlen] = 0;
    }

    /* now compute password hash */
    char *hash = md5_crypt(passwordString, saltString);
    free(passwordString);
    return [[NSString alloc] initWithCString:hash encoding:NSUTF8StringEncoding];
}

@end

@implementation NSDictionary (NuHTTPHelpers)
- (NSString *) urlQueryString
{
    NSMutableString *result = [NSMutableString string];
    NSEnumerator *keyEnumerator = [[[self allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
    id key;
    while ((key = [keyEnumerator nextObject])) {
        if ([result length] > 0) [result appendString:@"&"];
        [result appendString:[NSString stringWithFormat:@"%@=%@", [key urlEncode], [[[self objectForKey:key] stringValue] urlEncode]]];
    }
    return [NSString stringWithString:result];
}

@end

static NSMutableDictionary *parseHeaders(const char *headers)
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    int max = strlen(headers);
    int start = 0;
    int cursor = 0;
    while (cursor < max) {
        while ((headers[cursor] != ':') && (headers[cursor] != '=')) {
            cursor++;
        }
        NSString *key = [[[NSString alloc] initWithBytes:(headers+start)
            length:(cursor - start) encoding:NSASCIIStringEncoding] autorelease];
        //NSLog(@"got key[%@]", key);
        cursor++;

        // skip whitespace
        while (headers[cursor] == ' ') {cursor++;}
        start = cursor;
        while (headers[cursor] && (headers[cursor] != ';') && ((headers[cursor] != 13) || (headers[cursor+1] != 10))) {
            cursor++;
        }

        NSString *value;
                                                  // strip quotes
        if ((headers[start] == '"') && (headers[cursor-1] == '"'))
            value = [[[NSString alloc] initWithBytes:(headers+start+1) length:(cursor-start-2) encoding:NSASCIIStringEncoding] autorelease];
        else
            value = [[[NSString alloc] initWithBytes:(headers+start) length:(cursor-start) encoding:NSASCIIStringEncoding] autorelease];
        //NSLog(@"got value[%@]", value);
        [dict setObject:value forKey:key];

        if (headers[cursor] == ';')
            cursor++;
        else cursor += 2;
        // skip whitespace
        while (headers[cursor] == ' ') {cursor++;}
        start = cursor;
    }

    return dict;
}

@implementation NSData (NuHTTPHelpers)
- (NSDictionary *) urlQueryDictionary
{
    NSString *string = [[[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding] autorelease];
    return [string urlQueryDictionary];
}

- (NSDictionary *) multipartDictionaryWithBoundary:(NSString *) boundary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    const char *bytes = (const char *) [self bytes];
    const char *pattern = [boundary cStringUsingEncoding:NSUTF8StringEncoding];

    NSLog(@"pattern: %s", pattern);

    // scan through bytes, looking for pattern.
    // split on pattern.
    int cursor = 0;
    int start = 0;
    int max = [self length];
    NSLog(@"max = %d", max);
    while (cursor < max) {
        if (bytes[cursor] == pattern[0]) {
            // try to scan pattern
            int i;
            int patternLength = strlen(pattern);
            BOOL match = YES;
            for (i = 0; i < patternLength; i++) {
                if (bytes[cursor+i] != pattern[i]) {
                    match = NO;
                    break;
                }
            }
            if (match) {
                if (start != 0) {
                                                  // skip first cr/lf
                    int startOfHeaders = start + 2;
                    // scan forward to end of headers
                    int cursor2 = startOfHeaders;
                    while ((bytes[cursor2] != (char) 0x0d) ||
                        (bytes[cursor2+1] != (char) 0x0a) ||
                        (bytes[cursor2+2] != (char) 0x0d) ||
                    (bytes[cursor2+3] != (char) 0x0a)) {
                        cursor2++;
                        if (cursor2 + 4 == max) {
                            // something is wrong.
                            break;
                        }
                    }
                    if (cursor2 + 4 == max) {
                        // it's over
                        break;
                    }
                    else {
                        int lengthOfHeaders = cursor2 - startOfHeaders;
                        char *headers = (char *) malloc((lengthOfHeaders + 1) * sizeof(char));
                        strncpy(headers, bytes+startOfHeaders, lengthOfHeaders);
                        headers[lengthOfHeaders] = 0;

                        // Process headers.
                        NSMutableDictionary *item = parseHeaders(headers);

                                                  // skip CR/LF pair
                        int startOfData = cursor2 + 4;
                                                  // skip CR/LF and final two hyphens
                        int lengthOfData = cursor - startOfData - 2;

                        if (([item valueForKey:@"Content-Type"] == nil) && ([item valueForKey:@"filename"] == nil)) {
                            NSString *string = [[[NSString alloc]
                                initWithBytes:(bytes+startOfData)
                                length:lengthOfData
                                encoding:NSUTF8StringEncoding]
                                autorelease];
                            NSLog(@"saving %@ for %@", string, [item valueForKey:@"name"]);
                            [dict setObject:string forKey:[item valueForKey:@"name"]];
                        }
                        else {
                            NSData *data = [NSData dataWithBytes:(bytes+startOfData) length:lengthOfData];                            NSLog(@"saving data of length %d for %@", [data length], [item valueForKey:@"name"]);
                            [item setObject:data forKey:@"data"];
                            [dict setObject:item forKey:[item valueForKey:@"name"]];
                        }
                    }
                }
                cursor = cursor + patternLength - 1;
                start = cursor + 1;
            }
        }
        cursor++;
    }

    return dict;
}

- (NSDictionary *) multipartDictionary
{
    // scan for pattern
    const char *bytes = (const char *) [self bytes];
    int cursor = 0;
    int start = 0;
    int max = [self length];
    while (cursor < max) {
        if (bytes[cursor] == 0x0d) {
            break;
        }
        else {
            cursor++;
        }
    }
    char *pattern = (char *) malloc((cursor+1) * sizeof(char));
    strncpy(pattern, bytes, cursor);
    pattern[cursor] = 0x00;
    NSString *boundary = [[[NSString alloc] initWithCString:pattern encoding:NSUTF8StringEncoding] autorelease];
    free(pattern);
    return [self multipartDictionaryWithBoundary:boundary];
}

+ (NSData *) dataWithSize:(int) size
{
    char *bytes = (char *) malloc (size * sizeof(char));
    memset(bytes, 0, size);
    return [self dataWithBytesNoCopy:bytes length:size freeWhenDone:YES];
}

static const char *const digits = "0123456789abcdef";

- (NSString*) hex
{
    NSString *result = nil;
    size_t length = [self length];
    if (0 != length) {
        NSMutableData *temp = [NSMutableData dataWithLength:(length << 1)];
        if (temp) {
            const unsigned char *src = [self bytes];
            unsigned char *dst = [temp mutableBytes];
            if (src && dst) {
                while (length-- > 0) {
                    *dst++ = digits[(*src >> 4) & 0x0f];
                    *dst++ = digits[(*src++ & 0x0f)];
                }
                result = [[[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding] autorelease];
            }
        }
    }
    return result;
}

- (NSData *) md5
{
    unsigned char *digest = MD5([self bytes], [self length], NULL);
    return [NSData dataWithBytes:digest length:16];
}

- (NSData *) hmac_sha1:(NSData *) key
{
    unsigned char hash[1024];
    unsigned int hashlen;
    unsigned char *digest = HMAC(EVP_sha1(), [key bytes], [key length], [self bytes], [self length], hash, &hashlen);
    return [NSData dataWithBytes:hash length:hashlen];
}

- (NSData *) hmac_sha256:(NSData *) key
{
    unsigned char hash[1024];
    unsigned int hashlen;
    unsigned char *digest = HMAC(EVP_sha256(), [key bytes], [key length], [self bytes], [self length], hash, &hashlen);
    return [NSData dataWithBytes:hash length:hashlen];
}

- (NSString *) base64
{
    const char *input = [self bytes];
    int length = [self length];
    BIO *bmem, *b64;
    BUF_MEM *bptr;

    b64 = BIO_new(BIO_f_base64());
    bmem = BIO_new(BIO_s_mem());
    b64 = BIO_push(b64, bmem);
    BIO_write(b64, input, length);
    BIO_flush(b64);
    BIO_get_mem_ptr(b64, &bptr);

    char *buff = (char *)malloc(bptr->length);
    memcpy(buff, bptr->data, bptr->length-1);
    buff[bptr->length-1] = 0;

    BIO_free_all(b64);

    return [NSString stringWithCString:buff encoding:NSUTF8StringEncoding];
}

@end

@implementation NSDate (NuHTTPHelpers)

// Get an RFC822-compliant representation of a date.
- (NSString *) rfc822
{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    [result appendString:
    [self descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S "
        timeZone:[NSTimeZone localTimeZone] locale:nil]];
    [result appendString:[[NSTimeZone localTimeZone] abbreviation]];
    return result;
}

// Get an RFC822-compliant representation of a date, expressed in GMT.
- (NSString *) rfc822_GMT
{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    [result appendString:
    [self descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S GMT"
        timeZone:[NSTimeZone timeZoneWithName:@"GMT"] locale:nil]];
    return result;
}

// Get an RFC1123-compliant representation of a date.
- (NSString *) rfc1123
{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    [result appendString:
    [self descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S "
        timeZone:[NSTimeZone timeZoneWithName:@"GMT"] locale:nil]];
    [result appendString:[[NSTimeZone timeZoneWithName:@"GMT"] abbreviation]];
    return result;
}

// Get an RFC3339-compliant representation of a date.
- (NSString *) rfc3339
{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    [result appendString:
    [self descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S%z"
        timeZone:[NSTimeZone localTimeZone] locale:nil]];
    [result insertString:@":" atIndex:([result length] - 2)];
    return result;
}

@end
