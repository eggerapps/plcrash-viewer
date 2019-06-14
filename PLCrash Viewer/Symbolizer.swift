//
//  Symbolizer.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Foundation
import Cocoa

public enum SymbolizerError: CustomNSError
{
	case missingBuildNumber
	case dSymRootFolderKeyMissing
	case archiveFilePatternKeyMissing
	case xcarchiveFileNotFound
	case xcarchiveFileNotUnzippable
	case xcarchiveDoesNotContainDSYM
	case atosOutputNotReadable
}

public class Symbolizer
{
	// MARK: - Factory Method
	
	private static var sharedSymbolizersByBuildNumber = [String : Symbolizer]()
	private static var didAlreadyReportError = false
	
	public class func symbolizer(forCrashReport crashReport: BITPLCrashReport) throws -> Symbolizer
	{
		guard let buildNumber = crashReport.applicationInfo.applicationVersion else {
			throw SymbolizerError.missingBuildNumber
		}
		
		if let instance = sharedSymbolizersByBuildNumber[buildNumber] {
			return instance
		}
		
		guard let rootFolders = UserDefaults.standard.stringArray(forKey: PreferenceWindowController.DSymRootFolderListKey)
			else { throw SymbolizerError.dSymRootFolderKeyMissing }
		guard let archivePattern = UserDefaults.standard.string(forKey: PreferenceWindowController.ArchiveFilePatternKey)
			else { throw SymbolizerError.archiveFilePatternKeyMissing }
		
		let rootFolderURLs = rootFolders.map { URL(fileURLWithPath: $0) }
		
		for rootFolderURL in rootFolderURLs {
			let v = try rootFolderURL.resourceValues(forKeys: [.isDirectoryKey, .canonicalPathKey])
			guard v.isDirectory == true else { throw SymbolizerError.dSymRootFolderKeyMissing }
		}
		
		var unzippedXCArchive: URL

		let rankBoostPattern = try! NSRegularExpression(pattern: ".*\(buildNumber).*")
		
		let expectedFilename = renderExpectedFilename(pattern: archivePattern,
													  placeholders: [ "$BUILD": buildNumber ])
		if expectedFilename.hasSuffix(".zip") {
			// NOTE: first see if it a decompressed xcarchive is already present
			var unzippedFilename = expectedFilename
			unzippedFilename.removeLast(4)
			if let xcArchive = findFile(rootFolders: rootFolderURLs,
										expectedFileName: unzippedFilename,
										rankBoostPattern: rankBoostPattern)
			{
				unzippedXCArchive = xcArchive
			} else {
				// NOTE: zip has to be expanded
				guard let xcArchive = findFile(rootFolders: rootFolderURLs,
											   expectedFileName: expectedFilename,
											   rankBoostPattern: rankBoostPattern)
				else {
					throw SymbolizerError.xcarchiveFileNotFound
				}
				
				let destinationFolder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PLCrashViewer")
				guard unzipFile(at: xcArchive.path, to: destinationFolder.path) else {
					throw SymbolizerError.xcarchiveFileNotUnzippable
				}
				
				let name = xcArchive.deletingPathExtension().lastPathComponent
				unzippedXCArchive = destinationFolder.appendingPathComponent(name)
			}
		} else {
			guard let xcArchive = findFile(rootFolders: rootFolderURLs,
										   expectedFileName: expectedFilename,
										   rankBoostPattern: rankBoostPattern)
			else {
				throw SymbolizerError.xcarchiveFileNotFound
			}
			unzippedXCArchive = xcArchive
		}
		
		var dsymArchive = unzippedXCArchive.appendingPathComponent("dSYMs")
		guard let content1 = (try? FileManager.default.contentsOfDirectory(atPath: dsymArchive.path))?.first else {
			throw SymbolizerError.xcarchiveDoesNotContainDSYM
		}
		dsymArchive = dsymArchive
						.appendingPathComponent(content1)
						.appendingPathComponent("Contents")
						.appendingPathComponent("Resources")
						.appendingPathComponent("DWARF")
		guard let content2 = (try? FileManager.default.contentsOfDirectory(atPath: dsymArchive.path))?.first else {
			throw SymbolizerError.xcarchiveDoesNotContainDSYM
		}
		dsymArchive = dsymArchive.appendingPathComponent(content2)

