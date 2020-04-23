//
//  SubmitInfectionViewController.swift
//  TracePrivately
//

import UIKit

// TODO: Assuming there will be more fields in future (e.g. pathology lab test ID or photo), prepopulate with any pending submission requests
class SubmitInfectionViewController: UIViewController {

    @IBOutlet var submitButton: ActionButton!
    
    @IBOutlet var infoLabel: UILabel!
    
    var config: SubmitInfectionConfig = .empty
    
    // Holds the form elements
    @IBOutlet var stackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = Bundle.main.url(forResource: "SubmitConfig", withExtension: "plist") {
            if let config = SubmitInfectionConfig(plistUrl: url) {
                self.config = config
            }
        }
        
        // TODO: Make use of config in this form
        
        self.title = String(format: NSLocalizedString("infection.report.submit.title", comment: ""), Disease.current.localizedTitle)
        
        self.infoLabel.text = String(format: NSLocalizedString("infection.report.message", comment: ""), Disease.current.localizedTitle)
        
        self.submitButton.setTitle(NSLocalizedString("infection.report.submit.title", comment: ""), for: .normal)
        
        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(Self.cancelTapped(_:)))
        self.navigationItem.leftBarButtonItem = button
        
        
        let elements = self.config.sortedFields.compactMap { self.createFormElement(field: $0) }
        
        elements.forEach { self.stackView.addArrangedSubview($0) }
    }
    
    @objc func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SubmitInfectionViewController {
    func createFormElement(field: SubmitInfectionConfig.Field) -> UIView? {
        let isDarkMode: Bool
        
        if #available(iOS 12, *) {
            isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        }
        else {
            isDarkMode = false
        }

        var subViews: [UIView] = []
        
        if let str = field.localizedTitle {
            let label = UILabel()
            label.text = str
            label.font = UIFont.preferredFont(forTextStyle: .headline)
            if #available(iOS 13.0, *) {
                label.textColor = .label
            } else {
                label.textColor = isDarkMode ? .white : .black
            }
            
            subViews.append(label)
        }
        
        if let str = field.localizedDescription {
            let label = UILabel()
            label.text = str
            label.font = UIFont.preferredFont(forTextStyle: .body)
            if #available(iOS 13.0, *) {
                label.textColor = .label
            } else {
                label.textColor = isDarkMode ? .white : .black
            }

            subViews.append(label)
        }

        switch field.type {
        case .shortText:
            
            let textField = UITextField()
            textField.placeholder = field.placeholder
            
            subViews.append(textField)

        case .photo:
            // A container with a button to open the photo picker and an image view for preview
            
            let button = UIButton(type: .custom)
            
            let previewImageView = UIImageView()
            
            
            let stackView = UIStackView(arrangedSubviews: [ button, previewImageView ])
            stackView.axis = .horizontal
            
            subViews.append(stackView)

        case .longText:
            let textView = UITextView()
            subViews.append(textView)
        }
        
        
        let container = UIStackView(arrangedSubviews: subViews)
        container.axis = .vertical
        
        return container
    }
}

extension SubmitInfectionViewController {
    @IBAction func submitTapped(_ sender: ActionButton) {
        let request = CTSelfTracingInfoRequest()
        
        request.completionHandler = { info, error in
            guard let keys = info?.dailyTracingKeys else {
                
                var showError = true
                
                if let error = error as? CTError {
                    switch error {
                    case .permissionDenied:
                        showError = false
                    default:
                        break
                    }
                }
                
                if showError {
                    let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error?.localizedDescription ?? NSLocalizedString("infection.report.gathering_data.error", comment: ""), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    
                    self.present(alert, animated: true, completion: nil)
                }
                
                return
            }

            guard keys.count > 0 else {
                let alert = UIAlertController(title: NSLocalizedString("infection.report.gathering.empty.title", comment: ""), message: NSLocalizedString("infection.report.gathering.empty.message", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))

                self.present(alert, animated: true, completion: nil)
                
                return
            }

            let alert = UIAlertController(title: NSLocalizedString("infection.report.submit.title", comment: ""), message: NSLocalizedString("infection.report.submit.message", comment: ""), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: NSLocalizedString("submit", comment: ""), style: .destructive, handler: { action in
                
                self.submitReport(keys: keys)
                
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        
        request.perform()
    }
}

extension SubmitInfectionViewController {
    // TODO: Make it super clear to the user if an error occurred, so they have an opportunity to submit again
    func submitReport(keys: [CTDailyTracingKey]) {
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("infection.report.submitting.title", comment: ""), message: NSLocalizedString("infection.report.submitting.message", comment: ""), preferredStyle: .alert)

        self.present(loadingAlert, animated: true, completion: nil)

        // TODO: Move most of this to DataManager for consistency
        let context = DataManager.shared.persistentContainer.newBackgroundContext()
        
        context.perform {
            // Putting this as pending effectively saves a draft in case something goes wrong in submission
            
            let entity = LocalInfectionEntity(context: context)
            entity.dateAdded = Date()
            entity.status = DataManager.InfectionStatus.pendingSubmission.rawValue
            
            try? context.save()
        
            NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)

            KeyServer.shared.submitInfectedKeys(keys: keys) { success, error in
                
                context.perform {
                    if success {
                        // TODO: Check against the local database to see if it should be submittedApproved or submittedUnapproved.
                        entity.status = DataManager.InfectionStatus.submittedUnapproved.rawValue
                        
                        for key in keys {
                            let keyEntity = LocalInfectionKeyEntity(context: context)
                            keyEntity.infectedKey = key.keyData
                            keyEntity.infection = entity
                        }

                        try? context.save()
                        
                        NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
                    }

                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {

                            if success {
                                self.dismiss(animated: true, completion: nil)
                            }
                            else {
                                let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error?.localizedDescription ?? NSLocalizedString("infection.report.submit.error", comment: "" ), preferredStyle: .alert)
                                
                                alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                                
                                self.present(alert, animated: true, completion: nil)
                            }
                        }
                    }
                }
            }
        }
    }
}
