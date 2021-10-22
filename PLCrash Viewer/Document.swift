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
	
	var crashReport: BITPLCrashReport?
	var threadsViewDatasource: ThreadsViewDatasource?
	var symbolizer: Symbolizer?
	
	func updateContentView() {
		if let contentView = contentView {
			if let crashReport = crashReport {
				contentView.string = BITPLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS)
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
					for thread in crashReport.threads as! [BITPLCrashReportThreadInfo] {
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
        crashReport = try BITPLCrashReport(data: data)
		updateContentView()
	}
	
	@IBAction func symbolize(_: Any?) {
		do {
			let dsymSymbolizer = try DSYMSymbolizer.symbolizer(forCrashReport: crashReport!)
			self.symbolizer = CachingSymbolizer(wrappedSymbolizer: dsymSymbolizer)
			updateContentView()
		} catch let error {
			DSYMSymbolizer.reportError(error, crashReport: crashReport!)
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

