//
//  PreferenceWindowController.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Foundation
import Cocoa

class PreferenceWindowController: NSWindowController
{
	// NOTE: It isn't necessary to mark static properties with the lazy keyword
	static let sharedController = PreferenceWindowController(windowNibName: "PreferenceWindow")
	
	static let DSymRootFolderKey = "DSymRootFolder"
	static let ArchiveFilePatternKey = "ArchiveFilePattern"
	
	@IBAction func chooseRootFolder(_ sender: Any?)
	{
		let openPanel = NSOpenPanel()
		openPanel.message = "Choose dSYM Root Folder…"
		openPanel.showsHiddenFiles = false
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = true
		openPanel.canChooseFiles = false
		openPanel.canCreateDirectories = true
		openPanel.beginSheetModal(for: self.window!) { response in
			if response == .OK {
				guard let fileURL = openPanel.url else { fatalError("Pressed OK in open panel but url is nil") }
				UserDefaults.standard.set(fileURL, forKey: PreferenceWindowController.DSymRootFolderKey)
			}
		}
	}
}
