//
//  CrashReport.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.08.19.
//  Copyright © 2019 Egger Apps. All rights reserved.
//

import Foundation

class CrashReport: SidebarItem
{
	class ThreadStack {
		typealias ID = Int
		let id: ID
		let imageLoadAddress: UInt64
		let stackAddresses: [UInt64]
		
		var stackSymbols = [String]()
		
		public init (id: ID, imageLoadAddress: UInt64, stackAddresses: [UInt64]) {
			self.id = id
			self.imageLoadAddress = imageLoadAddress
			self.stackAddresses = stackAddresses
		}
	}
	
	// MARK: - Properties
	
	let bitplReport: BITPLCrashReport

	let stacks = [ThreadStack.ID : ThreadStack]()
	
	var uuid: UUID { bitplReport.uuidRef as! UUID }
	
	// MARK: - Initializers
	
	public init(bitplReport: BITPLCrashReport) {
		self.bitplReport = bitplReport
	}
	
	// MARK: - Equatable
	
	static func == (lhs: CrashReport, rhs: CrashReport) -> Bool {
		return lhs.uuid == rhs.uuid
	}

	// MARK: - Hashable
	
	public func hash(into h: inout Hasher) {
		h.combine(uuid)
	}

	// MARK: - SidebarItem protocol
	
	let isExpandable = false
	let children: [CrashReport] = []
	
	var name: String {
		return (bitplReport.uuidRef as! UUID).uuidString
	}

}
