#!/bin/sh
# The CLI must be able to open the app group's container independently of its caller.
exec /usr/bin/codesign --verify --strict \
  -R '=anchor apple generic and certificate leaf[subject.OU] = "MKAFV9VL9V" and entitlement["com.apple.security.application-groups"] = "MKAFV9VL9V.com.adriendonot.Vellem"' \
  "$1"
