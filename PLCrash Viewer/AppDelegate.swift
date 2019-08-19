//
//  AppDelegate.swift
//  PLCrash Viewer
//
//  Created by Jakob Egger on 06.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		MainWindowController.shared.showWindow(nil)
		return true
	}
	
	
/*
	-(BOOL)applicationOpenUntitledFile:(NSApplication *)sender {
		[[PGEWindowController windowControllerFor:[NavigationItem favoritesList]] showWindow: nil];
		return YES;
	}

	-(IBAction)newWindow:(id)sender {
		[[PGEWindowController windowControllerFor:[NavigationItem favoritesList]] showWindow: nil];
	}
*/
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		
		UserDefaults.standard.register(defaults: [PreferenceWindowController.DSymRootFolderListKey: ["/Volumes/RAID/Builds/Releases/", "/Volumes/RAID/Builds/Postico/"],
												  PreferenceWindowController.ArchiveFilePatternKey: "postico-$BUILD.xcarchive.zip"])
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	@IBAction func openPreferenceWindow(_ sender: Any?) {
		PreferenceWindowController.sharedController.showWindow(sender)
	}
}

