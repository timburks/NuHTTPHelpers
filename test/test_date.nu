;; test_date.nu
;;  tests for NSDate extensions in NuHTTPHelpers.
;;
;;  Copyright (c) 2009 Tim Burks, Neon Design Technology, Inc.

(load "NuHTTPHelpers")

(class TestDate is NuTestCase
     (- testFormatters is
        (set date (NSDate dateWithTimeIntervalSinceReferenceDate:0))
        (assert_equal "Sun, 31 Dec 2000 16:00:00 PDT" (date rfc822))
        (assert_equal "Mon, 01 Jan 2001 00:00:00 GMT" (date rfc822_GMT))
        (assert_equal "Mon, 01 Jan 2001 00:00:00 GMT+00:00" (date rfc1123))
        (assert_equal "2000-12-31T16:00:00-08:00" (date rfc3339))))