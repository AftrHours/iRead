//
//  ResolvedAnalysis+Merges.swift
//  iRead
//
//  Created by abr on 24/10/26.
//

import Foundation

extension ResolvedAnalysis {
    var linkedMentions: [ResolvedMention] { mentions.filter { $0.entity != nil } }

    func entity(_ key: Int) -> ResolvedEntity? {
        entities.first { $0.key == key }
    }

    func entityKey(of mention: ResolvedMention, asOf sentence: Int) -> Int? {
        mention.entity.map { follow($0, upTo: sentence) }
    }

    func finalKey(of entity: Int) -> Int {
        follow(entity, upTo: nil)
    }

    mutating func merge(_ from: Int, into: Int, at sentence: Int, decidedBy: DecidedBy) {
        let source = finalKey(of: from), target = finalKey(of: into)
        guard source != target, let i = entities.firstIndex(where: { $0.key == source }) else { return }
        entities[i].mergeEdges.append(MergeEdge(into: target, mergedAtSentence: sentence, decidedBy: decidedBy))
    }

    private func follow(_ key: Int, upTo sentence: Int?) -> Int {
        var current = key
        var seen: Set<Int> = [current]
        while let edge = entity(current)?.mergeEdges.first(where: { sentence == nil || $0.mergedAtSentence <= sentence! }),
              seen.insert(edge.into).inserted {
            current = edge.into
        }
        return current
    }
}
