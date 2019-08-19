//
//  CrashReportViewController.swift
//  PLCrash Viewer
//
//  Created by Martin Köhler on 19.08.19.
//  Copyright © 2019 Egger Apps. All rights reserved.
//

import Cocoa

class CrashReportViewController: NSViewController
{
	// MARK: - Properties
	
	@IBOutlet var contentView: NSTextView!
	@IBOutlet weak var threadsView: NSOutlineView!
	
	private var crashReport: BITPLCrashReport?
	private var threadsViewDatasource: ThreadsViewDatasource?
	private var symbolizer: Symbolizer?
	
	// MARK: - NSViewController overrides
	
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
		
		contentView.font = NSFont.userFixedPitchFont(ofSize: 11)
		contentView.enclosingScrollView!.hasHorizontalScroller = true
		contentView.enclosingScrollView!.hasVerticalScroller = true
		contentView.enclosingScrollView!.autohidesScrollers = true
		contentView.isHorizontallyResizable = true
		contentView.isVerticallyResizable = true
		contentView.maxSize = CGSize(width: 1000000, height: 1000000)
		contentView.textContainer!.widthTracksTextView = false
		contentView.textContainer!.heightTracksTextView = false
		contentView.textContainer!.size = CGSize(width: 1000000, height: 1000000)
		updateContentView()
		contentView.enclosingScrollView!.isHidden = true
    }
	
	override var nibName: NSNib.Name? { "CrashReportView" }

	// MARK: - Actions
	
	@IBAction func selectDisplayMode(_ sender: NSSegmentedControl) {
		threadsView.enclosingScrollView!.isHidden = (sender.selectedSegment != 0)
		contentView.enclosingScrollView!.isHidden = (sender.selectedSegment != 1)
	}

	func updateContentView() {
		if let contentView = contentView {
			if let crashReport = crashReport {
				contentView.string = BITPLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS)
			} else {
				contentView.string = ""
			}
		}
		if let threadsView = threadsView {
			if let crashReport = crashReport {
				threadsViewDatasource = ThreadsViewDatasource(crashReport: crashReport)
			} else {
				threadsViewDatasource = nil
			}
			threadsView.dataSource = threadsViewDatasource
			threadsView.delegate = threadsViewDatasource
			threadsView.reloadData()
			if let crashReport = crashReport {
				if let e = crashReport.exceptionInfo {
					threadsView.expandItem(e)
				} else {
					for thread in crashReport.threads as! [BITPLCrashReportThreadInfo] {
						if thread.crashed {
							threadsView.expandItem(thread)
						}
					}
				}
			}
		}
	}
	
}
