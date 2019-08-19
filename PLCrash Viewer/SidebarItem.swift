//
//  SidebarItem.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.08.19.
//  Copyright © 2019 Egger Apps. All rights reserved.
//

import Foundation

protocol SidebarItem: Hashable
{
	associatedtype ChildType: SidebarItem
	
	var name: String { get }
	var isExpandable: Bool { get }
	var children: [ChildType] { get }
}
