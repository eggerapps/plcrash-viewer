//
//  CrashReportReader.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.08.19.
//  Copyright © 2019 Egger Apps. All rights reserved.
//

import Foundation
import zlib

enum CrashReportReaderError: CustomNSError
{
	case maximumFileSizeExceeded(byteCount: Int)
	case corrupted
	case uncompressFailure(zlibResult: Int32)
	
    static var errorDomain: String { "at.eggerapps.PLCrash-Viewer" }
	
	public var errorUserInfo: [String : Any] {
		switch self {
		case .maximumFileSizeExceeded(let byteCount):
			return [NSLocalizedDescriptionKey: "Uncompressed crash report to big",
					NSLocalizedRecoverySuggestionErrorKey: "Maximum uncompressed size is \(byteCount) bytes."]
			
		case .corrupted:
			return [NSLocalizedDescriptionKey: "Compressed crash report corrupted",
					NSLocalizedRecoverySuggestionErrorKey: "The zlib stream was corrupted"]
			
		case .uncompressFailure(let zlibResult):
			return [NSLocalizedDescriptionKey: "Crash report could not be uncompressed",
					NSLocalizedRecoverySuggestionErrorKey: "uncompress() returned \(zlibResult)"]

		}
	}
}

class CompressedCrashReportReader
{
	static func read(from data: Data, ofType typeName: String) throws -> BITPLCrashReport
	{
		if data.prefix(7) == "zplcrsh".data(using: .utf8) {
			let compressedBytes = [UInt8](data.advanced(by: 7))
			var uncompressedBytes = [UInt8](repeating: 0, count: 1024*1024)
			var uncompressedLength: UInt = UInt(uncompressedBytes.count)
			let zlibResult = uncompress(&uncompressedBytes, &uncompressedLength, compressedBytes, UInt(compressedBytes.count))
			guard zlibResult == Z_OK else {
				if zlibResult == Z_BUF_ERROR { throw CrashReportReaderError.maximumFileSizeExceeded(byteCount: uncompressedBytes.count) }
				if zlibResult == Z_DATA_ERROR { throw CrashReportReaderError.corrupted }
				throw CrashReportReaderError.uncompressFailure(zlibResult: zlibResult)
			}
			let uncompressedData = Data(bytes: uncompressedBytes, count: Int(uncompressedLength))
			return try read(from: uncompressedData, ofType: typeName)
		}
        return try BITPLCrashReport(data: data)
	}

}
