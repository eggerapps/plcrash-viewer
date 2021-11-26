//
//  Symbolizer.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.12.18.
//  Copyright © 2018 Egger Apps. All rights reserved.
//

import Foundation
import Cocoa

class DSYMSymbolizer: Symbolizer
{
	enum Source {
		case deepSearch(rootFolderURLs: [URL], archivePattern: String)
		case url(URL)
	}
	
	// MARK: - Factory Method
	
	private static var sharedSymbolizersByBuildNumber = [String : DSYMSymbolizer]()
	private static var didAlreadyReportError = false
	
	private class func deepSearchURL(buildNumber: String,
									 rootFolderURLs: [URL],
									 archivePattern: String) throws -> URL
	{
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
		return dsymArchive
	}
	
	public class func symbolizer(forCrashReport crashReport: PLCrashReport,
								 source: Source) throws -> DSYMSymbolizer
	{
		guard let buildNumber = crashReport.applicationInfo.applicationVersion else {
			throw SymbolizerError.missingBuildNumber
		}
		
		if let instance = sharedSymbolizersByBuildNumber[buildNumber] {
			return instance
		}
		
		let url: URL
		switch source {
			case .url(let u):
				url = u
			
			case .deepSearch(let rootFolderURLs, let archivePattern):
				url = try deepSearchURL(buildNumber: buildNumber,
										rootFolderURLs: rootFolderURLs,
										archivePattern: archivePattern)
		}
		
		let instance = try DSYMSymbolizer(dsymURL: url)
		sharedSymbolizersByBuildNumber[buildNumber] = instance
		return instance
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
	
	private let archForUUID: [UUID:String]
	
	public init(dsymURL: URL) throws { // NOTE: for UI app, please use factory method symbolizer(forCrashReport:)
		self.dsymURL = dsymURL
		
		let pipe = Pipe()
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/dwarfdump")
		process.arguments = ["-u", dsymURL.path]
		process.standardOutput = pipe
		try process.run()
		let resultData = pipe.fileHandleForReading.readDataToEndOfFile()
		guard let output = String(data: resultData, encoding: .utf8) else { throw SymbolizerError.couldntReadArchitecturesInDSYM }
		var archForUUID = [UUID:String]()
		let scanner = Scanner(string: output)
		while true {
			guard let _ = scanner.scanString("UUID:") else { break }
			guard let uuid_str = scanner.scanCharacters(from: CharacterSet(charactersIn: "0123456789ABCDEFabcdef-")) else { break }
			guard let uuid = UUID(uuidString: uuid_str) else { break }
			guard let _ = scanner.scanString("(") else { break }
			guard let arch = scanner.scanUpToString(")") else { break }
			archForUUID[uuid] = arch
			_ = scanner.scanUpToCharacters(from: .newlines)
			_ = scanner.scanCharacters(from: .newlines)
		}
		guard archForUUID.count == 2 else {
			throw SymbolizerError.unexpectedNumberOfArchitecturesInDSYM
		}
		self.archForUUID = archForUUID
	}
	
	public func symbolize(imageUUID: UUID, imageLoadAddress: UInt64, stackAddresses: [UInt64]) throws -> [String] {
		let pipe = Pipe()
		guard let arch = archForUUID[imageUUID] else { throw SymbolizerError.imageUUIDNotFoundInDSYM }
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/atos")
		process.arguments = ["-o", dsymURL.path,
							 "-arch", arch,
							 "-l", String(format:"0x%2X", imageLoadAddress)] +
							stackAddresses.map { String(format:"0x%2X", $0) }
		process.standardOutput = pipe
		try process.run()
		
		let resultData = pipe.fileHandleForReading.readDataToEndOfFile()
		guard let output = String(data: resultData, encoding: .utf8)
			else { throw SymbolizerError.atosOutputNotReadable }
		var results = [String]()
		output.enumerateLines { line, _ in
			results.append(line.replacingOccurrences(of: " (in \(self.dsymURL.lastPathComponent))", with: ""))
		}
		return results
	}
}

extension PLCrashReportBinaryImageInfo {
	var uuid: UUID? {
		guard var uuidstr = imageUUID else {
			return nil
		}
		if let uuid = UUID(uuidString: uuidstr) {
			return uuid
		}
		guard uuidstr.count == 32 else {
			return nil
		}
		var index = uuidstr.index(uuidstr.startIndex, offsetBy: 8)
		for _ in 1...4 {
			uuidstr.insert("-", at: index)
			index = uuidstr.index(index, offsetBy: 5)
		}
		if let uuid = UUID(uuidString: uuidstr) {
			return uuid
		}
		return nil
	}
}
