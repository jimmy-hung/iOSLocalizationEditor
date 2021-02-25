//
//  ViewController.swift
//  LocalizationEditor
//
//  Created by Igor Kulman on 30/05/2018.
//  Copyright © 2018 Igor Kulman. All rights reserved.
//

import Cocoa

/**
Protocol for announcing changes to the toolbar. Needed because the VC does not have direct access to the toolbar (handled by WindowController)
 */
protocol ViewControllerDelegate: AnyObject {
    /**
     Invoked when localization groups should be set in the toolbar's dropdown list
     */
    func shouldSetLocalizationGroups(groups: [LocalizationGroup])

    /**
     Invoiked when search and filter should be reset in the toolbar
     */
    func shouldResetSearchTermAndFilter()

    /**
     Invoked when localization group should be selected in the toolbar's dropdown list
     */
    func shouldSelectLocalizationGroup(title: String)
}

final class ViewController: NSViewController {
    enum FixedColumn: String {
        case key
        case actions
    }

    // MARK: - Outlets

    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
  
  // MARK: - Properties
  
  weak var delegate: ViewControllerDelegate?
  var projectTitle = ""
  var importLanguagesArr: Array<String> = []
  
  private var currentFilter: Filter = .all
  private var currentSearchTerm: String = ""
  private let dataSource = LocalizationsDataSource()
  private var presendedAddViewController: AddViewController?
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupData()
    settingItemAction()
  }
  
  // MARK: - Setup
  
  private func setupData() {
    let cellIdentifiers = [KeyCell.identifier, LocalizationCell.identifier, ActionsCell.identifier]
    cellIdentifiers.forEach { identifier in
      let cell = NSNib(nibNamed: identifier, bundle: nil)
      tableView.register(cell, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier))
    }
    
    tableView.delegate = self
    tableView.dataSource = dataSource
    tableView.allowsColumnResizing = true
    tableView.usesAutomaticRowHeights = true
    
    tableView.selectionHighlightStyle = .none
  }
  
  private func reloadData(with languages: [String], title: String?) {
    delegate?.shouldResetSearchTermAndFilter()
    
    let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    view.window?.title = title.flatMap({ "\(appName) [\($0)]" }) ?? appName
    
    let columns = tableView.tableColumns // 上方欄位
    columns.forEach {
      self.tableView.removeTableColumn($0)
    }
    
    // not sure why this is needed but without it autolayout crashes and the whole tableview breaks visually
    tableView.reloadData()
    
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(FixedColumn.key.rawValue))
    column.title = "key".localized
    tableView.addTableColumn(column)
    
    languages.forEach { language in
      let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(language))
      column.title = Flag(languageCode: language).emoji
      column.maxWidth = 460
      column.minWidth = 50
      self.tableView.addTableColumn(column)
    }
    
    let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(FixedColumn.actions.rawValue))
    actionsColumn.title = "actions".localized
    actionsColumn.maxWidth = 48
    actionsColumn.minWidth = 32
    tableView.addTableColumn(actionsColumn)
    
    tableView.reloadData()
    
    // Also resize the columns:
    tableView.sizeToFit()
    
    // Needed to properly size the actions column
    DispatchQueue.main.async {
      self.tableView.sizeToFit()
      self.tableView.layout()
    }
  }
  
  private func filter() {
    dataSource.filter(by: currentFilter, searchString: currentSearchTerm)
    tableView.reloadData()
  }
  
  /* TODO: sorting unfinished
  func getFileData(url: URL){
    do {
      let data = try Data(contentsOf: url)
      let string = String(data: data, encoding: .utf8)
      let strArr = string?.split(separator: "\n")
      print("show")

      
    } catch {
      let err = error
      print("some error: \(err)")
    }
  }
 */
  
  private func openFolder() {
    let openPanel = NSOpenPanel()
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = true
    openPanel.canCreateDirectories = true
    openPanel.canChooseFiles = true
    openPanel.begin { [unowned self] result -> Void in
      guard result.rawValue == NSApplication.ModalResponse.OK.rawValue, let url = openPanel.url else {
        return
      }
      
      //self.getFileData(url: url) // TODO: sorting unfinished
      
      self.projectTitle = url.lastPathComponent
      self.progressIndicator.startAnimation(self)
      self.dataSource.load(folder: url) { [unowned self] languages, title, localizationFiles in self.reloadData(with: languages, title: title)
        self.progressIndicator.stopAnimation(self)
        
        dataSource.languagesArr = languages as Array
        
        if let title = title {
          self.delegate?.shouldSetLocalizationGroups(groups: localizationFiles)
          self.delegate?.shouldSelectLocalizationGroup(title: title)
        }
      }
    }
  }
  
  // ====
  /**
   setting  tool bar item
   */
  func settingItemAction(){
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    appDelegate.exportToCSVItem.action = #selector(ViewController.export)
    appDelegate.importFileItem.action = #selector(ViewController.importFile)
  }
  
  /**
   import file to update project content only support csv
   */
  @objc func importFile(){
    let openPanel = NSOpenPanel()
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = true
    openPanel.canCreateDirectories = true
    openPanel.canChooseFiles = true
    openPanel.begin { [unowned self] result -> Void in
      guard result.rawValue == NSApplication.ModalResponse.OK.rawValue, let url = openPanel.url else {
        return
      }
      //
      var dataImport: [String: [String: LocalizationString?]] = [:]
      do {
        let file = try String(contentsOf: url)
        let rows = file.components(separatedBy: .newlines)
        for (count, row) in rows.enumerated() {
          if(count == 0){
            importLanguagesArr = strReplaceArr(str: row, replaceItem: ["key", "\""]).components(separatedBy: ",")
            importLanguagesArr.removeAll { (str) -> Bool in
              let str = str == ""
              return str
            }
            continue
          }
          let fields = strReplaceArr(str: row, replaceItem: ["\""]).components(separatedBy: ",")
          if let key = fields.first {
            var itemDict: [String: LocalizationString?] = [:]
            for value in 0...importLanguagesArr.count - 1{
              if fields.count == 1 { continue }
              importLanguagesArr.removeAll { (str) -> Bool in
                let str = str == ""
                return str
              }
              if value + 1 < fields.count {
                let localStr = LocalizationString(key: key, value: fields[value + 1], message: "")
                itemDict[importLanguagesArr[value]] = localStr
              }
            }
            dataImport[key] = itemDict
          }
        }
      } catch {
        print(error)
      }
      //
      updataAndReload(importArr: dataImport)
    }
  }
  
  /**
   after import file to do
   */
  func updataAndReload(importArr: [String: [String: LocalizationString?]]){
    for updata in importArr {
      for count in 0...importLanguagesArr.count - 1 {
        let language = importLanguagesArr[count]
        dataSource.updateLocalization(language: language, key: updata.key, with: updata.value[language]??.value ?? "" , message: "")
      }
    }
    dataSource.importSource(importData: importArr)
    tableView.reloadData()
  }
  
  /**
   export project setting
   */
  @objc func export(){
    dataSource.toCSV()
    if(dataSource.dataToCSV.count <= 0) {
      dialogOKCancel(question: "Nothing content",
                     text: "",
                     showBtn2: false)
      return
    }
    // ========= write to csv
    let titleArr = makeTitleArr()
    let contentArr = makeContentArr()
    let mixArr = titleArr + contentArr
    //
    let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)[0]
    let filename = "\(projectTitle).csv"
    let filePathLib = "\(URL(fileURLWithPath: docDir).appendingPathComponent(filename).path)"
    //
    do {
      try mixArr.joined(separator: ",").write(toFile: filePathLib, atomically: true, encoding: .utf8)
      dialogOKCancel(question: "Export Sucess", text: "\(filePathLib)", showBtn2: true)
      
    } catch {
      dialogOKCancel(question: "Data Error", text: "", showBtn2: false)
    }
    // =========
  }
  
  func dialogOKCancel(question: String, text: String, showBtn2: Bool) {
    let alert: NSAlert = NSAlert()
    alert.messageText = question
    alert.informativeText = text
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: "OK")
    if(showBtn2) {
      alert.addButton(withTitle: "copy path")
    }
    let res = alert.runModal()
    if res == NSApplication.ModalResponse.alertFirstButtonReturn {
      //
    } else {
      let paste = NSPasteboard.general
      paste.clearContents()
      paste.setString(text, forType: .string)
    }
  }
  
  /**
   set export file title
   */
  func makeTitleArr() -> Array<String> {
    var titleArr = ["key"]
    for item in dataSource.languagesArr {
      titleArr.append(item)
    }
    return titleArr
  }
  
  /**
   set export file content
   */
  func makeContentArr() -> Array<String> {
    var contentArr: Array<String> = []
    for item in dataSource.dataToCSV {
      let correspondKey = dataSource.languagesArr
      var stringContent = "\n"
      for (count, kteam) in correspondKey.enumerated() {
        if let content = item.value[kteam],
           let contentKey = content?.key,
           let contentStr = content?.description {
          //
          stringContent += count == 0 ? contentKey : ""
          //
          let contentStrArr = contentStr.split(separator: "=")
          if let str = contentStrArr.last?.description {
            var str = str.replacingOccurrences(of: "\n", with: "\\n")
            str = str.replacingOccurrences(of: ",", with: "，")
            str = strReplaceArr(str: str, replaceItem: [" "])
            stringContent += ", " + str
          }
        }
      }
      contentArr.append(stringContent)
    }
    return compareArr(arr: contentArr)
  }
  
  func compareArr(arr: Array<String>) -> Array<String> {
    return arr.sorted()
  }
  
  func strReplaceArr(str: String, replaceItem: Array<String>) -> String{
    var string = str
    for item in replaceItem {
      string = string.replacingOccurrences(of: item, with: "")
    }
    return string
  }
  // ====
}

