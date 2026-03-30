//
//  ExportFileDocument.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 20/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    var data: Data
    var contentType: UTType

    init(data: Data = Data(), contentType: UTType = .json) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
