;; test_helpers.nu
;;  tests for NuHTTPHelpers.
;;
;;  Copyright (c) 2009 Tim Burks, Neon Design Technology, Inc.

(load "NuHTTPHelpers")

(class TestHelpers is NuTestCase
     (- testUnicode is
        (assert_equal "\u1234" (NSString stringWithUnicodeCharacter:0x1234))
        (assert_equal "\u0000" (NSString stringWithUnicodeCharacter:0x0000)))
     
     (- testURLEncoding is
        (assert_equal "http%3A%2F%2Fprogramming.nu" ("http://programming.nu" urlEncode))
        (assert_equal "http%3A%2F%2Fprogramming.nu%2Fhome%3Fone%3D1%26two%3D2%263%3Dthree" ("http://programming.nu/home?one=1&two=2&3=three" urlEncode))
        (assert_equal "one%20two%20three%2C%20four%20five%20six" ("one two three, four five six" urlEncode))
        (assert_equal "caf%C3%A9" ("caf\xe9" urlEncode)))
     
     (- testURLDecoding is
        (assert_equal "http://programming.nu" ("http%3A%2F%2Fprogramming.nu" urlDecode))
        (assert_equal "http://programming.nu/home?one=1&two=2&3=three" ("http%3A%2F%2Fprogramming.nu%2Fhome%3Fone%3D1%26two%3D2%263%3Dthree" urlDecode))
        (assert_equal "one two three, four five six" ("one%20two%20three%2C%20four%20five%20six" urlDecode))
        (assert_equal "caf\xe9" ("caf%C3%A9" urlDecode)))
     
     (- testURLQueryDictionaryEncoding is
        (set d (dict one:1 two:2 zero:"z,e r&o"))
        (set s "one=1&two=2&zero=z%2Ce%20r%26o")
        (assert_equal s (d urlQueryString))
        (assert_equal (d description) ((s urlQueryDictionary) description)))
     
     (- testBase64 is
        (set d (NSData dataWithContentsOfFile:"objc/NuHTTPHelpers.m"))
        (assert_equal (d base64) (((d base64) dataUsingBase64Encoding) base64))
        (assert_equal d  ((d base64) dataUsingBase64Encoding)))
     
     (- testHex is
        (assert_equal "1234567890abcdefabcdef" (("1234567890abcdefABCDEF" dataUsingHexEncoding) hex)))
     
     (- testBase64andHexEncodings is
        (set hex "4894cb9adc0e14a3f33c72d05e26ddfdc8f67cf9f2e111b1bfcb7054d5883e2b")
        (set b64 "SJTLmtwOFKPzPHLQXibd/cj2fPny4RGxv8twVNWIPis=")
        (assert_equal hex ((b64 dataUsingBase64Encoding) hex))
        (assert_equal b64 ((hex dataUsingHexEncoding) base64)))
     
     (- testHashFunctions is
        (set thirtyTwoZeros (NSData dataWithSize:32))
        ;; ok, it's really 64. Two zeros per byte.
        (assert_equal "0000000000000000000000000000000000000000000000000000000000000000" (thirtyTwoZeros hex))
        ;;
        ;; MD5 hashing
        ;;
        ;; golden result obtained with "openssl md5"
        (assert_equal "70bc8f4b72a86921468bf8e8441dce51" ((thirtyTwoZeros md5) hex))
        ;; golden result obtained with "openssl md5 | openssl base64"
        (assert_equal "cLyPS3KoaSFGi/joRB3OUQ==" ((thirtyTwoZeros md5) base64))
        ;;
        ;; HMAC-SHA1 hashing
        ;;
        ;; golden result obtained with "openssl sha1 -hmac secret"
        (assert_equal "1cd0e4db152978b086c3fbd1d88b3d0fbc75b9d0" ((thirtyTwoZeros hmac_sha1:("secret" dataUsingEncoding:NSUTF8StringEncoding)) hex))
        ;; golden result obtained with "openssl sha1 -hmac secret -binary | openssl base64"
        (assert_equal "HNDk2xUpeLCGw/vR2Is9D7x1udA=" ((thirtyTwoZeros hmac_sha1:("secret" dataUsingEncoding:NSUTF8StringEncoding)) base64))
        ;;
        ;; Salted MD5 hashing, typically used for passwords
        ;;
        ;; golden result obtained with "openssl passwd -1 -salt sauce"
        (assert_equal "$1$sauce$ToKwxvX1ZyeiswSSzdPRi0" ("secret" md5HashWithSalt:"sauce"))))


