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

	override func read(from data: Data, ofType typeName: String) throws {
		let prefix = data.prefix(7)
		if prefix == "zplcrsh".data(using: .utf8) ||
		   prefix == "zplhang".data(using: .utf8)
		{
			return try read(fromCompressedData: data.advanced(by: 7), ofType: typeName)
		}
		if prefix == "DIAGNOS".data(using: .utf8)
		{
			guard let range = data.range(of: "\n\n".data(using: .utf8)!) else {
				throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Diagnostic file has invalid header"])
			}
			return try read(fromCompressedData: data.suffix(from: range.endIndex), ofType: typeName)
		}
        crashReport = try BITPLCrashReport(data: data)
		updateContentView()
	}
	
	func read(fromCompressedData compressedData: Data, ofType typeName: String) throws {
		let compressedBytes = [UInt8](compressedData)
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

