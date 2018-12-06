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
	
	var formattedReport = ""
	
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

	override func read(from data: Data, ofType typeName: String) throws {
		let cr = try BITPLCrashReport(data: data)
		let formatter = BITPLCrashReportTextFormatter(textFormat: PLCrashReportTextFormatiOS, stringEncoding: String.Encoding.utf8.rawValue)!
		let formattedReportData = try formatter.formatReport(cr)
		formattedReport = String(bytes: formattedReportData, encoding: .utf8)!
		if let contentView = contentView { contentView.string = formattedReport }
	}

	override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
		contentView.string = formattedReport
		contentView.font = NSFont.userFixedPitchFont(ofSize: 11)
		contentView.enclosingScrollView!.hasHorizontalScroller = true
		contentView.textContainer!.widthTracksTextView = false
		contentView.textContainer!.size = CGSize(width: 1000000, height: 1000000)
		super.windowControllerDidLoadNib(windowController)
	}
}

