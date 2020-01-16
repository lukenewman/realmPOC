//
//  ViewController.swift
//  realm
//
//  Created by Luke Newman on 1/13/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import RealmSwift
import UIKit

class ViewController: UITableViewController {

    var classes: Results<StudioClass>!
    var notificationToken: NotificationToken? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        Stores.shared.initialize()

        navigationItem.title = "Upcoming Classes"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let realm = try! Realm()
        classes = realm.objects(StudioClass.self)
        notificationToken = classes.observe { [weak self] changes in
            guard let tableView = self?.tableView else { return }
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                tableView.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                tableView.beginUpdates()
                // Always apply updates in the following order: deletions, insertions, then modifications.
                // Handling insertions before deletions may result in unexpected behavior.
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
                                     with: .automatic)
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.endUpdates()
            case .error(let error):
                Logger.log("classes observation error: \(error.localizedDescription)", to: .realm)
            }
        }
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return classes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let studioClass = classes[indexPath.row]
        cell.textLabel?.text = studioClass.name
        return cell
    }

}