// MARK: - NSTableViewDelegate

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else {
            return nil
        }

        switch identifier.rawValue {
        case FixedColumn.key.rawValue:
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: KeyCell.identifier), owner: self)! as! KeyCell
            cell.key = dataSource.getKey(row: row)
            cell.message = dataSource.getMessage(row: row)
            return cell
        case FixedColumn.actions.rawValue:
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ActionsCell.identifier), owner: self)! as! ActionsCell
            cell.delegate = self
            cell.key = dataSource.getKey(row: row)
            return cell
        default:
            let language = identifier.rawValue
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: LocalizationCell.identifier), owner: self)! as! LocalizationCell
            cell.delegate = self
            cell.language = language
            cell.value = row < dataSource.numberOfRows(in: tableView) ? dataSource.getLocalization(language: language, row: row) : nil
            return cell
        }
    }
}

// MARK: - LocalizationCellDelegate

extension ViewController: LocalizationCellDelegate {
    func userDidUpdateLocalizationString(language: String, key: String, with value: String, message: String?) {
        dataSource.updateLocalization(language: language, key: key, with: value, message: message)
    }
}

// MARK: - ActionsCellDelegate

extension ViewController: ActionsCellDelegate {
    func userDidRequestRemoval(of key: String) {
        dataSource.deleteLocalization(key: key)

        // reload keeping scroll position
        let rect = tableView.visibleRect
        filter()
        tableView.scrollToVisible(rect)
    }
}

