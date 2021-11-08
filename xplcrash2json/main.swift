//
//  main.swift
//  xplcrash2json
//
//  Created by Martin Köhler on 22.10.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation
import PLCrash_Viewer

let args = parseArguments()

let crashReport: BITPLCrashReport
do {
	let data = try uncompressCrashReport(data: args.read())
	crashReport = try BITPLCrashReport(data: data)
} catch let error {
	fputs("Failed to parse crash report: \(error.localizedDescription)\n", stderr)
	exit(1)
}

guard let buildNumber = crashReport.applicationInfo.applicationVersion else {
	fputs("Failed to extract build number from crash report\n", stderr)
	exit(1)
}

let dsymURL: URL = args.dsymURL(for: buildNumber)

let symbolizer: Symbolizer
do {
	let dsymSymbolizer = try DSYMSymbolizer.symbolizer(forCrashReport: crashReport, source: .url(dsymURL))
	symbolizer = CachingSymbolizer(wrappedSymbolizer: dsymSymbolizer)
} catch let error {
	fputs("Failed to create Symbolizer: \(error.localizedDescription)\n", stderr)
	exit(1)
}

let json: Data
do {
	json = try jsonDump(args: args, crashReport: crashReport, symbolizer: symbolizer)
} catch let error {
	fputs("Failed to dump crash report: \(error.localizedDescription)\n", stderr)
	exit(1)
}

args.write(json)
