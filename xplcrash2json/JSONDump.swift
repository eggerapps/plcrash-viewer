//
//  JSONDump.swift
//  xplcrash2json
//
//  Created by Martin Köhler on 22.10.21.
//  Copyright © 2021 Egger Apps. All rights reserved.
//

import Foundation
import PLCrash_Viewer

func jsonDump(crashReport: BITPLCrashReport, symbolizer: Symbolizer) throws -> Data
{
	let image = crashReport.images.first as? BITPLCrashReportBinaryImageInfo
	let context = JSONDumpContext(crashReport: crashReport,
								  image: image,
								  symbolizer: symbolizer)
	let dict = crashReport.dictionary(context)
	return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
}

// MARK: - Dump Implementation

struct JSONDumpContext {
	let crashReport: BITPLCrashReport
	let image: BITPLCrashReportBinaryImageInfo?
	let symbolizer: Symbolizer
}

protocol DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?]
}

extension BITPLCrashReport: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"uuid" : CFUUIDCreateString(nil, self.uuidRef),
			"system_info" : self.systemInfo?.dictionary(context),
			"machine_info" : self.machineInfo?.dictionary(context),
			"application_info" : self.applicationInfo?.dictionary(context),
			"process_info" : self.processInfo?.dictionary(context),
			"signal_info" : self.signalInfo?.dictionary(context),
			"mach_exception_info" : self.machExceptionInfo?.dictionary(context),
			"exception_info" : self.exceptionInfo?.dictionary(context),
			"threads" : (self.threads as? [BITPLCrashReportThreadInfo])?.map { $0.dictionary(context) },
			"images" : (self.images as? [BITPLCrashReportBinaryImageInfo])?.map { $0.dictionary(context) },
		]
	}
}

extension BITPLCrashReportSystemInfo: DictionaryRepresentable {
	var architectureString: String {
		switch self.architecture.rawValue { // see PLCrashReportSystemInfo.h
			case 0: return "x86-32"
			case 1: return "x86-64"
			case 2: return "armv6"
			case 3: return "ppc"
			case 4: return "ppc64"
			case 5: return "armv7"
			default: return "unknown"
		}
	}
	
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"os_version" : self.operatingSystemVersion,
			"os_build" : self.operatingSystemBuild,
			"architecture" : self.architectureString,
			"timestamp" : self.timestamp.description
		]
	}
}

extension BITPLCrashReportMachineInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"model_name" : self.modelName,
			"processor_info" : self.processorInfo.dictionary(context),
			"processor_count" : self.processorCount,
			"logical_processor_count" : self.logicalProcessorCount,
		]
	}
}

extension BITPLCrashReportApplicationInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"identifier" : self.applicationIdentifier,
			"version" : self.applicationVersion,
			"marketing_version" : self.applicationMarketingVersion
		]
	}
}

extension BITPLCrashReportProcessInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"process_name" : self.processName,
			"process_id" : self.processID,
			// "process_path" : self.processPath, // NOTE: omitted due to privacy concerns
			"process_start_time" : self.processStartTime.description,
			// "parent_process_name" : self.parentProcessName, // NOTE: omitted
			// "parent_process_id" : self.parentProcesID, // NOTE: omitted
			"native" : self.native,
		]
	}
}

extension BITPLCrashReportSignalInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"name" : self.name,
			"code" : self.code,
			"address" : self.address,
		]
	}
}

extension BITPLCrashReportMachExceptionInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"type" : self.type,
			"codes" : self.codes
		]
	}
}

extension BITPLCrashReportSymbolInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"symbol_name" : self.symbolName,
			"start_address" : self.startAddress,
			"end_address" : self.endAddress,
		]
	}
}

extension BITPLCrashReportStackFrameInfo: DictionaryRepresentable {
	func symbolizedName(_ context: JSONDumpContext) -> String {
		var symbolName = self.symbolInfo?.symbolName ?? "???"

		var address = self.instructionPointer
		if address > 0 { address -= 1 }

		if let image = context.image,
		   image.imageBaseAddress ..< (image.imageBaseAddress + image.imageSize) ~= address,
		   let symbols = try? context.symbolizer.symbolize(imageUUID: image.uuid!,
														   imageLoadAddress: image.imageBaseAddress,
														   stackAddresses: [address])
		{
			symbolName = symbols.first ?? "???"
		}
		return symbolName
	}
	
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"instruction_pointer" : self.instructionPointer,
			"symbol_info" : self.symbolInfo?.dictionary(context),
			"symbolized_name" : symbolizedName(context)
		]
	}
}

extension BITPLCrashReportExceptionInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"exception_name" : self.exceptionName,
			"exception_reason" : self.exceptionReason,
			"stack_frames" : (self.stackFrames as? [BITPLCrashReportStackFrameInfo])?.map { $0.dictionary(context) },
		]
	}
}

extension BITPLCrashReportRegisterInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"name" : self.registerName,
			"value" : self.registerValue,
		]
	}
}

extension BITPLCrashReportThreadInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"thread_number" : self.threadNumber,
			"stack_frames" : (self.stackFrames as? [BITPLCrashReportStackFrameInfo])?.map { $0.dictionary(context) },
			"crashed" : self.crashed,
			"registers" : (self.registers as? [BITPLCrashReportRegisterInfo])?.map { $0.dictionary(context) },
		]
	}
}

extension BITPLCrashReportProcessorInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"type_encoding" : self.typeEncoding.rawValue,
			"type" : type,
			"subtype" : subtype,
			"architecture" : architecture
		]
	}
	
	var architecture: String? {
		if typeEncoding != PLCrashReportProcessorTypeEncodingMach {
			return "unknown"
		}
		let cputype = cpu_type_t(type)
		if cputype | CPU_TYPE_ARM64 != 0 {
			return "arm64"
		}
		if cputype | CPU_TYPE_X86_64 != 0 {
			return "x86_64"
		}
		if cputype | CPU_TYPE_I386 != 0 {
			return "i386"
		}
		return "unknown"
	}
}

extension BITPLCrashReportBinaryImageInfo: DictionaryRepresentable {
	func dictionary(_ context: JSONDumpContext) -> [String: Any?] {
		return [
			"name" : self.imageName,
			"code_type" : self.codeType.dictionary(context),
			"base_address" : self.imageBaseAddress,
			"uuid" : self.imageUUID,
			"size" : self.imageSize,
		]
	}
}
