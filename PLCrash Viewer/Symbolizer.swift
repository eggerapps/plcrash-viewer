//
//  Symbolizer.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 16.09.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation

enum SymbolizerError: String, LocalizedError
{
	case missingApplicationVersion
	case dSymRootFolderKeyMissing
	case archiveFilePatternKeyMissing
	case xcarchiveFileNotFound
	case xcarchiveFileNotUnzippable
	case xcarchiveDoesNotContainDSYM
	case atosOutputNotReadable
	case couldntReadArchitecturesInDSYM
	case dsymFileNotFound
	case unexpectedNumberOfArchitecturesInDSYM
	case imageUUIDNotFoundInDSYM
	
	var errorDescription: String? {
		rawValue
	}
}

protocol Symbolizer
{
	func symbolize(imageUUID: UUID, imageLoadAddress: UInt64, stackAddresses: [UInt64]) throws -> [String]
}
