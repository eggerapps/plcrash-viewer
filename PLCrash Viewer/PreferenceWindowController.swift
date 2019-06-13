//
//  PreferenceWindowController.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Foundation
import Cocoa

class PreferenceWindowController: NSWindowController, NSTextViewDelegate
{
	@IBOutlet var rootFolderListTextView: NSTextView!
	
	// NOTE: It isn't necessary to mark static properties with the lazy keyword
	static let sharedController = PreferenceWindowController(windowNibName: "PreferenceWindow")
	
	static let DSymRootFolderListKey = "DSymRootFolderList"
	static let ArchiveFilePatternKey = "ArchiveFilePattern"
	
	override func windowDidLoad() {
		updateRootPathsFromDefaults()
		super.windowDidLoad()
	}
	
	private func updateRootPathsFromDefaults() {
		if let rootFolders = UserDefaults.standard.stringArray(forKey: PreferenceWindowController.DSymRootFolderListKey)
		{
			rootFolderListTextView.string = rootFolders.joined(separator: "\n")
		}
	}
	
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
				
				var normalizedLines = [String]()
				
				let lineBuffer = self.rootFolderListTextView.string
				let lines = lineBuffer.split(separator: "\n").map { String($0) }
				
				var alreadySeenLines = Set<String>()
				for line in lines {
					if alreadySeenLines.contains(line) { continue }
					normalizedLines.append(line)
					alreadySeenLines.insert(line)
				}
				
				let newPath = fileURL.path
				if !alreadySeenLines.contains(newPath) { normalizedLines.append(newPath) }

				UserDefaults.standard.set(normalizedLines as NSArray, forKey: PreferenceWindowController.DSymRootFolderListKey)

				self.updateRootPathsFromDefaults()
			}
		}
	}
	
	// MARK: -
	
	@objc public func textDidChange(_ notification: Notification) {
		let lineBuffer = self.rootFolderListTextView.string
		let lines = lineBuffer.split(separator: "\n").map { String($0) }
		UserDefaults.standard.set(lines as NSArray, forKey: PreferenceWindowController.DSymRootFolderListKey)
	}
}
