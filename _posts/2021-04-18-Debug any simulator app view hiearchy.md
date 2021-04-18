---
layout: post
title: Debugging any iOS simulator app view hierarchy
---

Xcode offers a nice [tool](https://developer.apple.com/library/archive/documentation/ToolsLanguages/Conceptual/Xcode_Overview/ExaminingtheViewHierarchy.html) for debugging your 
app view hierarchy. But sometimes it would be nice to see how others are 
structuring their UI. Up  until Xcode ... it was possible to attach LLDB to any 
iOS app process and  through that see its view hierarchy.

If you try to do it today, you will get error like: 
```
Could not attach to pid : “6430”
Domain: IDEDebugSessionErrorDomain
Code: 3
Failure Reason: attach failed (Not allowed to attach to process.  Look in the console messages (Console.app), near the debugserver entries when the attached failed.  The subsystem that denied the attach permission will likely have logged an informative message about why it was denied.)
User Info: {
    DVTRadarComponentKey = 855031;
    RawLLDBErrorMessage = "attach failed (Not allowed to attach to process.  Look in the console messages (Console.app), near the debugserver entries when the attached failed.  The subsystem that denied the attach permission will likely have logged an informative message about why it was denied.)";
}
```
![Screenshot 2021-04-18 at 09.59.10.png](/assets/images/Screenshot 2021-04-18 at 09.59.10.png)

From that error message we can see that we are not allowed to attach to that 
process. This is controlled by `com.apple.security.get-task-allow` [entitlement](https://developer.apple.com/documentation/bundleresources/entitlements) 
in the app binary.

Luckily, we can change that entitlement. But before that, we need to find the 
app we want to debug.

## Finding simulator apps

I'm going to use Apple Maps app as the app, I want to debug. iOS Simulator 
default apps all live in the same location, so its relatively easy to find them.
If we know the bundle ID for the app, we can use simctl to find it: 
```sh
xcrun simctl get_app_container booted com.apple.Maps
```

```
/Users/alvarhansen/Downloads/Xcode_12.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/Applications/Maps.app
```

If you do not know the bundle ID beforehand, you can just open the Applications
directory:

1. Find Xcode location:

	```sh
	xcode-select -p
	```

	```
	/Users/alvarhansen/Downloads/Xcode_12.4.app/Contents/Developer
	```

2. Open iOS Simulator applications directory:

	```sh
	open $(xcode-select -p)/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/Applications
	```

## Changing the simulator app

Modifying app entitlements means we will change its actual binary file. But the
app is located inside Xcode app, and we can't change the Xcode app. So, we will
copy the original app and make it "ours".

Lets copy Maps app to our Documents directory:
```sh
cp -R \
	$(xcode-select -p)/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/Applications/Maps.app \
	~/Documents/Maps.app
```

## Setting new entitlements

Before overriding entitlements, lets see what entitlements the app already has:

```sh
codesign -d --entitlements :- ~/Documents/Maps.app
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

No entitlements, but we can see that we need to use PropertyList file format.

Lets use this empty plist and create a plist file named `MapsEntitlements.plist`
at Documents directory with content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>com.apple.security.get-task-allow</key>
		<true/>
	</dict>
</plist>
```

Configuring entitlements is done using `codesign` tool. But to sign a binary, 
we need your developer identity. This can be found using:

```sh
security find-identity
```

```
  1) ABCD1234ABCD1234ABCD1234ABCD1234ABCD1234 "Apple Development: Alvar Hansen (ABCD1234)"
```

Copy that SHA1 fingerprint and use it in this command as signing identity:

```sh
codesign --force --options runtime --deep \
	--entitlements ~/Documents/MapsEntitlements.plist \
	--sign 'ABCD1234ABCD1234ABCD1234ABCD1234ABCD1234' \
	~/Documents/Maps.app
```

Most likely you will be prompted by system to give `codesign` an access to your
keychain.

After that we can check "our" app entitlements, and see if it has `get-task-allow`
entitlement:

```sh
codesign -d --entitlements :- ~/Documents/Maps.app
```

```xml
Executable=/Users/alvarhansen/Documents/Maps.app/Maps
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>com.apple.security.get-task-allow</key>
		<true/>
	</dict>
</plist>
```

It does!

As we changed the app binary, we need to resign it:

```sh
codesign --force --options runtime --deep \
	--entitlements ~/Documents/MapsEntitlements.plist \
	--sign 'ABCD1234ABCD1234ABCD1234ABCD1234ABCD1234' \
	~/Documents/Maps.app
```

## Installing app onto iOS Simulator

There are multiple ways to install apps onto simulator. Easiest is just drag and
drop of `.app` bundle. But you can also use `simctl`:

```sh
xcrun simctl install booted ~/Documents/Maps.app
```

```
An error was encountered processing the command (domain=IXUserPresentableErrorDomain, code=1):
Unable To Install “Maps”
Please try again later.
Rejecting downgrade of system/internal app com.apple.Maps: installed version is 2608.33.11.29.4, proposed version is 2608.33.11.29.4
Underlying error (domain=MIInstallerErrorDomain, code=34):
	Rejecting downgrade of system/internal app com.apple.Maps: installed version is 2608.33.11.29.4, proposed version is 2608.33.11.29.4
```

Oh no! We can't overwrite system apps. But no worries, lets make it even more "ours".
The way Simulator knows that this is existing system app is its bundle ID. So,
lets change the bundle ID of "our" app.

```sh
plutil -replace CFBundleIdentifier -string "not.apple.maps" ~/Documents/Maps.app/Info.plist
```

If we try to install the app again, get next error:

```
An error was encountered processing the command (domain=IXErrorDomain, code=2):
Failed to set plugin placeholders for not.apple.maps
Failed to create promise.
Underlying error (domain=IXErrorDomain, code=8):
	Attempted to set plugin placeholder promise with bundle ID com.apple.Maps.GeneralMapsWidget that does not match required prefix of not.apple.maps. for parent
	Mismatched bundle IDs.
```

Maps app comes with extensions and extensions bundle identifiers need common 
prefix. We have 2 options here:
a) We just delete them as we don't need them.
b) We change bundle ID of them.

