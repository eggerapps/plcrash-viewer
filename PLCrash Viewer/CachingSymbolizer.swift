//
//  CachingSymbolizer.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 16.09.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation

class CachingSymbolizer: Symbolizer
{
	private var wrappedSymbolizer: Symbolizer
	private struct CacheKey: Hashable {
		var imageUUID: UUID
		var imageLoadAddress: UInt64
		var stackAddress: UInt64
	}
	private var cache = [CacheKey: String]()
	
	init(wrappedSymbolizer: Symbolizer) {
		self.wrappedSymbolizer = wrappedSymbolizer
	}
	
	func symbolize(imageUUID: UUID, imageLoadAddress: UInt64, stackAddresses: [UInt64]) throws -> [String]
	{
		var symbols = [String]()
		var missingAddresses = [(Int, UInt64)]() // patch later
		for (idx, address) in stackAddresses.enumerated() {
			let key = CacheKey(imageUUID: imageUUID, imageLoadAddress: imageLoadAddress, stackAddress: address)
			if let symbol = cache[key] {
				symbols.append(symbol)
			} else {
				missingAddresses.append((idx, address))
				symbols.append("") // placeholder
			}
		}
		if !missingAddresses.isEmpty {
			let resolvedSymbols = try wrappedSymbolizer.symbolize(imageUUID: imageUUID, imageLoadAddress: imageLoadAddress, stackAddresses: missingAddresses.map { $0.1 } )
			for (i, symbol) in resolvedSymbols.enumerated() {
				let fixupIdx = missingAddresses[i].0
				symbols[fixupIdx] = symbol
				
				let cacheKey = CacheKey(imageUUID: imageUUID, imageLoadAddress: imageLoadAddress, stackAddress: missingAddresses[i].1)
				cache[cacheKey] = symbol
			}
		}
		return symbols
	}
}
