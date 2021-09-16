//
//  Symbolizer.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 16.09.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation

enum SymbolizerError: CustomNSError
{
	case missingBuildNumber
	case dSymRootFolderKeyMissing
	case archiveFilePatternKeyMissing
	case xcarchiveFileNotFound
	case xcarchiveFileNotUnzippable
	case xcarchiveDoesNotContainDSYM
	case atosOutputNotReadable
}

protocol Symbolizer
{
	func symbolize(imageLoadAddress: UInt64, stackAddresses: [UInt64]) throws -> [String]
}
