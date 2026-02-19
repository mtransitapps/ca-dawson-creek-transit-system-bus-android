#!/bin/bash
# Setup script for recording screenshots
# This script:
# 1. Installs the main mtransit-for-android app (APK path from env var)
# 2. Grants location permission to the main app
# 3. Sets GPS location based on GTFS area bounds
# 4. Installs the current repository's module app (APK path from env var)
# 5. Calls the screenshot recording script

set -e

echo ">> Setup and record screenshots..."

# Constants
MAIN_APP_PACKAGE="org.mtransit.android"

echo ">> Step 1: Install main mtransit app..."

if [ -z "$MAIN_APK_FILE" ]; then
  echo " > ERROR: MAIN_APK_FILE environment variable not set"
  exit 1
fi

if [ ! -f "$MAIN_APK_FILE" ]; then
  echo " > ERROR: Main APK file not found: $MAIN_APK_FILE"
  exit 1
fi

echo " - Installing main app from: $MAIN_APK_FILE"
adb install -r -d "$MAIN_APK_FILE"

# Verify installation
if ! adb shell pm list packages | grep -q "^package:${MAIN_APP_PACKAGE}$"; then
  echo " > ERROR: Main app installation failed"
  exit 1
fi

echo " - Main app installed successfully"

echo ">> Step 2: Grant location permission to main app..."

# Grant location permissions
adb shell pm grant "$MAIN_APP_PACKAGE" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$MAIN_APP_PACKAGE" android.permission.ACCESS_COARSE_LOCATION

echo " - Location permissions granted"

echo ">> Step 2.5: Set emulator GPS location..."

# Parse GPS coordinates from XML if available
GPS_XML_FILE="app-android/src/main/res-current/values/current_gtfs_rts_values_gen.xml"
if [ -f "$GPS_XML_FILE" ]; then
  echo " - Found GPS coordinates file: $GPS_XML_FILE"
  
  # Extract min/max lat/lng values using xmllint
  MIN_LAT=$(xmllint --xpath "string(//resources/string[@name='current_gtfs_rts_area_min_lat']/text())" "$GPS_XML_FILE" 2>/dev/null || echo "")
  MAX_LAT=$(xmllint --xpath "string(//resources/string[@name='current_gtfs_rts_area_max_lat']/text())" "$GPS_XML_FILE" 2>/dev/null || echo "")
  MIN_LNG=$(xmllint --xpath "string(//resources/string[@name='current_gtfs_rts_area_min_lng']/text())" "$GPS_XML_FILE" 2>/dev/null || echo "")
  MAX_LNG=$(xmllint --xpath "string(//resources/string[@name='current_gtfs_rts_area_max_lng']/text())" "$GPS_XML_FILE" 2>/dev/null || echo "")
  
  if [ -n "$MIN_LAT" ] && [ -n "$MAX_LAT" ] && [ -n "$MIN_LNG" ] && [ -n "$MAX_LNG" ]; then
    # Calculate center point (average of min and max)
    CENTER_LAT=$(echo "scale=6; ($MIN_LAT + $MAX_LAT) / 2" | bc)
    CENTER_LNG=$(echo "scale=6; ($MIN_LNG + $MAX_LNG) / 2" | bc)
    
    echo " - Setting GPS location to center: $CENTER_LAT, $CENTER_LNG"
    adb emu geo fix "$CENTER_LNG" "$CENTER_LAT"
    
    echo " - GPS location set successfully"
  else
    echo " > WARNING: Could not parse GPS coordinates from XML"
  fi
else
  echo " - No GPS coordinates file found, skipping GPS setup"
fi

echo ">> Step 3: Install current repository module app..."

if [ -n "$MODULE_APK_FILE" ] && [ -f "$MODULE_APK_FILE" ]; then
  # Get the package name from config/pkg if it exists
  CONFIG_PKG_FILE="config/pkg"
  if [ -f "$CONFIG_PKG_FILE" ]; then
    MODULE_PACKAGE=$(cat "$CONFIG_PKG_FILE")
    echo " - Module package: $MODULE_PACKAGE"
    echo " - Installing module app from: $MODULE_APK_FILE"
    
    adb install -r -d "$MODULE_APK_FILE"
    
    # Verify installation
    if adb shell pm list packages | grep -q "^package:${MODULE_PACKAGE}$"; then
      echo " - Module app installed successfully"
    else
      echo " > WARNING: Module app installation may have failed"
    fi
  else
    echo " > WARNING: No config/pkg file found, skipping module installation"
  fi
else
  echo " - No module APK provided or file not found, skipping module installation"
fi

echo ">> Step 4: Disable Pixel Launcher to prevent crashes..."

# Stop Pixel Launcher to prevent "not responding" dialogs during screenshot capture
adb shell am force-stop com.google.android.apps.nexuslauncher || true
adb shell pm disable-user --user 0 com.google.android.apps.nexuslauncher || true

echo " - Pixel Launcher disabled"

echo ">> Step 5: Record screenshots..."

# Call the screenshot recording script
if [ -f "./commons-android/pub/all-app-screenshots.sh" ]; then
  ./commons-android/pub/all-app-screenshots.sh
elif [ -f "../commons-android/pub/all-app-screenshots.sh" ]; then
  ../commons-android/pub/all-app-screenshots.sh
else
  echo " > ERROR: Screenshot recording script not found"
  exit 1
fi

echo ">> Setup and record screenshots... DONE"
