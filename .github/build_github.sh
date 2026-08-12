set -eu

rm -rf Payload tmp .zsign_cache dylibify "$scheme.ipa" "$scheme+SideStore.ipa"
mkdir -p tmp

# Use the same executable-to-dylib conversion as upstream LiveContainer. The
# converter also updates chained-fixup segment indexes after removing PAGEZERO.
curl --fail --location --retry 3 \
    --output ./tmp/dylibify \
    https://github.com/LiveContainer/dylibify/releases/download/1.0/dylibify
chmod +x ./tmp/dylibify

# copy lc to working folder
cp -R "$archive_path.xcarchive/Products/Applications" Payload

# temporarily move SideStore support framework to tmp before zip
mv Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework ./tmp

zip -r "$scheme.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"

mv ./tmp/SideStoreSupport.framework Payload/LiveContainer.app/Frameworks

# put sidestore related keys into Info.plist and settings bundle
/usr/libexec/PlistBuddy -c 'Add :ALTAppGroups array' ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c 'Add :ALTAppGroups: string group.com.SideStore.SideStore' ./Payload/LiveContainer.app/Info.plist

/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1 dict" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLName string com.kdt.livecontainer.sidestoreurlscheme" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes:0 string sidestore" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2 dict" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLName string com.kdt.livecontainer.sidestorebackupurlscheme" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLSchemes array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLSchemes:0 string sidestore-com.kdt.livecontainer" ./Payload/LiveContainer.app/Info.plist

/usr/libexec/PlistBuddy -c "Add :INIntentsSupported array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :INIntentsSupported:0 string RefreshAllIntent" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :INIntentsSupported:1 string ViewAppIntent" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes:0 string RefreshAllIntent" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes:1 string ViewAppIntent" ./Payload/LiveContainer.app/Info.plist

/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Type string PSToggleSwitchSpecifier" ./Payload/LiveContainer.app/Settings.bundle/Root.plist
/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Title string Open SideStore" ./Payload/LiveContainer.app/Settings.bundle/Root.plist
/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Key string LCOpenSideStore" ./Payload/LiveContainer.app/Settings.bundle/Root.plist
/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:DefaultValue bool false" ./Payload/LiveContainer.app/Settings.bundle/Root.plist

# download SideStore
cd tmp
if [ -n "${SIDESTORE_IPA_PATH:-}" ] && [ -f "$SIDESTORE_IPA_PATH" ]; then
    cp "$SIDESTORE_IPA_PATH" SideStore.ipa
else
    wget https://github.com/LiveContainer/SideStore/releases/download/nightly/SideStore.ipa
fi
unzip SideStore.ipa
cd ..

# SideStore
mv ./tmp/Payload/SideStore.app ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework
SIDESTORE_EXECUTABLE=./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
./tmp/dylibify "$SIDESTORE_EXECUTABLE" "$SIDESTORE_EXECUTABLE.dylib"
test -s "$SIDESTORE_EXECUTABLE.dylib"
rm "$SIDESTORE_EXECUTABLE"
mv "$SIDESTORE_EXECUTABLE.dylib" "$SIDESTORE_EXECUTABLE"

# Fail packaging if the converted image is not a dylib or has no install name.
otool -hv "$SIDESTORE_EXECUTABLE"
otool -hv "$SIDESTORE_EXECUTABLE" | grep -Eq 'DYLIB|0x6'
otool -D "$SIDESTORE_EXECUTABLE" | grep -Fq 'SideStore'
ldid -S"" ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
cp ./.github/sidelc/LCAppInfo.plist ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/

# Embedded SideStore becomes Bundle.main at runtime, so its orientation mask must
# match the LiveContainer host instead of SideStore's portrait-only iPhone default.
SIDESTORE_INFO=./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Info.plist
/usr/libexec/PlistBuddy -c "Delete :UISupportedInterfaceOrientations" \
    -c "Add :UISupportedInterfaceOrientations array" \
    -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" \
    -c "Add :UISupportedInterfaceOrientations:1 string UIInterfaceOrientationLandscapeLeft" \
    -c "Add :UISupportedInterfaceOrientations:2 string UIInterfaceOrientationLandscapeRight" \
    "$SIDESTORE_INFO"
/usr/libexec/PlistBuddy -c "Print :UISupportedInterfaceOrientations:1" "$SIDESTORE_INFO" | grep -Fxq "UIInterfaceOrientationLandscapeLeft"

# copy intents
cp ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Intents.intentdefinition ./Payload/LiveContainer.app/
cp ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/ViewApp.intentdefinition ./Payload/LiveContainer.app/
cp -r ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Metadata.appintents ./Payload/LiveContainer.app/Metadata.appintents
sed -i '' 's/9SideStore20RefreshAllAppsIntentV/16SideStoreSupport20RefreshAllAppsIntentV/g' ./Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata
sed -i '' 's/9SideStore26RefreshAllAppsWidgetIntentV/16SideStoreSupport26RefreshAllAppsWidgetIntentV/g' ./Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata

# AltWidgetExtension
mv ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/PlugIns/AltWidgetExtension.appex ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
cp -r ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Frameworks ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.kdt.livecontainer.LiveWidget"  ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable LiveWidgetExtension"  ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
mv ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/AltWidgetExtension ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension

# Sign
rm -rf .zsign_cache
if [ -d payloadlc/Payload ]; then
    find payloadlc/Payload -type d -name "_CodeSignature" -exec rm -r {} +
fi

ldid -S.github/sidelc/LiveWidgetExtension_adhoc.xml ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension

# package
zip -r "$scheme+SideStore.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
