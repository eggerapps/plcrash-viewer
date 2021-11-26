//
//  Document.swift
//  PLCrash Viewer
//
//  Created by Jakob Egger on 06.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Cocoa

class Document: NSDocument {

	@IBOutlet var contentView: NSTextView!
	@IBOutlet weak var threadsView: NSOutlineView!
	
	@IBAction func selectDisplayMode(_ sender: NSSegmentedControl) {
		threadsView.enclosingScrollView!.isHidden = (sender.selectedSegment != 0)
		contentView.enclosingScrollView!.isHidden = (sender.selectedSegment != 1)
	}
	
	var crashReport: PLCrashReport?
	var threadsViewDatasource: ThreadsViewDatasource?
	var symbolizer: Symbolizer?
	
	func updateContentView() {
		if let contentView = contentView {
			if let crashReport = crashReport {
				contentView.string = PLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS)
			} else {
				contentView.string = ""
			}
		}
		if let threadsView = threadsView {
			if let crashReport = crashReport {
				threadsViewDatasource = ThreadsViewDatasource(crashReport: crashReport, symbolizer: symbolizer)
			} else {
				threadsViewDatasource = nil
			}
			threadsView.dataSource = threadsViewDatasource
			threadsView.delegate = threadsViewDatasource
			threadsView.reloadData()
			if let crashReport = crashReport {
				if let e = crashReport.exceptionInfo {
					threadsView.expandItem(e)
				} else {
					for thread in crashReport.threads as! [PLCrashReportThreadInfo] {
						if thread.crashed {
							threadsView.expandItem(thread)
						}
					}
				}
			}
		}
	}
	
	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}

	override class var autosavesInPlace: Bool {
		return true
	}

	override var windowNibName: NSNib.Name? {
		// Returns the nib file name of the document
		// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
		return NSNib.Name("Document")
	}

	override func data(ofType typeName: String) throws -> Data {
		// Insert code here to write your document to data of the specified type, throwing an error in case of failure.
		// Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	override func read(from wrappedData: Data, ofType typeName: String) throws {
		let data = try uncompressCrashReport(data: wrappedData)
        crashReport = try PLCrashReport(data: data)
		updateContentView()
	}
	
	@IBAction func symbolize(_: Any?) {
		do {
			guard let rootFolders = UserDefaults.standard.stringArray(forKey: PreferenceWindowController.DSymRootFolderListKey)
				else { throw SymbolizerError.dSymRootFolderKeyMissing }
			guard let archivePattern = UserDefaults.standard.string(forKey: PreferenceWindowController.ArchiveFilePatternKey)
				else { throw SymbolizerError.archiveFilePatternKeyMissing }
			
			let rootFolderURLs = rootFolders.map { URL(fileURLWithPath: $0) }
			
			let source = DSYMSymbolizer.Source.deepSearch(rootFolderURLs: rootFolderURLs, archivePattern: archivePattern)
			let dsymSymbolizer = try DSYMSymbolizer.symbolizer(forCrashReport: crashReport!, source: source)
			self.symbolizer = CachingSymbolizer(wrappedSymbolizer: dsymSymbolizer)
			updateContentView()
		} catch let error {
			Self.reportError(error, crashReport: crashReport!)
		}
	}
	
	static var alreadyReportedErrors = Set<String>()
	static func reportError(_ error: Error, crashReport: PLCrashReport)
	{
		// NOTE: only report once, suppress error for multiple documents
		//       (for example when restoring session with multiple documents)
		let version = "\(crashReport.applicationInfo.applicationIdentifier!) build \(crashReport.applicationInfo.applicationVersion!)"
		if alreadyReportedErrors.contains(version) { return }
		else { alreadyReportedErrors.insert(version) }
		
		let alert = NSAlert(error: error)
		alert.messageText =
			"""
			Unable to locate the dSYM file for \(version).\n
			Please check the root folder configured in the user preferences
			"""
		if let rootFolder = UserDefaults.standard.string(forKey: PreferenceWindowController.DSymRootFolderListKey) {
			alert.messageText += ":\n\(rootFolder)"
		}
		alert.addButton(withTitle: "Open Preferences")
		alert.addButton(withTitle: "Cancel")
		let response = alert.runModal()
		if response == .alertFirstButtonReturn {
			DispatchQueue.main.async {
				PreferenceWindowController.sharedController.showWindow(self)
			}
		}
	}
	
	override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
		contentView.font = NSFont.userFixedPitchFont(ofSize: 11)
		contentView.enclosingScrollView!.hasHorizontalScroller = true
		contentView.enclosingScrollView!.hasVerticalScroller = true
		contentView.enclosingScrollView!.autohidesScrollers = true
		contentView.isHorizontallyResizable = true
		contentView.isVerticallyResizable = true
		contentView.maxSize = CGSize(width: 1000000, height: 1000000)
		contentView.textContainer!.widthTracksTextView = false
		contentView.textContainer!.heightTracksTextView = false
		contentView.textContainer!.size = CGSize(width: 1000000, height: 1000000)
		updateContentView()
		contentView.enclosingScrollView!.isHidden = true
		super.windowControllerDidLoadNib(windowController)
	}
	
	// MARK: - IB Actions
	
	@IBAction func copy(_ sender: Any?) {
		let selectedItems = threadsView.selectedRowIndexes.compactMap { threadsView.item(atRow: $0) }

		let pb = NSPasteboard.general
		pb.clearContents()
		guard ((threadsView.dataSource?.outlineView?(threadsView, writeItems: selectedItems, to: pb)) != nil)
		else { NSSound.beep(); return }
	}
}

