;; test_amazon.nu
;;  tests Amazon AWS request-signing using NuHTTPHelpers
;;
;;  Copyright (c) 2010 Tim Burks, Neon Design Technology, Inc.

(load "NuHTTPHelpers")

(class TestAmazon is NuTestCase
     (- testSignature is
        ;; http://docs.amazonwebservices.com/AWSECommerceService/2009-11-01/DG/index.html?rest-signature.html
        
        (set METHOD "GET")
        (set HOST "webservices.amazon.com")
        (set PATH "/onca/xml")
        (set AWS_ACCESS_KEY_ID "00000000000000000000")
        (set AWS_SECRET_ACCESS_KEY "1234567890")
        
        ;; declare arguments
        (set args
             (dict Service:"AWSECommerceService"
                   AWSAccessKeyId:AWS_ACCESS_KEY_ID
                   Operation:"ItemLookup"
                   ItemId:"0679722769"
                   ResponseGroup:"ItemAttributes,Offers,Images,Reviews"
                   Version:"2009-01-06"
                   Timestamp:"2009-01-01T12:00:00Z"))
        
        ;; collect arguments into a sorted array
        (set strings (array))
        (args each:
              (do (key value)
                  (set string (+ key "=" (value urlEncode)))
                  (strings << string)))
        (set strings (strings sort))
        
        ;; prepare request string to be signed
        (set stringToSign (+ METHOD "\n"
                             HOST "\n"
                             PATH "\n"
                             (strings componentsJoinedByString:"&")))
        
        ;; sign request
        (set signature (((stringToSign dataUsingEncoding:NSUTF8StringEncoding)
                         hmac_sha256:(AWS_SECRET_ACCESS_KEY dataUsingEncoding:NSUTF8StringEncoding))
                        base64))
        
        (set golden "Nace+U3Az4OhN7tISqgs1vdLBHBEijWcBeCqL5xN9xg=")
        
        (assert_equal golden signature)))