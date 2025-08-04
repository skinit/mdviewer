#!/usr/bin/swift

import Cocoa
@preconcurrency import WebKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Global Scope & Configuration

let allowedExtensions = [".html", ".htm", ".md", ".markdown"]
var outputFilePath: String? = nil


func printHelp() {
    print("""
    HTML/Markdown Viewer - Minimal, mask-based.

    USAGE:
      ThisScript.swift [OPTIONS] [MASKS...]

    OPTIONS:
      --help              Show this help message and exit
      --css FILE          Use a custom CSS file for styling Markdown output
      --output FILE       Write rendered HTML to FILE and exit (no window opened)

    MASKS:
      One or more file masks, e.g. *.md docs/*.html my*.*
      Only .html, .htm, .md, .markdown files are shown.
      If no masks are provided, a file selector dialog will appear.

    KEYBOARD SHORTCUTS:
      0                   First file
      $                   Last file
      j                   Previous file
      k                   Next file
      p                   Print
      q                   Quit
      +                   Increase font size
      -                   Decrease font size
      =                   Reset font size to normal
      w                   Save current file (output to HTML)
      o                   Open files
      /                   Search in document
      n                   Next search result
      N                   Previous search result
      Home                Scroll to top of document

    EXAMPLES:
      ThisScript.swift "*.html"
      ThisScript.swift my*.* --css style.css
      ThisScript.swift docs/*.md
      ThisScript.swift # Opens file selector
      ThisScript.swift readme.md --output output.html  # Renders to file without UI

    REQUIREMENTS:
      - For Markdown rendering: pandoc (install with 'brew install pandoc')
  """)
}

if CommandLine.arguments.contains("--help") {
    printHelp()
    exit(0)
}

// Pandoc check
let pandocCheckTask = Process()
pandocCheckTask.launchPath = "/usr/bin/env"
pandocCheckTask.arguments = ["which", "pandoc"]
let pandocCheckPipe = Pipe()
pandocCheckTask.standardOutput = pandocCheckPipe
pandocCheckTask.standardError = pandocCheckPipe
do { try pandocCheckTask.run(); pandocCheckTask.waitUntilExit() } catch {}
let pandocInstalled = pandocCheckTask.terminationStatus == 0

// Parse switches and masks
var cssPath: String? = nil
var masks: [String] = []
var i = 1 // Start at the first argument

while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]
    
    if arg == "--css" {
        if i + 1 < CommandLine.arguments.count {
            cssPath = CommandLine.arguments[i + 1]
            if !cssPath!.hasPrefix("/") {
                let currentDir = FileManager.default.currentDirectoryPath
                cssPath = "\(currentDir)/\(cssPath!)"
            }
            if !FileManager.default.fileExists(atPath: cssPath!) {
                print("Warning: CSS file not found: \(cssPath!)")
                cssPath = nil
            }
            i += 2
        } else {
            print("Warning: --css option requires a file path argument.")
            i += 1
        }
    } else if arg == "--output" {
        if i + 1 < CommandLine.arguments.count {
            outputFilePath = CommandLine.arguments[i + 1]
            // Convert relative path to absolute if needed
            if !outputFilePath!.hasPrefix("/") {
                let currentDir = FileManager.default.currentDirectoryPath
                outputFilePath = "\(currentDir)/\(outputFilePath!)"
            }
            i += 2
        } else {
            print("Warning: --output option requires a file path argument.")
            i += 1
        }
    } else if !arg.hasPrefix("--") {
        masks.append(arg)
        i += 1
    } else {
        i += 1
    }
}

// Function to resolve relative path to absolute path
func resolveAbsolutePath(_ path: String) -> String {
    if path.hasPrefix("/") {
        return path // Already absolute
    } else {
        let currentDir = FileManager.default.currentDirectoryPath
        return "\(currentDir)/\(path)"
    }
}

// Function to show file selector dialog
func showFileSelector() -> [String] {
    let openPanel = NSOpenPanel()
    openPanel.title = "Select HTML or Markdown files"
    openPanel.allowsMultipleSelection = true
    openPanel.canChooseDirectories = false
    openPanel.canChooseFiles = true
    
    if #available(macOS 11.0, *) {
        let markdownTypes = ["md", "markdown"].compactMap { UTType(filenameExtension: $0) }
        openPanel.allowedContentTypes = [.html] + markdownTypes
    } else {
        openPanel.allowedFileTypes = ["html", "htm", "md", "markdown"]
    }
    
    let result = openPanel.runModal()
    if result == .OK {
        return openPanel.urls.map { $0.path }
    }
    return []
}

