//
//  Arguments.swift
//  xplcrash2json
//
//  Created by Martin Köhler on 22.10.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation

struct Arguments {
	static let DefaultPlaceholder = "{CFBundleVersion}"
	
	let symbolPathPattern: String
	let placeholder: String
	
	let read: () -> Data
	let write: (Data) -> ()
}

func printUsage() {
	fputs("""
		Usage:
		\t\(CommandLine.arguments[0]) -s path-pattern [ -p placeholder ] [ -i crash.xplcrash ] [ -o out.json ]
		\t\(CommandLine.arguments[0]) -s path-pattern [ -p placeholder ] < crash.xplcrash > out.json

		\t-s <path-pattern>\tpattern where to find dSYM files, must include placeholder
		\t-p <placeholder>\tdefault: \(Arguments.DefaultPlaceholder)\n
		\t-i <input-path>\tpath to crash report\n
		\t-o <output-path>\toutput path for JSON dump\n
		""", stderr)
}

func parseArguments() -> Arguments {
	var inputPath: String!
	var outputPath: String!
	var symbolPathPattern: String!
	var placeholder: String!
	
	var i = 1
	while i < CommandLine.arguments.count {
		let arg = CommandLine.arguments[i]
		i += 1

		switch arg {
			case "-i":
				guard i < CommandLine.arguments.count else { printUsage(); exit(1) }
				inputPath = CommandLine.arguments[i]
				i += 1
			
			case "-o":
				guard i < CommandLine.arguments.count else { printUsage(); exit(1) }
				outputPath = CommandLine.arguments[i]
				i += 1

			case "-p":
				guard i < CommandLine.arguments.count else { printUsage(); exit(1) }
				placeholder = CommandLine.arguments[i]
				i += 1

			case "-s":
				guard i < CommandLine.arguments.count else { printUsage(); exit(1) }
				symbolPathPattern = CommandLine.arguments[i]
				i += 1
			
			default:
				fputs("Unexpected argument: \(arg)\n\n", stderr)
				printUsage()
				exit(1)
		}
	}
	
	guard symbolPathPattern != nil else {
		fputs("Expected mandatory argument -s:\n\n", stderr)
		printUsage()
		exit(1)
	}
	
	if placeholder == nil { placeholder = Arguments.DefaultPlaceholder }

	guard symbolPathPattern.contains(placeholder) else {
		fputs("Symbol path must contain placeholder \(placeholder!)\n\n", stderr)
		printUsage()
		exit(1)
	}
	
	let read: () -> Data
	let write: (Data) -> ()
	
	if let path = inputPath {
		read = {
			let data: Data
			do {
				data = try Data(contentsOf: URL(fileURLWithPath: path))
			} catch let error {
				fputs("Failed to read \(path): \(error.localizedDescription)", stderr)
				exit(1)
			}
			return data
		}
	} else {
		read = {
			let data: Data
			do {
				guard let d = try FileHandle.standardInput.readToEnd() else {
					fputs("Failed to read from stdin", stderr)
					exit(1)
				}
				data = d
			} catch let error {
				fputs("Failed to read crash report data from stdin: \(error.localizedDescription)\n", stderr)
				exit(1)
			}
			return data
		}
	}
	
	if let path = outputPath {
		write = { data in
			do {
				try data.write(to: URL(fileURLWithPath: path))
			} catch let error {
				fputs("Failed to write to \(path): \(error.localizedDescription)", stderr)
				exit(1)
			}
		}
	} else {
		write = { data in
			do {
				try FileHandle.standardOutput.write(contentsOf: data)
			} catch let error {
				fputs("Failed to write to standard output: \(error.localizedDescription)", stderr)
				exit(1)
			}
		}
	}
	
	return Arguments(symbolPathPattern: symbolPathPattern,
					 placeholder: placeholder,
					 read: read,
					 write: write)
}

