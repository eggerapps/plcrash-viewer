//
//  CrashReport.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 22.10.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation
import zlib

public func uncompressCrashReport(data: Data) throws -> Data {
	func uncompress(data compressedData: Data) throws -> Data {
		let compressedBytes = [UInt8](compressedData)
		var uncompressedBytes = [UInt8](repeating: 0, count: 1024*1024)
		var uncompressedLength: UInt = UInt(uncompressedBytes.count)
		let zlibResult = zlib.uncompress(&uncompressedBytes, &uncompressedLength, compressedBytes, UInt(compressedBytes.count))
		guard zlibResult == Z_OK else {
			if zlibResult == Z_BUF_ERROR { throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Uncompressed crash report to big", NSLocalizedRecoverySuggestionErrorKey: "Maximum uncompressed size is \(uncompressedBytes.count) bytes."]) }
			if zlibResult == Z_DATA_ERROR { throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Compressed crash report corrupted", NSLocalizedRecoverySuggestionErrorKey: "The zlib stream was corrupted"]) }
			throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Crash report could not be uncompressed", NSLocalizedRecoverySuggestionErrorKey: "uncompress() returned \(zlibResult)"])
		}
		let uncompressedData = Data(bytes: uncompressedBytes, count: Int(uncompressedLength))
		return uncompressedData
	}
	
	let prefix = data.prefix(7)
	if prefix == "zplcrsh".data(using: .utf8) ||
	   prefix == "zplhang".data(using: .utf8)
	{
		return try uncompress(data: data.advanced(by: 7))
	}
	if prefix == "DIAGNOS".data(using: .utf8)
	{
		guard let range = data.range(of: "\n\n".data(using: .utf8)!) else {
			throw NSError(domain: "at.eggerapps.PLCrash-Viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Diagnostic file has invalid header"])
		}
		return try uncompress(data: data.suffix(from: range.endIndex))
	}
	return data
}