// MARK: - WindowControllerToolbarDelegate

extension ViewController: WindowControllerToolbarDelegate {
    /**
     Invoked when user requests adding a new translation
     */
    func userDidRequestAddNewTranslation() {
        let addViewController = storyboard!.instantiateController(withIdentifier: "Add") as! AddViewController
        addViewController.delegate = self
        presendedAddViewController = addViewController
        presentAsSheet(addViewController)
    }

    /**
     Invoked when user requests filter change

     - Parameter filter: new filter setting
     */
    func userDidRequestFilterChange(filter: Filter) {
        guard currentFilter != filter else {
            return
        }

        currentFilter = filter
        self.filter()
    }

    /**
     Invoked when user requests searching

     - Parameter searchTerm: new search term
     */
    func userDidRequestSearch(searchTerm: String) {
        guard currentSearchTerm != searchTerm else {
            return
        }

        currentSearchTerm = searchTerm
        filter()
    }

    /**
     Invoked when user request change of the selected localization group

     - Parameter group: new localization group title
     */
    func userDidRequestLocalizationGroupChange(group: String) {
        let languages = dataSource.selectGroupAndGetLanguages(for: group)
        reloadData(with: languages, title: group)
    }

    /**
     Invoked when user requests opening a folder
     */
    func userDidRequestFolderOpen() {
        openFolder()
    }
}

// MARK: - AddViewControllerDelegate

extension ViewController: AddViewControllerDelegate {
    func userDidCancel() {
        dismiss()
    }

    func userDidAddTranslation(key: String, message: String?) {
        dismiss()

        dataSource.addLocalizationKey(key: key, message: message)
        filter()

        if let row = dataSource.getRowForKey(key: key) {
            DispatchQueue.main.async {
                self.tableView.scrollRowToVisible(row)
            }
        }
    }

    private func dismiss() {
        guard let presendedAddViewController = presendedAddViewController else {
            return
        }

        dismiss(presendedAddViewController)
    }
}