		let instance = Symbolizer(dsymURL: dsymArchive)
		sharedSymbolizersByBuildNumber[buildNumber] = instance
		return instance
	}
	
	public class func reportError(_ error: Error, crashReport: BITPLCrashReport)
	{
		// NOTE: only report once, suppress error for multiple documents
		//       (for example when restoring session with multiple documents)
		if didAlreadyReportError { return }
		else { didAlreadyReportError = true }
		
		let alert = NSAlert(error: error)
		alert.messageText =
			"""
			Unable to locate the dSYM file for \(crashReport.applicationInfo.applicationIdentifier!) build \(crashReport.applicationInfo.applicationVersion!).\n
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
	
	// MARK: - Helper Methods
	
	private class func renderExpectedFilename(pattern: String,
											  placeholders: [String: CustomStringConvertible]) -> String
	{
		var result = pattern
		for (placeholder, replacement) in placeholders {
			result = result.replacingOccurrences(of: placeholder, with: replacement.description)
		}
		return result
	}
	
	private class func findFile(rootFolders: [URL],
								expectedFileName: String,
								rankBoostPattern: NSRegularExpression) -> URL?
	{
		// NOTE: we won't slowly descend into expanded Postico.apps
		let blacklistedExtensions = Set<String>(["app", "framework"])

		var folders = rootFolders
		while let folder = folders.popLast() {
			if let contents = try? FileManager.default.contentsOfDirectory(atPath: folder.path) {
				let rankedContents = contents.sorted { (a, b) -> Bool in
					let aIsMatch = rankBoostPattern.rangeOfFirstMatch(in: a, options: [],
																	  range: NSMakeRange(0, (a as NSString).length)).length > 0
					let bIsMatch = rankBoostPattern.rangeOfFirstMatch(in: b, options: [],
																	  range: NSMakeRange(0, (b as NSString).length)).length > 0
					if aIsMatch && !bIsMatch { return true }
					return false
				}
				for c in rankedContents {
					let url = folder.appendingPathComponent(c)
					guard let rv = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]) else { continue }
					if c == expectedFileName {
						return url
					} else if rv.isDirectory == true,
						      !blacklistedExtensions.contains(url.pathExtension)
					{
						folders.insert(url, at: 0)
					}
				}
			}
		}
		
		return nil
	}
	
	private class func unzipFile(at sourcePath: String, to destinationPath: String) -> Bool
	{
		// TODO: only extract dSYM
		
		let process = Process.launchedProcess(launchPath: "/usr/bin/unzip",
											  arguments: ["-o", sourcePath, "-d", destinationPath])
		process.waitUntilExit()
		return process.terminationStatus <= 1
	}
	
	// MARK: - Initializer
	
	private let dsymURL: URL
	
	private init(dsymURL: URL) {
		self.dsymURL = dsymURL
	}
	
	public func symbolize(imageLoadAddress: UInt64, stackAddresses: [UInt64]) throws -> [String] {
		let pipe = Pipe()
		
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/atos")
		process.arguments = ["-o", dsymURL.path,
							 "-l", String(format:"0x%2X", imageLoadAddress)] +
							stackAddresses.map { String(format:"0x%2X", $0) }
		process.standardOutput = pipe
		try process.run()
		
		let resultData = pipe.fileHandleForReading.readDataToEndOfFile()
		guard let output = String(data: resultData, encoding: .utf8)
			else { throw SymbolizerError.atosOutputNotReadable }
		var results = [String]()
		output.enumerateLines { line, _ in
			results.append(line)
		}
		return results
	}
}
