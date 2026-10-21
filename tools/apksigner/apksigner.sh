#!/bin/bash
D=$(dirname "$0")/lib
exec java --add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED --add-exports java.base/sun.security.util=ALL-UNNAMED -cp "$D:$D/apksig.jar" ApkSignerShim "$@" 2> >(grep -v JAVA_TOOL_OPTIONS >&2)
