# iCloud CloudKit Setup Instructions

Your app is now configured for iCloud sync! Follow these steps to complete the setup in Xcode.

## Required Steps in Xcode

### 1. Enable iCloud Capability

1. Open **Fun Finance App.xcodeproj** in Xcode
2. Select the **Fun Finance App** target (not the Tests target)
3. Click on **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Search for and add **iCloud**
6. In the iCloud section, check these boxes:
   - ✅ **CloudKit**
7. Under Containers, you should see:
   - `iCloud.punkproduct.Fun-Finance-App`

   **Note:** If the container doesn't exist, Xcode will create it automatically when you build

### 2. Enable Background Modes (Optional but Recommended)

1. Still in **Signing & Capabilities** tab
2. Click **+ Capability** again
3. Add **Background Modes**
4. Check:
   - ✅ **Remote notifications**

   This allows the app to wake up and sync when changes come from other devices.

### 3. Verify Bundle Identifier

Make sure your app's Bundle Identifier matches the CloudKit container:
- Bundle ID: `punkproduct.Fun-Finance-App`
- CloudKit Container: `iCloud.punkproduct.Fun-Finance-App`

These should already be correctly configured in your project.

### 4. Build and Test

1. Build the app (⌘B)
2. Run on a device or simulator
3. Sign into iCloud on that device (Settings > [Your Name])
4. The app will now sync data to iCloud!

## How to Test Sync

1. **Single Device Test:**
   - Add some impulses in the app
   - Delete the app
   - Reinstall it
   - Your data should automatically restore!

2. **Multi-Device Test:**
   - Install on iPhone
   - Install on iPad (or another iPhone)
   - Sign into same iCloud account on both
   - Add an impulse on one device
   - Wait 10-30 seconds
   - Open the app on the other device
   - The impulse should appear!

## Troubleshooting

### "Container not found" error
- Make sure you're signed into Xcode with an Apple ID (Xcode > Settings > Accounts)
- You may need an Apple Developer account (free or paid)

### Data not syncing
- Verify the device is signed into iCloud
- Check internet connection
- Go to Settings > [Your Name] > iCloud > See All Apps > Make sure your app is enabled

### How to check sync status in code
The `CloudKitSyncMonitor` is available in `AppContainer`:
```swift
container.cloudKitSyncMonitor.syncStatus
container.cloudKitSyncMonitor.isCloudKitAvailable
```

You can display this in a Settings view to show users their sync status.

## What's Synced

Everything is synced:
- ✅ All impulses (wanted items)
- ✅ Monthly summaries
- ✅ App settings
- ✅ Images (up to 500KB each, compressed)

## CloudKit Limits (Free)

- **1GB** total storage per user
- **10GB** monthly data transfer per user
- Plenty for this app's usage!

## Next Steps

Consider adding a sync status indicator in your Settings view:

```swift
@ObservedObject var syncMonitor = container.cloudKitSyncMonitor

var body: some View {
    if syncMonitor.isCloudKitAvailable {
        HStack {
            Image(systemName: syncIcon)
            Text(syncStatusText)
        }
    } else {
        Text("Sign in to iCloud to enable sync")
    }
}
```
