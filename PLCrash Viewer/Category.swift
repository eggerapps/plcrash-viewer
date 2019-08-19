//
//  Category.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.08.19.
//  Copyright © 2019 Egger Apps. All rights reserved.
//

import Foundation

class Category: SidebarItem
{
	// MARK: - SidebarItem protocol
	
	let isExpandable = true
	
	var children: [CrashReport] { reports }
	
	var name: String
	
	// MARK: - Properties
	
	var reports = [CrashReport]()
	
	// MARK: - Initializer
	
	public init(name: String) {
		self.name = name
	}
	
	// MARK: - Equatable
	
	static func == (lhs: Category, rhs: Category) -> Bool {
		return lhs.name == rhs.name
	}

	// MARK: - Hashable
	
	public func hash(into h: inout Hasher) {
		h.combine(name)
	}
}
