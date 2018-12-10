//
//  Document.swift
//  PLCrash Viewer
//
//  Created by Jakob Egger on 06.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Cocoa
import zlib

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
		if data.prefix(7) == "zplcrsh".data(using: .utf8) {
			let compressedBytes = [UInt8](data.advanced(by: 7))
			var uncompressedBytes = [UInt8](repeating: 0, count: 1024*1024)
			var uncompressedLength: UInt = UInt(uncompressedBytes.count)
			let zlibResult = uncompress(&uncompressedBytes, &uncompressedLength, compressedBytes, UInt(compressedBytes.count))
			guard zlibResult == Z_OK else {
				if zlibResult == Z_BUF_ERROR { throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Uncompressed crash report to big", NSLocalizedRecoverySuggestionErrorKey: "Maximum uncompressed size is \(uncompressedBytes.count) bytes."]) }
				if zlibResult == Z_DATA_ERROR { throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Compressed crash report corrupted", NSLocalizedRecoverySuggestionErrorKey: "The zlib stream was corrupted"]) }
				throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Crash report could not be uncompressed", NSLocalizedRecoverySuggestionErrorKey: "uncompress() returned \(zlibResult)"])
			}
			let uncompressedData = Data(bytes: uncompressedBytes, count: Int(uncompressedLength))
			return try read(from: uncompressedData, ofType: typeName)
		}
		let cr = try BITPLCrashReport(data: data)
		let formatter = BITPLCrashReportTextFormatter(textFormat: PLCrashReportTextFormatiOS, stringEncoding: String.Encoding.utf8.rawValue)!
		let formattedReportData = try formatter.formatReport(cr)
		formattedReport = String(bytes: formattedReportData, encoding: .utf8)!
		if let contentView = contentView { contentView.string = formattedReport }
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
		contentView.string = formattedReport
		super.windowControllerDidLoadNib(windowController)
	}
}