// Expand masks to file paths
func expandMasks(_ masks: [String]) -> [String] {
    var files: [String] = []
    let fm = FileManager.default
    for mask in masks {
        // Handle relative paths in masks
        let resolvedMask = resolveAbsolutePath(mask)
        let url = URL(fileURLWithPath: resolvedMask)
        let dir = url.deletingLastPathComponent().path.isEmpty ? "." : url.deletingLastPathComponent().path
        let pattern = url.lastPathComponent
        if let items = try? fm.contentsOfDirectory(atPath: dir) {
            for item in items {
                let full = "\(dir)/\(item)"
                let ext = item.lowercased().split(separator: ".").last.map { ".\($0)" } ?? ""
                if !allowedExtensions.contains(ext) { continue }
                if matchesPattern(item, pattern: pattern) {
                    files.append(full)
                }
            }
        }
    }
    return files.sorted(by: >)
}

func matchesPattern(_ filename: String, pattern: String) -> Bool {
    let regexPattern = "^" + pattern
        .replacingOccurrences(of: ".", with: "\\.")
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".") + "$"
    do {
        let regex = try NSRegularExpression(pattern: regexPattern, options: [])
        let range = NSRange(location: 0, length: filename.utf16.count)
        return regex.firstMatch(in: filename, options: [], range: range) != nil
    } catch { return false }
}

// Get default CSS function
func getDefaultCSS() -> String {
    return """
    body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;line-height:1.6;color:#333;max-width:900px;margin:0 auto;padding:20px;background-color:#fff}h1,h2,h3,h4,h5,h6{margin-top:24px;margin-bottom:16px;font-weight:600;line-height:1.25}h1{font-size:2em;border-bottom:1px solid #eaecef;padding-bottom:.3em}h2{font-size:1.5em;border-bottom:1px solid #eaecef;padding-bottom:.3em}h3{font-size:1.25em}h4{font-size:1em}h5{font-size:.875em}h6{font-size:.85em;color:#6a737d}pre{background-color:#f6f8fa;border-radius:3px;padding:16px;overflow:auto}code{background-color:rgba(27,31,35,.05);border-radius:3px;font-family:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace;font-size:85%;padding:.2em .4em}pre code{background-color:transparent;padding:0}blockquote{border-left:4px solid #dfe2e5;color:#6a737d;padding:0 1em;margin:0 0 16px}img{max-width:100%}table{border-collapse:collapse;width:100%;margin-bottom:16px}table th,table td{border:1px solid #dfe2e5;padding:6px 13px}table tr{background-color:#fff;border-top:1px solid #c6cbd1}table tr:nth-child(2n){background-color:#f6f8fa}@media print{body{max-width:100%;margin:0;padding:0}}
    """
}

// MARK: - HTML Generation Function for Output Mode
func generateHTMLOutput(filePath: String) -> String? {
    let fileURL = URL(fileURLWithPath: filePath)
    let ext = fileURL.pathExtension.lowercased()
    
    if ext == "html" || ext == "htm" {
        // For HTML files, just read the content
        return try? String(contentsOf: fileURL, encoding: .utf8)
    } else {
        // For Markdown files, render using pandoc
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempHtmlPath = tempDir.appendingPathComponent("output.html").path
            
            let pandocTask = Process()
            pandocTask.launchPath = "/usr/bin/env"
            pandocTask.arguments = [
                "pandoc", filePath, "--from=markdown", "--to=html5", "--embed-resources",
                "--standalone", "--highlight-style=pygments", "--mathjax", "-o", tempHtmlPath
            ]
            try pandocTask.run(); pandocTask.waitUntilExit()
            
            if pandocTask.terminationStatus != 0 {
                throw NSError(domain: "PandocError", code: Int(pandocTask.terminationStatus), 
                              userInfo: [NSLocalizedDescriptionKey: "Pandoc conversion failed"])
            }
            
            var htmlContent = try String(contentsOfFile: tempHtmlPath, encoding: .utf8)
            if let headEndRange = htmlContent.range(of: "</head>") {
                // Get styles (either custom from --css or the default)
                let displayStyles = (try? String(contentsOfFile: cssPath ?? "", encoding: .utf8)) ?? getDefaultCSS()
                
                let printOverrides = """
                @media print {
                    body {
                        margin: 0 !important;
                        padding: 0.5in !important; /* Add some padding for the printer */
                        width: auto !important;
                        max-width: 100% !important;
                        font-size: 12pt; /* Use points for print */
                    }
                    pre, blockquote {
                        page-break-inside: avoid; /* Prevent code blocks from being split across pages */
                    }
                }
                """
                
                let combinedCSS = displayStyles + "\n\n" + printOverrides
                let styleTag = "<style>\n\(combinedCSS)\n</style>\n"
                htmlContent.insert(contentsOf: styleTag, at: headEndRange.lowerBound)
            }
            
            return htmlContent
            
        } catch {
            print("Error: Failed to process markdown file: \(error.localizedDescription)")
            return nil
        }
    }
}

