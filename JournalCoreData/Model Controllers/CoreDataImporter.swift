//
//  CoreDataImporter.swift
//  JournalCoreData
//
//  Created by Andrew R Madsen on 9/10/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation
import CoreData

class CoreDataImporter {
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func sync(entries: [EntryRepresentation], completion: @escaping (Error?) -> Void = { _ in }) {
        
        DispatchQueue.global().async {
            print("started syncing")
            
            let identifiers = entries.compactMap { $0.identifier }
            let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "identifier IN %@", identifiers)
            var entriesInCoreData: [Entry]?
            do {
                entriesInCoreData = try self.context.fetch(fetchRequest)
            } catch {
                NSLog("Error fetching single entry: \(error)")
                completion(NSError())
                return
            }
            
            var entriesDict: [String: Entry] = [:]
            
            guard let coreDataEntries = entriesInCoreData else { completion(NSError()); return }
            for entry in coreDataEntries {
                // entries will have identifiers since they were fetched by them (line 32)
                entriesDict[entry.identifier!] = entry
            }
            self.context.perform {
                for entryRep in entries {
                    guard let identifier = entryRep.identifier else { completion(NSError()); return }
                    let entry = entriesDict[identifier]
                    if let entry = entry, entry != entryRep {
                        self.update(entry: entry, with: entryRep)
                    } else if entry == nil {
                        _ = Entry(entryRepresentation: entryRep, context: self.context)
                    }
                    completion(nil)
                }
            }
        }
    }
    
    private func update(entry: Entry, with entryRep: EntryRepresentation) {
        entry.title = entryRep.title
        entry.bodyText = entryRep.bodyText
        entry.mood = entryRep.mood
        entry.timestamp = entryRep.timestamp
        entry.identifier = entryRep.identifier
    }
    
    let context: NSManagedObjectContext
}
