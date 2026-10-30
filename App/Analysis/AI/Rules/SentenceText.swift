//
//  SentenceText.swift
//  iRead
//
//  Created by abr on 24/10/26.
//

import Foundation

enum SentenceText {
    static func of(_ sentence: Sentence, in content: BookContent) -> String {

        let paragraph = content.paragraphs[sentence.paragraph]
        let chapter = content.chapters[paragraph.chapterIndex]
        let range = NSRange(location: paragraph.range.location + sentence.range.location, length: sentence.range.length)
        return (chapter.text as NSString).substring(with: range)
    }
    static func numbered(in content: BookContent) -> [NumberedSentence] {
        content.sentences.enumerated().map { NumberedSentence(index: $0.offset, text: of($0.element, in: content)) }
    }

}
