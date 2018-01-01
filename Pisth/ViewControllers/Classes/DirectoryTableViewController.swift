//
//  DirectoryTableViewController.swift
//  
//
//  Created by Adrian on 25.12.17.
//

import UIKit

class DirectoryTableViewController: UITableViewController, LocalDirectoryTableViewControllerDelegate {
        
    var directory: String
    var connection: RemoteConnection
    var files: [String]?
    var isDir = [Bool]()
    var delegate: DirectoryTableViewControllerDelegate?
    var closeAfterSending = false
    
    static var disconnected = false
    
    init(connection: RemoteConnection, directory: String? = nil) {
        self.connection = connection
        ConnectionManager.shared.connection = connection
        
        if directory == nil {
            self.directory = connection.path
        } else {
            self.directory = directory!
        }
        
        var continue_ = false
        
        if !Reachability.isConnectedToNetwork() {
            continue_ = false
        } else if ConnectionManager.shared.filesSession == nil {
            continue_ = ConnectionManager.shared.connect()
        } else if !ConnectionManager.shared.filesSession!.isConnected || !ConnectionManager.shared.filesSession!.isAuthorized {
            continue_ = ConnectionManager.shared.connect()
        } else {
            continue_ = ConnectionManager.shared.filesSession!.isConnected && ConnectionManager.shared.filesSession!.isAuthorized
        }
        
        if continue_ {
            if self.directory == "~" { // Get absolute path from ~
                if let path = try? ConnectionManager.shared.filesSession?.channel.execute("echo $HOME").replacingOccurrences(of: "\n", with: "") {
                    self.directory = path!
                }
            }
            
            if let files = ConnectionManager.shared.files(inDirectory: self.directory) {
                self.files = files
                
                if files == [self.directory+"/*"] { // The content of files is ["*"] when there is no file
                    self.files = []
                }
                
                // Check if path is directory or not
                for file in files {
                    isDir.append(file.hasSuffix("/"))
                }
                
                self.files!.append((self.directory as NSString).deletingLastPathComponent) // Append parent directory
                isDir.append(true)
            }
        }
        
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func reload() { // Reload current directory content
        files = nil
        isDir = []
        
        if let files = ConnectionManager.shared.files(inDirectory: self.directory) {
            self.files = files
            
            if files == [self.directory+"/*"] { // The content of files is ["*"] when there is no file
                self.files = []
            }
            
            // Check if path is directory or not
            for file in files {
                isDir.append(file.hasSuffix("/"))
            }
            
            self.files!.append((self.directory as NSString).deletingLastPathComponent) // Append parent directory
            isDir.append(true)
        } else {
            self.files = nil
        }
        
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }
    
    @objc func uploadFile(_ sender: UIBarButtonItem) { // Add file
        
        let chooseAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        chooseAlert.addAction(UIAlertAction(title: "Import", style: .default, handler: { (_) in // Upload file
            let localDirVC = LocalDirectoryTableViewController(directory: FileManager.default.documents)
            localDirVC.delegate = self
            
            self.navigationController?.pushViewController(localDirVC, animated: true)
        }))
        
        chooseAlert.addAction(UIAlertAction(title: "Create blank file", style: .default, handler: { (_) in // Create file
            
            let chooseName = UIAlertController(title: "Create blank file", message: "Choose new file name", preferredStyle: .alert)
            chooseName.addTextField(configurationHandler: { (textField) in
                textField.placeholder = "New file name"
            })
            chooseName.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            chooseName.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
                do {
                    let result = try ConnectionManager.shared.filesSession?.channel.execute("touch '\(self.directory)/\(chooseName.textFields![0].text!)' 2>&1")
                    
                    if result?.replacingOccurrences(of: "\n", with: "") != "" { // Error
                        let errorAlert = UIAlertController(title: nil, message: result, preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                        self.present(errorAlert, animated: true, completion: nil)
                    } else {
                        self.reload()
                    }
                } catch let error {
                    let errorAlert = UIAlertController(title: "Error creating file!", message: error.localizedDescription, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }))
            
            self.present(chooseName, animated: true, completion: nil)
            
        }))
        
        chooseAlert.addAction(UIAlertAction(title: "Create folder", style: .default, handler: { (_) in // Create folder
            let chooseName = UIAlertController(title: "Create folder", message: "Choose new folder name", preferredStyle: .alert)
            chooseName.addTextField(configurationHandler: { (textField) in
                textField.placeholder = "New folder name"
            })
            chooseName.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            chooseName.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
                do {
                    let result = try ConnectionManager.shared.filesSession?.channel.execute("mkdir '\(self.directory)/\(chooseName.textFields![0].text!)' 2>&1")
                    
                    if result?.replacingOccurrences(of: "\n", with: "") != "" { // Error
                        let errorAlert = UIAlertController(title: nil, message: result, preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                        self.present(errorAlert, animated: true, completion: nil)
                    } else {
                        self.reload()
                    }
                } catch let error {
                    let errorAlert = UIAlertController(title: "Error creating folder!", message: error.localizedDescription, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }))
            
            self.present(chooseName, animated: true, completion: nil)
        }))
        
        chooseAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        chooseAlert.popoverPresentationController?.barButtonItem = sender
        
        self.present(chooseAlert, animated: true, completion: nil)
    }
    
    @objc func openShell() { // Open shell in current directory
        let terminalVC = Bundle.main.loadNibNamed("TerminalViewController", owner: nil, options: nil)!.first! as! TerminalViewController
        terminalVC.pwd = directory
        navigationController?.pushViewController(terminalVC, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = directory.components(separatedBy: "/").last
        
        navigationItem.largeTitleDisplayMode = .never
        
        // TableView cells
        tableView.register(UINib(nibName: "FileTableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "file")
        tableView.backgroundColor = .black
        clearsSelectionOnViewWillAppear = false
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        // Initialize the refresh control.
        refreshControl = UIRefreshControl()
        refreshControl?.tintColor = UIColor.white
        refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
        
        // Bar buttons
        let uploadFile = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(uploadFile(_:)))
        let terminal = UIBarButtonItem(image: #imageLiteral(resourceName: "terminal"), style: .plain, target: self, action: #selector(openShell))
        navigationItem.setRightBarButtonItems([uploadFile, terminal], animated: true)
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 87
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let files = files {
            return files.count
        }
        
        return 0
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "file") as! FileTableViewCell
        
        // Configure the cell...
        
        if let files = files {
            if files[indexPath.row] != (directory as NSString).deletingLastPathComponent {
                if isDir[indexPath.row] {
                    let components = files[indexPath.row].components(separatedBy: "/")
                    cell.filename.text = components[components.count-2]
                } else {
                    cell.filename.text = files[indexPath.row].components(separatedBy: "/").last
                }
            } else {
                cell.filename.text = ".."
            }
        }
        
        if isDir.indices.contains(indexPath.row) {
            if isDir[indexPath.row] {
                cell.iconView.image = #imageLiteral(resourceName: "folder")
            } else if files![indexPath.row].hasPrefix("./") {
                cell.iconView.image = #imageLiteral(resourceName: "bin")
            } else {
                cell.iconView.image = fileIcon(forExtension: (files![indexPath.row] as NSString).pathExtension)
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Remove file
            do {
                let result = try ConnectionManager.shared.filesSession?.channel.execute("rm -rf '\(files![indexPath.row])' 2>&1")
                
                if result?.replacingOccurrences(of: "\n", with: "") != "" { // Error
                    let errorAlert = UIAlertController(title: nil, message: result, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                } else {
                    files!.remove(at: indexPath.row)
                    isDir.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            } catch let error {
                let errorAlert = UIAlertController(title: "Error removing file!", message: error.localizedDescription, preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(errorAlert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let cell = tableView.cellForRow(at: indexPath) as? FileTableViewCell else { return }
        
        var continueDownload = true
        
        let activityVC = UIAlertController(title: "Downloading...", message: "", preferredStyle: .alert)
        activityVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            continueDownload = false
        }))
        
        self.present(activityVC, animated: true) {
            if cell.iconView.image == #imageLiteral(resourceName: "folder") { // Open folder
                let dirVC = DirectoryTableViewController(connection: self.connection, directory: self.files?[indexPath.row])
                if let delegate = self.delegate {
                    activityVC.dismiss(animated: true, completion: {
                        
                        delegate.directoryTableViewController(dirVC, didOpenDirectory: self.files![indexPath.row])
                        
                        tableView.deselectRow(at: indexPath, animated: true)
                    })
                } else {
                    activityVC.dismiss(animated: true, completion: {
                        
                        self.navigationController?.pushViewController(dirVC, animated: true)
                        
                        tableView.deselectRow(at: indexPath, animated: true)
                    })
                }
            } else if cell.iconView.image == #imageLiteral(resourceName: "bin") { // Execute file
                let terminalVC = Bundle.main.loadNibNamed("TerminalViewController", owner: nil, options: nil)!.first! as! TerminalViewController
                terminalVC.command = "'\(String(self.files![indexPath.row].dropFirst()))'"
                terminalVC.pwd = self.directory
                
                activityVC.dismiss(animated: true, completion: {
                    self.navigationController?.pushViewController(terminalVC, animated: true)
                })
                
            } else { // Download file
                
                guard let session = ConnectionManager.shared.filesSession else {
                    tableView.deselectRow(at: indexPath, animated: true)
                    activityVC.dismiss(animated: true, completion: nil)
                    DirectoryTableViewController.disconnected = true
                    self.navigationController?.popToRootViewController(animated: true)
                    return
                }
                
                if !Reachability.isConnectedToNetwork() {
                    tableView.deselectRow(at: indexPath, animated: true)
                    activityVC.dismiss(animated: true, completion: nil)
                    DirectoryTableViewController.disconnected = true
                    self.navigationController?.popToRootViewController(animated: true)
                    return
                }
                
                if !session.isConnected || !session.isAuthorized {
                    tableView.deselectRow(at: indexPath, animated: true)
                    activityVC.dismiss(animated: true, completion: nil)
                    DirectoryTableViewController.disconnected = true
                    self.navigationController?.popToRootViewController(animated: true)
                    return
                }
                
                let newFile = FileManager.default.documents.appendingPathComponent(cell.filename.text!)
                
                DispatchQueue.global(qos: .background).async {
                    if let data = session.sftp.contents(atPath: self.files![indexPath.row], progress: { (receivedBytes, bytesToBeReceived) -> Bool in
                        
                        let received = ByteCountFormatter().string(fromByteCount: Int64(receivedBytes))
                        let toBeReceived = ByteCountFormatter().string(fromByteCount: Int64(bytesToBeReceived))
                        
                        DispatchQueue.main.async {
                            activityVC.message = "\(received) / \(toBeReceived)"
                        }
                        
                        return continueDownload
                    }) {
                        DispatchQueue.main.async {
                            do {
                                try data.write(to: newFile)
                                
                                activityVC.dismiss(animated: true, completion: {
                                    ConnectionManager.shared.saveFile = SaveFile(localFile: newFile.path, remoteFile: self.files![indexPath.row])
                                    LocalDirectoryTableViewController.openFile(newFile, from: tableView.cellForRow(at: indexPath)!.frame, in: tableView, navigationController: self.navigationController, showActivityViewControllerInside: self)
                                })
                            } catch let error {
                                activityVC.dismiss(animated: true, completion: {
                                    let errorAlert = UIAlertController(title: "Error downloading file!", message: error.localizedDescription, preferredStyle: .alert)
                                    errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                                    self.present(errorAlert, animated: true, completion: nil)
                                })
                            }
                            
                            tableView.deselectRow(at: indexPath, animated: true)
                        }
                    } else {
                        DispatchQueue.main.async {
                            activityVC.dismiss(animated: true, completion: {
                                self.navigationController?.popToRootViewController(animated: true)
                            })
                        }
                    }
                }
            }
        }
                
    }
    
    // MARK: - LocalDirectoryTableViewControllerDelegate
    
    func localDirectoryTableViewController(_ localDirectoryTableViewController: LocalDirectoryTableViewController, didOpenFile file: URL) { // Send file
        
        // Upload file
        func sendFile() {
            
            let activityVC = ActivityViewController(message: "Uploading")
            self.present(activityVC, animated: true) {
                do {
                    let dataToSend = try Data(contentsOf: file)
                    
                    ConnectionManager.shared.filesSession?.sftp.writeContents(dataToSend, toFileAtPath: (self.directory as NSString).appendingPathComponent(file.lastPathComponent))
                    
                    if self.closeAfterSending {
                        activityVC.dismiss(animated: true, completion: {
                            AppDelegate.shared.close()
                        })
                    } else {
                        activityVC.dismiss(animated: true, completion: {
                            self.reload()
                        })
                    }
                    
                } catch let error {
                    let errorAlert = UIAlertController(title: "Error reading file data!", message: error.localizedDescription, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
        
        // Ask user to send file
        let confirmAlert = UIAlertController(title: file.lastPathComponent, message: "Do you want to send \(file.lastPathComponent) to \((directory as NSString).lastPathComponent)?", preferredStyle: .alert)
        
        confirmAlert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        
        confirmAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) in
            sendFile()
        }))
        
        // Go back here
        navigationController?.popToViewController(self, animated: true, completion: {
            self.present(confirmAlert, animated: true, completion: nil)
        })
    }
}
