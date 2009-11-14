/*!
@header NuHTTPHelpers.h
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

#import <Foundation/Foundation.h>

@interface NSString (NuHTTPHelpers)
/*! URL-encode a string. */
- (NSString *) urlEncode;
/*! Decode a url-encoded string. */
- (NSString *) urlDecode;
/*! Convert a url query into a dictionary. */
- (NSDictionary *) urlQueryDictionary;
/*! Base64 decode a string */
- (NSData *) dataUsingBase64Encoding;
/*! Compute an md5 hash of a string (typically a password) with a specified salt. */
- (NSString *) md5HashWithSalt:(NSString *) salt;
@end

@interface NSDictionary (NuHTTPHelpers)
/*! Convert a dictionary into a url query string. */
- (NSString *) urlQueryString;
@end

@interface NSData (NuHTTPHelpers)
/*! Get a dictionary from an encoded post. */
- (NSDictionary *) urlQueryDictionary;
/*! Get a dictionary corresponding to a multipart-encoded message body. */
- (NSDictionary *) multipartDictionaryWithBoundary:(NSString *) boundary;
/*! Create a data object of a specified size. */
+ (NSData *) dataWithSize:(int) size;
/*! Get a hex representation of binary data. */
- (NSString*) hex;
/*! Get an md5 hash of binary data. */
- (NSData *) md5;
/*! Get an HMAC SHA1 hash of binary data. */
- (NSData *) hmac_sha1:(NSData *) key;
/*! Base64 encode binary data. */
- (NSString *) base64;
@end
