//
//  EntryController.swift
//  JournalCoreData
//
//  Created by Spencer Curtis on 8/12/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation
import CoreData

let baseURL = URL(string: "https://journal-performance2.firebaseio.com/")!

class EntryController {
        
    func createEntry(with title: String, bodyText: String, mood: String) {
        
        let entry = Entry(title: title, bodyText: bodyText, mood: mood)
        
        put(entry: entry)
        
        saveToPersistentStore()
    }
    
    func update(entry: Entry, title: String, bodyText: String, mood: String) {
        
        entry.title = title
        entry.bodyText = bodyText
        entry.timestamp = Date()
        entry.mood = mood
        
        put(entry: entry)
        
        saveToPersistentStore()
    }
    
    func delete(entry: Entry) {
        
        CoreDataStack.shared.mainContext.delete(entry)
        deleteEntryFromServer(entry: entry)
        saveToPersistentStore()
    }
    
    private func put(entry: Entry, completion: @escaping ((Error?) -> Void) = { _ in }) {
        
        let identifier = entry.identifier ?? UUID().uuidString
        let requestURL = baseURL.appendingPathComponent(identifier).appendingPathExtension("json")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "PUT"
        
        do {
            request.httpBody = try JSONEncoder().encode(entry)
        } catch {
            NSLog("Error encoding Entry: \(error)")
            completion(error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                NSLog("Error PUTting Entry to server: \(error)")
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    }
    
    func deleteEntryFromServer(entry: Entry, completion: @escaping ((Error?) -> Void) = { _ in }) {
        
        guard let identifier = entry.identifier else {
            NSLog("Entry identifier is nil")
            completion(NSError())
            return
        }
        
        let requestURL = baseURL.appendingPathComponent(identifier).appendingPathExtension("json")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                NSLog("Error deleting entry from server: \(error)")
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    }
    
    func fetchEntriesFromServer(completion: @escaping (([EntryRepresentation]?, Error?) -> Void) = { _,_ in }) {
        
        let requestURL = baseURL.appendingPathExtension("json")
        
        URLSession.shared.dataTask(with: requestURL) { (data, _, error) in
            
            if let error = error {
                NSLog("Error fetching entries from server: \(error)")
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                NSLog("No data returned from data task")
                completion(nil, NSError())
                return
            }

            do {
                let entryReps = try JSONDecoder().decode([String: EntryRepresentation].self, from: data).map({$0.value})
                completion(entryReps, nil)
            } catch {
                NSLog("Error decoding JSON data: \(error)")
                completion(nil, error)
                return
            }
        }.resume()
    }
    
    func refreshEntriesFromServer(completion: @escaping ((Error?) -> Void) = { _ in }) {
        fetchEntriesFromServer { (representations, error) in
            if error != nil { return }
            guard let representations = representations else { return }
            let moc = CoreDataStack.shared.container.newBackgroundContext()
            self.updateEntries(with: representations, in: moc, completion: completion)
        }
    }
    
    private func updateEntries(with representations: [EntryRepresentation],
                               in context: NSManagedObjectContext,
                               completion: @escaping ((Error?) -> Void) = { _ in }) {
        
        importer = CoreDataImporter(context: context)
        importer?.sync(entries: representations) { (error) in
            if let error = error {
                NSLog("Error syncing entries from server: \(error)")
                completion(error)
                return
            }
            
            context.perform {
                do {
                    try context.save()
                    completion(nil)
                } catch {
                    NSLog("Error saving sync context: \(error)")
                    completion(error)
                    return
                }
            }
        }
    }
    
    func saveToPersistentStore() {        
        do {
            try CoreDataStack.shared.mainContext.save()
        } catch {
            NSLog("Error saving managed object context: \(error)")
        }
    }
    
    private var importer: CoreDataImporter?
}