// Process output mode if --output is specified
if let outputPath = outputFilePath {
    if masks.isEmpty {
        print("Error: When using --output, you must specify an input file")
        exit(1)
    }
    
    // Get the files from masks (should be just one file in normal usage)
    let files = expandMasks(masks)
    if files.isEmpty {
        print("Error: No matching HTML or Markdown files found.")
        exit(1)
    }
    
    // Just process the first file if multiple are matched
    let filePath = files[0]
    if let htmlContent = generateHTMLOutput(filePath: filePath) {
        do {
            try htmlContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Output written to: \(outputPath)")
            exit(0)
        } catch {
            print("Error writing to output file: \(error.localizedDescription)")
            exit(1)
        }
    } else {
        print("Error generating HTML output")
        exit(1)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var bgView: NSView!
    var files: [String] = []
    var currentIndex: Int = 0
    var currentHTML: String? = nil
    var zoomLevel: Double = 1.0  // Track current zoom level
    
    // Search functionality
    var searchPhrase: String = ""
    var currentSearchIndex: Int = -1
    var totalSearchMatches: Int = 0
    var isSearchPopupActive: Bool = false  // Track if search popup is active

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        if masks.isEmpty {
            files = showFileSelector()
            if files.isEmpty {
                NSApp.terminate(nil); return
            }
        } else {
            files = expandMasks(masks)
            if files.isEmpty {
                print("No matching HTML or Markdown files found.")
                NSApp.terminate(nil); return
            }
        }
        setupWindow()
        loadFile(at: 0)
    }

    func setupWindow() {
        let screen = getCurrentScreen()
        let screenFrame = screen.visibleFrame
        let windowWidth = screenFrame.width * 0.7
        let windowHeight = screenFrame.height * 0.9
        let windowRect = NSRect(x: screenFrame.origin.x + (screenFrame.width - windowWidth) / 2,
                                y: screenFrame.origin.y + (screenFrame.height - windowHeight) / 2,
                                width: windowWidth, height: windowHeight)
        
        window = NSWindow(contentRect: windowRect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MDViewer"
        window.delegate = self

        bgView = NSView(frame: window.contentView!.bounds)
        bgView.autoresizingMask = [.width, .height]
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = NSColor.white.cgColor
        window.contentView = bgView

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: bgView.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        bgView.addSubview(webView)

        setupMenu()
        window.makeKeyAndOrderFront(nil)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // If search popup is active, don't intercept keystrokes
            if self.isSearchPopupActive {
                return event
            }
            
            // Check for key modifiers (for Shift+o)
            let isShiftDown = (event.modifierFlags.contains(.shift))
            let character = event.charactersIgnoringModifiers?.lowercased()
            
            // Check for special keys
            let keyCode = event.keyCode
            
            // Home key (pos1) pressed
            if keyCode == 115 { // 115 is the key code for Home on macOS
                self.scrollToTop()
                return nil
            }
            
            // Handle based on character and modifiers
            switch character {
            case "0": self.navigateToFirstFile(); return nil
            case "$": self.navigateToLastFile(); return nil
            case "j": self.navigateToPreviousFile(); return nil
            case "k": self.navigateToNextFile(); return nil
            case "p": self.printDocument(self); return nil
            case "q": NSApp.terminate(nil); return nil
            case "+": self.increaseFontSize(); return nil
            case "-", "_": self.decreaseFontSize(); return nil
            case "=": self.resetFontSize(); return nil
            case "o": self.openFiles(self); return nil
            case "w": self.saveDocumentAs(self); return nil
            case "/": self.showSearchInput(); return nil
            case "n": 
                if isShiftDown {
                    self.navigateToPreviousSearchResult()
                } else {
                    self.navigateToNextSearchResult()
                }
                return nil
            default: return event
            }
        }
    }

    // Add this method to the AppDelegate class
    func scrollToTop() {
        webView.evaluateJavaScript("window.scrollTo(0, 0);", completionHandler: nil)
    }

    // Add this selector method to the AppDelegate class
    @objc func scrollToTopAction(_ sender: Any) {
        scrollToTop()
    }

    // Add methods for font size adjustment
    func increaseFontSize() {
        zoomLevel += 0.1
        if zoomLevel > 3.0 { zoomLevel = 3.0 }  // Limit maximum zoom
        webView.evaluateJavaScript("document.body.style.zoom = '\(zoomLevel)'", completionHandler: nil)
    }
    
    func decreaseFontSize() {
        zoomLevel -= 0.1
        if zoomLevel < 0.5 { zoomLevel = 0.5 }  // Limit minimum zoom
        webView.evaluateJavaScript("document.body.style.zoom = '\(zoomLevel)'", completionHandler: nil)
    }
    
    // Method to reset font size to normal
    func resetFontSize() {
        zoomLevel = 1.0
        webView.evaluateJavaScript("document.body.style.zoom = '1.0'", completionHandler: nil)
    }
    
    // Search functionality methods - Updated to use a custom search panel
    func showSearchInput() {
        // Create a custom panel window for search input
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        panel.title = "Search in Document"
        panel.center()
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.delegate = self
        
        // Create the content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 60))
        
        // Add a search icon
        let iconView = NSImageView(frame: NSRect(x: 15, y: 18, width: 24, height: 24))
        if let searchImage = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search") {
            iconView.image = searchImage
            iconView.contentTintColor = NSColor.secondaryLabelColor
        }
        contentView.addSubview(iconView)
        
        // Add the search text field
        let textField = NSTextField(frame: NSRect(x: 45, y: 18, width: 260, height: 24))
        textField.placeholderString = "Search text..."
        textField.stringValue = searchPhrase
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none
        contentView.addSubview(textField)
        
        // Add search button
        let searchButton = NSButton(frame: NSRect(x: 315, y: 18, width: 70, height: 24))
        searchButton.title = "Search"
        searchButton.bezelStyle = .rounded
        searchButton.setButtonType(.momentaryPushIn)
        contentView.addSubview(searchButton)
        
        // Set content view and behavior
        panel.contentView = contentView
        panel.initialFirstResponder = textField  // Focus the text field
        panel.isReleasedWhenClosed = false
        
        // Set action for search button
        searchButton.target = self
        searchButton.action = #selector(performSearchFromPanel(_:))
        
        // Set action for pressing Enter in text field
        textField.target = self
        textField.action = #selector(performSearchFromPanel(_:))
        
        // Store reference to the text field for the button action
        objc_setAssociatedObject(searchButton, "textField", textField, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(panel, "textField", textField, .OBJC_ASSOCIATION_RETAIN)
        
        // Track when search popup is active
        self.isSearchPopupActive = true
        
        // Show the panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        
        // Set handler for panel close
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: nil) { [weak self] _ in
            self?.isSearchPopupActive = false
            NotificationCenter.default.removeObserver(self as Any, name: NSWindow.willCloseNotification, object: panel)
        }
    }

    @objc func performSearchFromPanel(_ sender: Any) {
        // Get the text field from the sender
        var textField: NSTextField?
        
        if let button = sender as? NSButton {
            textField = objc_getAssociatedObject(button, "textField") as? NSTextField
        } else if let field = sender as? NSTextField {
            textField = field
        }
        
        guard let textField = textField else { return }
        
        // Get the search phrase
        let newSearchPhrase = textField.stringValue
        
        // Close the panel
        if let panel = textField.window {
            panel.close()
        }
        
        // Perform the search
        if newSearchPhrase.isEmpty {
            clearSearch()
        } else {
            searchPhrase = newSearchPhrase
            performSearch()
        }
    }

    // Add method to perform search
    func performSearch() {
        let jsScript = """
        (function() {
            // First clear any existing highlights
            var oldHighlights = document.querySelectorAll('.search-highlight');
            for (var i = 0; i < oldHighlights.length; i++) {
                var parent = oldHighlights[i].parentNode;
                parent.replaceChild(document.createTextNode(oldHighlights[i].textContent), oldHighlights[i]);
            }
            document.normalize();
            
            // Now perform the new search
            var searchText = "\(searchPhrase.replacingOccurrences(of: "\"", with: "\\\""))";
            if (!searchText) return { count: 0 };
            
            var count = 0;
            var textNodes = [];
            
            function findTextNodes(node) {
                if (node.nodeType === 3) {
                    textNodes.push(node);
                } else if (node.nodeType === 1 && node.childNodes) {
                    for (var i = 0; i < node.childNodes.length; i++) {
                        findTextNodes(node.childNodes[i]);
                    }
                }
            }
            
            findTextNodes(document.body);
            
            for (var i = 0; i < textNodes.length; i++) {
                var node = textNodes[i];
                var content = node.textContent;
                var position = content.toLowerCase().indexOf(searchText.toLowerCase());
                
                while (position !== -1) {
                    count++;
                    var before = content.substring(0, position);
                    var matched = content.substring(position, position + searchText.length);
                    var after = content.substring(position + searchText.length);
                    
                    var span = document.createElement('span');
                    span.className = 'search-highlight';
                    span.setAttribute('data-search-index', count - 1);
                    span.style.backgroundColor = 'yellow';
                    span.style.color = 'red';
                    span.textContent = matched;
                    
                    var beforeNode = document.createTextNode(before);
                    var afterNode = document.createTextNode(after);
                    
                    var parent = node.parentNode;
                    parent.insertBefore(beforeNode, node);
                    parent.insertBefore(span, node);
                    parent.insertBefore(afterNode, node);
                    parent.removeChild(node);
                    
                    node = afterNode;
                    content = after;
                    position = content.toLowerCase().indexOf(searchText.toLowerCase());
                }
            }
            
            return { count: count };
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let resultDict = result as? [String: Any],
               let count = resultDict["count"] as? Int {
                self.totalSearchMatches = count
                self.currentSearchIndex = count > 0 ? 0 : -1
                
                if count > 0 {
                    self.navigateToSearchResult(self.currentSearchIndex)
                    self.window.title = "\(URL(fileURLWithPath: self.files[self.currentIndex]).lastPathComponent) [\(self.currentIndex + 1)/\(self.files.count)] - \(self.currentSearchIndex + 1)/\(self.totalSearchMatches) matches"
                } else {
                    NSSound.beep()
                    self.window.title = "\(URL(fileURLWithPath: self.files[self.currentIndex]).lastPathComponent) [\(self.currentIndex + 1)/\(self.files.count)] - No matches"
                }
            }
        }
    }

    // Add method to navigate to specific search result
    func navigateToSearchResult(_ index: Int) {
        guard index >= 0 && index < totalSearchMatches else { return }
        
        currentSearchIndex = index
        
        let jsScript = """
        (function() {
            var highlights = document.querySelectorAll('.search-highlight');
            for (var i = 0; i < highlights.length; i++) {
                highlights[i].style.backgroundColor = 'yellow';
                highlights[i].style.color = 'red';
            }
            
            var current = document.querySelector('.search-highlight[data-search-index="\(index)"]');
            if (current) {
                current.style.backgroundColor = 'orange';
                current.style.color = 'darkred';
                current.scrollIntoView({behavior: 'smooth', block: 'center'});
                return true;
            }
            return false;
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let success = result as? Bool, success {
                self.window.title = "\(URL(fileURLWithPath: self.files[self.currentIndex]).lastPathComponent) [\(self.currentIndex + 1)/\(self.files.count)] - \(self.currentSearchIndex + 1)/\(self.totalSearchMatches) matches"
            }
        }
    }

    // Add method to navigate to next search result
    func navigateToNextSearchResult() {
        guard totalSearchMatches > 0 else { NSSound.beep(); return }
        
        let nextIndex = (currentSearchIndex + 1) % totalSearchMatches
        navigateToSearchResult(nextIndex)
    }

    // Add method to navigate to previous search result
    func navigateToPreviousSearchResult() {
        guard totalSearchMatches > 0 else { NSSound.beep(); return }
        
        let prevIndex = (currentSearchIndex - 1 + totalSearchMatches) % totalSearchMatches
        navigateToSearchResult(prevIndex)
    }

    // Add method to clear search highlights
    func clearSearch() {
        searchPhrase = ""
        currentSearchIndex = -1
        totalSearchMatches = 0
        
        let jsScript = """
        (function() {
            var oldHighlights = document.querySelectorAll('.search-highlight');
            for (var i = 0; i < oldHighlights.length; i++) {
                var parent = oldHighlights[i].parentNode;
                parent.replaceChild(document.createTextNode(oldHighlights[i].textContent), oldHighlights[i]);
            }
            document.normalize();
            return true;
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { [weak self] (_, _) in
            guard let self = self else { return }
            self.window.title = "\(URL(fileURLWithPath: self.files[self.currentIndex]).lastPathComponent) [\(self.currentIndex + 1)/\(self.files.count)]"
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if url.isFileURL || url.scheme == nil || url.scheme == "about" || (url.fragment != nil && url.scheme == nil) {
            decisionHandler(.allow)
        } else if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func getCurrentScreen() -> NSScreen {
        return NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
    }

    func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = mainMenu.addItem(withTitle: "App", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        mainMenu.setSubmenu(appMenu, for: appMenuItem)
        appMenu.addItem(withTitle: "Next File (k)", action: #selector(nextFile(_:)), keyEquivalent: "k")
        appMenu.addItem(withTitle: "Previous File (j)", action: #selector(previousFile(_:)), keyEquivalent: "j")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Open Files... (Shift+o)", action: #selector(openFiles(_:)), keyEquivalent: "O") // Capital O = Shift+o
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit (q)", action: #selector(exitApp(_:)), keyEquivalent: "q")
        
        let fileMenuItem = mainMenu.addItem(withTitle: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        mainMenu.setSubmenu(fileMenu, for: fileMenuItem)
        fileMenu.addItem(withTitle: "Open Files... (Shift+o)", action: #selector(openFiles(_:)), keyEquivalent: "O")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save As... (o)", action: #selector(saveDocumentAs(_:)), keyEquivalent: "o") // lowercase o
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Print... (p)", action: #selector(printDocument(_:)), keyEquivalent: "p")
        
        // View menu with zoom options
        let viewMenuItem = mainMenu.addItem(withTitle: "View", action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: "View")
        mainMenu.setSubmenu(viewMenu, for: viewMenuItem)
        viewMenu.addItem(withTitle: "Increase Font Size (+)", action: #selector(increaseFont(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Decrease Font Size (-)", action: #selector(decreaseFont(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Reset Font Size (=)", action: #selector(resetFont(_:)), keyEquivalent: "=")
        
        // Search section in view menu
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Search (/)", action: #selector(showSearch(_:)), keyEquivalent: "/")
        viewMenu.addItem(withTitle: "Next Match (n)", action: #selector(nextMatch(_:)), keyEquivalent: "n")
        viewMenu.addItem(withTitle: "Previous Match (N)", action: #selector(previousMatch(_:)), keyEquivalent: "N")
        
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Scroll to Top (Home)", action: #selector(scrollToTopAction(_:)), keyEquivalent: "") // No key equivalent as we handle the Home key separately

        NSApp.mainMenu = mainMenu
    }

    @objc func nextFile(_ sender: Any) { navigateToNextFile() }
    @objc func previousFile(_ sender: Any) { navigateToPreviousFile() }
    @objc func exitApp(_ sender: Any) { NSApp.terminate(nil) }
    @objc func increaseFont(_ sender: Any) { increaseFontSize() }
    @objc func decreaseFont(_ sender: Any) { decreaseFontSize() }
    @objc func resetFont(_ sender: Any) { resetFontSize() }
    @objc func showSearch(_ sender: Any) { showSearchInput() }
    @objc func nextMatch(_ sender: Any) { navigateToNextSearchResult() }
    @objc func previousMatch(_ sender: Any) { navigateToPreviousSearchResult() }
    
    @objc func openFiles(_ sender: Any) {
        let selectedFiles = showFileSelector()
        if !selectedFiles.isEmpty {
            self.files = selectedFiles.sorted()
            self.currentIndex = 0
            loadFile(at: 0)
        }
    }

    @objc func saveDocumentAs(_ sender: Any) {
        guard let htmlContent = self.currentHTML, !htmlContent.isEmpty else {
            NSSound.beep(); return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save HTML"
        let currentFileURL = URL(fileURLWithPath: files[currentIndex])
        let suggestedName = currentFileURL.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(suggestedName).html"

        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [.html]
        } else {
            savePanel.allowedFileTypes = ["html"]
        }

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try htmlContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Saving File"
                alert.informativeText = "Could not save the file: \(error.localizedDescription)"
                alert.runModal()
            }
        }
    }
    
    @objc func printDocument(_ sender: Any) {
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .portrait
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.topMargin = 72.0; printInfo.bottomMargin = 72.0
        printInfo.leftMargin = 72.0; printInfo.rightMargin = 72.0
        
        let printOperation = self.webView.printOperation(with: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    func loadFile(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        currentIndex = index
        loadCurrentFile()
    }

    func loadCurrentFile() {
        let filePath = files[currentIndex]
        let fileURL = URL(fileURLWithPath: filePath)
        let ext = fileURL.pathExtension.lowercased()
        window.title = "\(fileURL.lastPathComponent) [\(currentIndex + 1)/\(files.count)]"
        
        // Reset zoom level when loading a new file
        zoomLevel = 1.0
        
        // Clear any previous search
        clearSearch()
        
        if ext == "html" || ext == "htm" {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
            currentHTML = try? String(contentsOf: fileURL, encoding: .utf8)
        } else {
            renderMarkdown(filePath: filePath)
        }
    }

    func renderMarkdown(filePath: String) {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempHtmlPath = tempDir.appendingPathComponent("output.html").path
            
            let pandocTask = Process()
            pandocTask.launchPath = "/usr/bin/env"
            pandocTask.arguments = [
                "pandoc", filePath, "--from=markdown", "--to=html5", "--embed-resources",
                "--standalone", "--highlight-style=pygments", "--mathjax", "-o", tempHtmlPath
            ]
            try pandocTask.run(); pandocTask.waitUntilExit()
            
            if pandocTask.terminationStatus != 0 {
                throw NSError(domain: "PandocError", code: Int(pandocTask.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Pandoc conversion failed"])
            }
            
            var htmlContent = try String(contentsOfFile: tempHtmlPath, encoding: .utf8)
            if let headEndRange = htmlContent.range(of: "</head>") {
                // Get the main display styles (either custom from --css or the default)
                let displayStyles = (try? String(contentsOfFile: cssPath ?? "", encoding: .utf8)) ?? getDefaultCSS()

                // Define a robust, separate @media print block. This will be appended
                // to the display styles, ensuring printing works correctly even with custom CSS.
                let printOverrides = """
                @media print {
                    body {
                        margin: 0 !important;
                        padding: 0.5in !important; /* Add some padding for the printer */
                        width: auto !important;
                        max-width: 100% !important;
                        font-size: 12pt; /* Use points for print */
                    }
                    pre, blockquote {
                        page-break-inside: avoid; /* Prevent code blocks from being split across pages */
                    }
                }
                """
                
                // Combine the display styles with the guaranteed print styles
                let combinedCSS = displayStyles + "\n\n" + printOverrides
                
                let styleTag = "<style>\n\(combinedCSS)\n</style>\n"
                htmlContent.insert(contentsOf: styleTag, at: headEndRange.lowerBound)
            }
            
            currentHTML = htmlContent
            try htmlContent.write(toFile: tempHtmlPath, atomically: true, encoding: .utf8)
            let tempHtmlURL = URL(fileURLWithPath: tempHtmlPath)
            webView.loadFileURL(tempHtmlURL, allowingReadAccessTo: tempDir)
            
        } catch {
            let errorHTML = "<html><body><h1>Error</h1><p>Failed to process markdown file: \(error.localizedDescription)</p></body></html>"
            webView.loadHTMLString(errorHTML, baseURL: nil)
            currentHTML = errorHTML
        }
    }

    func navigateToNextFile() {
        let nextIndex = (currentIndex + 1) % files.count
        if nextIndex <= currentIndex { NSSound.beep() }
        loadFile(at: nextIndex)
    }
    
    func navigateToPreviousFile() {
        let prevIndex = currentIndex > 0 ? currentIndex - 1 : files.count - 1
        if prevIndex >= currentIndex { NSSound.beep() }
        loadFile(at: prevIndex)
    }

    func navigateToFirstFile() {
        loadFile(at: 0)
    }

    func navigateToLastFile() {
        loadFile(at: files.count - 1)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillFinishLaunching(_ notification: Notification) {}
}

// MARK: - App Execution
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
NSApp.setActivationPolicy(.regular)
app.run()