I'm going with option A here:

```sh
rm -r ~/Documents/Maps.app/PlugIns
```

Time to attempt that install again:

```sh
xcrun simctl install booted ~/Documents/Maps.app
```

And success! If we take a look into Simulator, we see that we have 2 Maps apps
now:

![Simulator Screen Shot - iPhone X - 2021-04-18 at 11.41.02.png](/assets/images/Simulator Screen Shot - iPhone X - 2021-04-18 at 11.41.02.png)

## Debugging Maps app

Time to debug "our" Maps app. First thing we need to do is to launch it. Tap on
the second Maps icon, launch it from terminal:

```sh
xcrun simctl launch not.apple.maps
```

```sh
not.apple.maps: 9249
```
One of the benefits of running it from terminal is that we get back the process ID.
It will be useful for us in next step.

## Attaching debugger to app

Now that we have "our" Maps app running, its time to open Xcode. To be able to
use Xcode debugger tools, you need to have any iOS app project open. It does not
matter if it is your existing, unrelated app or just new plain iOS app project.

Once you have opened your Xcode project, go to Menu -> Debug -> "Attach to Process by PID or Name":
![Screenshot 2021-04-18 at 11.56.23.png](/assets/images/Screenshot 2021-04-18 at 11.56.23.png)


Use the PID from previous step or type in "Maps" and then click on "Attach".
![Screenshot 2021-04-18 at 12.01.32.png](/assets/images/Screenshot 2021-04-18 at 12.01.32.png)

After few seconds, you should see that Xcode Debug area becomes active and you
can now select "Debug View Hierarchy".
![Screenshot 2021-04-18 at 12.03.02.png](/assets/images/Screenshot 2021-04-18 at 12.03.02.png)

Click on it! Wait few seconds and you should now have View Debugger attached to 
Maps app.

![Screenshot 2021-04-18 at 12.05.59.png](/assets/images/Screenshot 2021-04-18 at 12.05.59.png)

