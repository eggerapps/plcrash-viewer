//
//  MainWindowController.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.08.19.
//  Copyright © 2019 Egger Apps. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController, NSOutlineViewDelegate, NSOutlineViewDataSource
{
	// MARK: - Properties
	
	@IBOutlet var sidebarOutlineView: NSOutlineView!
	@IBOutlet var detailViewHolder: NSView!
	@IBOutlet var crashReportViewController: CrashReportViewController!

	private var store: CrashReportStore!
	private var storeView: CrashReportStoreView!
	
	// MARK: - Singleton Access
	
	// NOTE: It isn't necessary to mark static properties with the lazy keyword
	static let shared = MainWindowController(windowNibName: "MainWindow")
	
	// MARK: - NSWindowController overrides
	
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
		
		let crashView = crashReportViewController.view
		detailViewHolder.addSubview(crashView)
		detailViewHolder.addConstraints([
			detailViewHolder.leadingAnchor.constraint(equalTo: crashView.leadingAnchor),
			detailViewHolder.trailingAnchor.constraint(equalTo: crashView.trailingAnchor),
			detailViewHolder.topAnchor.constraint(equalTo: crashView.topAnchor, constant: -5),
			detailViewHolder.bottomAnchor.constraint(equalTo: crashView.bottomAnchor)
		])
		
		// TODO
		store = CrashReportStore()
		storeView = CrashReportStoreView(store: store)
    }
    
	// MARK: -
	// MARK: Outline View Datasource & Delegate
	
	/*
	func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
		return view
	}*/
		
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return storeView.categories.count
		}
		else if let category = item as? Category {
			return category.children.count
		}
		else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is Category
	}
    
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return storeView.categories[index]
		}
		else if let category = item as? Category {
			return category.children[index]
		}
		else {
			fatalError("NSOutlineView requested child of invalid item: \(item!)")
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView?
	{
		let identifier: NSUserInterfaceItemIdentifier
		switch item {
		case is CrashReport:
			identifier = NSUserInterfaceItemIdentifier("CrashReportCell")
		case is Category:
			identifier = NSUserInterfaceItemIdentifier("CategoryCell")
		default:
			identifier = tableColumn!.identifier
		}
		return outlineView.makeView(withIdentifier: identifier, owner: nil)
	}
	
	/*
	func outlineViewItemDidCollapse(_ notification: Notification) {
		favoriteViewController.roundCornerView.needsDisplay = true
	}
	
	func outlineViewItemDidExpand(_ notification: Notification) {
		favoriteViewController.roundCornerView.needsDisplay = true
	}
*/

}
