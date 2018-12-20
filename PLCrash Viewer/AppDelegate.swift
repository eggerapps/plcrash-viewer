//
//  AppDelegate.swift
//  PLCrash Viewer
//
//  Created by Jakob Egger on 06.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		
		UserDefaults.standard.register(defaults: [PreferenceWindowController.DSymRootFolderKey: "/Volumes/Builds/Releases/",
												  PreferenceWindowController.ArchiveFilePatternKey: "postico-$BUILD.xcarchive.zip"])
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	@IBAction func openPreferenceWindow(_ sender: Any?) {
		PreferenceWindowController.sharedController.showWindow(sender)
	}
}

