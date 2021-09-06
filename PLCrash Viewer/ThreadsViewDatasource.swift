//
//  ThreadsViewDatasource.swift
//  PLCrash Viewer
//
//  Created by Jakob Egger on 2018-12-07.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Cocoa

class ThreadsViewDatasource: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {
	
	// MARK: - Properties
	
	let crashReport: BITPLCrashReport
	let symbolizer: Symbolizer?
	
	// MARK: - Initializer
	
	init(crashReport: BITPLCrashReport, symbolizer: Symbolizer?) {
		self.crashReport = crashReport
		self.symbolizer = symbolizer
	}
	
	// MARK: - NSOutlineViewDataSource

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if let item = item {
			if let thread = item as? BITPLCrashReportThreadInfo {
				return thread.stackFrames.count
			}
			if let exceptionInfo = item as? BITPLCrashReportExceptionInfo {
				return exceptionInfo.stackFrames.count
			}
			else {
				return 0
			}
		} else {
			return crashReport.threads.count + (crashReport.exceptionInfo != nil ? 1 : 0) 
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			if let exceptionInfo = crashReport.exceptionInfo {
				if index == 0 {
					return exceptionInfo
				} else {
					return crashReport.threads[index-1]
				}
			} else {
				return crashReport.threads[index]
			}
		}
		if let thread = item as? BITPLCrashReportThreadInfo {
			return thread.stackFrames[index]
		}
		if let exceptionInfo = item as? BITPLCrashReportExceptionInfo {
			return exceptionInfo.stackFrames[index]
		}
		fatalError("Invalid Item in Outline View")
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if item is BITPLCrashReportThreadInfo { return true }
		if item is BITPLCrashReportExceptionInfo { return true }
		return false
	}
	
	private func symbolName(for stackFrame: BITPLCrashReportStackFrameInfo) -> String {
		let symbolInfo = stackFrame.symbolInfo
		var symbolName = symbolInfo?.symbolName ?? "???"

		let address = stackFrame.instructionPointer - 1

		if let image = crashReport.images.first as? BITPLCrashReportBinaryImageInfo,
		   image.imageBaseAddress ..< (image.imageBaseAddress + image.imageSize) ~= address,
		   let symbols = try? symbolizer?.symbolize(imageLoadAddress: image.imageBaseAddress,
													stackAddresses: [address])
		{
			symbolName = symbols?.first ?? "???"
		}
		return symbolName
	}
	
	private func instructionPointer(for stackFrame: BITPLCrashReportStackFrameInfo) -> String {
		NSString(format: "0x%x", stackFrame.instructionPointer) as String
	}
	
	private func imageName(for stackFrame: BITPLCrashReportStackFrameInfo) -> String {
		var imageName = "???"
		for image in crashReport.images as! [BITPLCrashReportBinaryImageInfo] {
			if image.imageBaseAddress <= stackFrame.instructionPointer && stackFrame.instructionPointer < image.imageBaseAddress + image.imageSize {
				imageName = (image.imageName as NSString?)?.lastPathComponent ?? "???"
			}
		}
		return imageName
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		guard let identifier = tableColumn?.identifier else { fatalError("No Identifier!") }
		let view = outlineView.makeView(withIdentifier: identifier, owner: nil)
		guard let tableCellView = view as? NSTableCellView else { fatalError("Unexpected View") }
		let stringValue: String
		if let thread = item as? BITPLCrashReportThreadInfo {
			if identifier == NSUserInterfaceItemIdentifier(rawValue: "#") { 
				stringValue = "Thread \(thread.threadNumber)"
				tableCellView.textField?.alignment = .left
			} else {
				stringValue = ""
			}
		}
		else if let stackFrame = item as? BITPLCrashReportStackFrameInfo {
			if identifier == NSUserInterfaceItemIdentifier(rawValue: "#") { 
				stringValue = "#\(outlineView.childIndex(forItem: item))"
				tableCellView.textField?.alignment = .right
			}
			else if identifier == NSUserInterfaceItemIdentifier(rawValue: "SymbolName") {
				stringValue = symbolName(for: stackFrame)
			}
			else if identifier == NSUserInterfaceItemIdentifier(rawValue: "InstructionPointer") {
				stringValue = instructionPointer(for: stackFrame)
			}
			else if identifier == NSUserInterfaceItemIdentifier(rawValue: "ImageName") {
				stringValue = imageName(for: stackFrame)
			}
			else if identifier == NSUserInterfaceItemIdentifier(rawValue: "ImageLoadAddress") {
				stringValue = ""
			} else {
				stringValue = ""
			}
		}
		else if let exception = item as? BITPLCrashReportExceptionInfo {
			if identifier == NSUserInterfaceItemIdentifier(rawValue: "#") { 
				stringValue = exception.exceptionName ?? "Exception"
			}
			else if identifier == NSUserInterfaceItemIdentifier(rawValue: "SymbolName") {
				stringValue = exception.exceptionReason ?? "???"
			}
			else {
				stringValue = ""
			}
		}
		else {
			fatalError("Unexpected item: \(item)")
		}
		tableCellView.textField!.stringValue = stringValue
		return tableCellView
	}
	
	func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool
	{
		func padString(_ string: String, _ length: Int) -> String {
			return string.padding(toLength: length,
								  withPad: " ",
								  startingAt: 0)
		}
		
		let headerCells = ["THREAD", "FRAME", "IMAGE", "INSTRUCTION POINTER", "SYMBOL NAME"]
		var maxCellLength = headerCells.map { $0.count }
		
		var rows = [ headerCells ]
		
		for item in items {
			guard !(item is BITPLCrashReportThreadInfo) else {
				continue
			}
			var row = [String]()
			
			if let stackFrame = item as? BITPLCrashReportStackFrameInfo {
				guard let parent = outlineView.parent(forItem: item) else { continue }
				
				if let thread = parent as? BITPLCrashReportThreadInfo {
					row.append("\(thread.threadNumber)")
				}
				
				row.append("#\(outlineView.childIndex(forItem: item))")
				row.append(imageName(for: stackFrame))
				row.append(instructionPointer(for: stackFrame))
				row.append(symbolName(for: stackFrame))
			}
			else if let exception = item as? BITPLCrashReportExceptionInfo {
				row.append(exception.exceptionName ?? "Exception")
				row.append("")
				row.append("")
				row.append(exception.exceptionReason ?? "???")
			}
			else {
				fatalError("Unexpected item: \(item)")
			}
			
			for (i, cell) in row.enumerated() {
				if maxCellLength[i] < cell.count {
					maxCellLength[i] = cell.count
				}
			}
			
			let padCount = headerCells.count - row.count
			row.append(contentsOf: Array(repeating: "", count: padCount))
			rows.append(row)
		}
		
		var clip = ""
		for i in 0 ..< rows.count {
			for j in 0 ..< headerCells.count {
				rows[i][j] = padString(rows[i][j], maxCellLength[j])
			}
			clip += rows[i].joined(separator: "\t") + "\n"
		}
		
		pasteboard.setString(clip, forType: .string)
		return true
	}
}
