//
//  ViewController.swift
//  TracePrivately
//

import UIKit

class ViewController: UITableViewController {

    enum RowType {
        case trackingState
        case startStopTracking
        case checkIfExposed
        case markAsInfected
    }
    
    struct Section {
        let header: String?
        let footer: String?
        
        let rows: [RowType]
    }
    
    var trackingStatusError: Error?
    var trackingStatus: CTManagerState = .unknown
    
    var sections: [Section] = []
    
    fileprivate var isDeterminingState = false
    fileprivate var stateGetRequest: CTStateGetRequest?
    
    fileprivate var isSettingState = false
    fileprivate var stateSetRequest: CTStateSetRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.title = "Trace Privately"
        
        self.sections = [
            Section(header: "About", footer: "This is an example only of contact tracing using Apple's newly-announced framework.", rows: []),
            Section(header: "Tracking", footer: nil, rows: [ .trackingState, .startStopTracking ]),
            Section(header: "Infection", footer: nil, rows: [ .markAsInfected ]),
            Section(header: "Exposure", footer: nil, rows: [ .checkIfExposed ])
        ]
        
        self.refreshTrackingState()
    }
}

extension ViewController {
    func refreshTrackingState() {
        self.stateGetRequest?.invalidate()
        
        self.isDeterminingState = true
        
        let request = CTStateGetRequest()
        request.completionHandler = { error in
            // In this example the request is running on main queue anyway, but I've put the dispatch in anyway
            DispatchQueue.main.async {
                self.trackingStatusError = error
                self.trackingStatus = request.state
                
                self.isDeterminingState = false
                
                var indexPaths: [IndexPath] = []
                
                if let indexPath = self.indexPath(rowType: .trackingState) {
                    indexPaths.append(indexPath)
                }

                if let indexPath = self.indexPath(rowType: .startStopTracking) {
                    indexPaths.append(indexPath)
                }
            
                if indexPaths.count > 0 {
                    self.tableView.reloadRows(at: indexPaths, with: .automatic)
                }
            }
        }
        
        self.stateGetRequest = request
        
        request.perform()
    }
}

extension ViewController {
    func startTracking() {
        
    }
    
    func stopTracking() {
        
    }
}

extension ViewController {
    func updateStartStopTrackingCell(cell: UITableViewCell) {
        switch self.trackingStatus {
        case .off:
            cell.textLabel?.text = "Start Tracking"
            cell.detailTextLabel?.text = "Available"
            cell.accessoryType = .disclosureIndicator

        case .on:
            cell.textLabel?.text = "Stop Tracking"
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .none
            
        case .unknown:
            cell.textLabel?.text = "Start Tracking"
            cell.detailTextLabel?.text = "Not available"
            cell.accessoryType = .none
        }
        
        cell.accessoryView = nil
    }
}

extension ViewController {
    func indexPath(rowType: RowType) -> IndexPath? {
        for (s, section) in self.sections.enumerated() {
            for (r, row) in section.rows.enumerated() {
                if row == rowType {
                    return IndexPath(row: r, section: s)
                }
            }
        }
        
        return nil
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].header
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.sections[section].footer
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let rowType = self.sections[indexPath.section].rows[indexPath.row]
        
        switch rowType {
        case .trackingState:
            cell.textLabel?.text = "Tracking State"
            
            if let error = self.trackingStatusError {
                cell.detailTextLabel?.text = error.localizedDescription
            }
            else {
                cell.detailTextLabel?.text = self.trackingStatus.localizedTitle
            }
            
            if self.isDeterminingState {
                let indicator = UIActivityIndicatorView(style: .medium)
                indicator.startAnimating()
                cell.accessoryView = indicator
            }
            else {
                cell.accessoryView = nil
            }
            
            self.updateGetStateIndicator(cell: cell)
            
        case .startStopTracking:
            self.updateStartStopTrackingCell(cell: cell)
            
        case .checkIfExposed:
            cell.textLabel?.text = "Check Your Exposure"
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            
        case .markAsInfected:
            cell.textLabel?.text = "I Have COVID-19"
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    private func updateGetStateIndicator(cell: UITableViewCell) {
        if self.isDeterminingState {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.startAnimating()
            cell.accessoryView = indicator
        }
        else {
            cell.accessoryView = nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rowType = self.sections[indexPath.section].rows[indexPath.row]
        
        switch rowType {
        case .trackingState:
            self.refreshTrackingState()
            tableView.deselectRow(at: indexPath, animated: true)
            
            if let cell = tableView.cellForRow(at: indexPath) {
                self.updateGetStateIndicator(cell: cell)
            }
            
        case .startStopTracking:
            tableView.deselectRow(at: indexPath, animated: true)
            
            switch self.trackingStatus {
            case .unknown:
                let alert = UIAlertController(title: "Error", message: "Unable to start tracking at this time", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
            case .off:
                let alert = UIAlertController(title: "Start Tracking", message: "Click Start to enable tracking on your device.\n\nIt is achieved in a private and secure way, with minimal impact on your battery life.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Start", style: .destructive, handler: { action in
                   
                    let haptics = UINotificationFeedbackGenerator()
                    haptics.notificationOccurred(.success)

                    self.startTracking()
                    
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                self.present(alert, animated: true, completion: nil)
                
            case .on:
                let alert = UIAlertController(title: "Stop Tracking", message: "Are you sure? It is extremely helpful to society if tracking is enabled whenever you're around other people.", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Stop", style: .destructive, handler: { action in

                    let haptics = UINotificationFeedbackGenerator()
                    haptics.notificationOccurred(.success)
                    
                    self.stopTracking()

                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            }
            
        case .checkIfExposed:
            break
            
        case .markAsInfected:
            break
        }
    }
}


extension CTManagerState {
    var localizedTitle: String {
        switch self {
        case .unknown: return "Unknown"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}
