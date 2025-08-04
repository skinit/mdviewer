# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a standalone Swift application for macOS that provides a markdown and HTML viewer with file navigation capabilities. The application is built as a single Swift script (`mdviewer.swift`) that creates a native macOS app using Cocoa and WebKit frameworks.

## Development Commands

### Running the Application
```bash
# Run directly with Swift
swift mdviewer.swift

# Run with file masks
swift mdviewer.swift "*.md"
swift mdviewer.swift "docs/*.html"

# Run with custom CSS
swift mdviewer.swift --css assets/github.css "*.md"

# Generate HTML output without GUI
swift mdviewer.swift readme.md --output output.html
```

### Dependencies
- **pandoc**: Required for Markdown rendering. Install with `brew install pandoc`
- The application checks for pandoc availability at startup

### Making the Script Executable
```bash
chmod +x mdviewer.swift
./mdviewer.swift
```

## Architecture Overview

### Core Components

**AppDelegate (lines 288-913)**
- Main application controller implementing NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate
- Manages file navigation, search functionality, and UI interactions
- Handles keyboard shortcuts and menu operations

**File Management**
- `expandMasks()` (lines 153-174): Expands file glob patterns to actual file paths
- `matchesPattern()` (lines 176-186): Pattern matching for file selection
- Supports .html, .htm, .md, .markdown files only

**Rendering System**
- HTML files: Direct loading via WebKit
- Markdown files: Converted to HTML using pandoc with embedded resources
- CSS styling: Default styles or custom CSS via `--css` flag
- Print support: Dedicated print CSS rules automatically injected

**Search Functionality (lines 427-686)**
- In-document text search with highlighting
- Custom search panel UI
- Navigation between search results with keyboard shortcuts
- JavaScript-based highlighting system

### Key Features

**Navigation**
- Multi-file navigation with keyboard shortcuts (j/k for prev/next)
- File selector dialog when no masks provided
- Support for glob patterns in file selection

**Styling System**
- 16 predefined CSS themes in `/assets/` directory
- Custom CSS support via `--css` parameter
- Built-in default GitHub-like styling
- Automatic print CSS optimization

**UI Controls**
- Font size adjustment (+, -, =)
- Document search (/, n, N)
- File operations (o for open, w for save, p for print)
- Scroll to top (Home key)

### File Structure
```
mdviewer/
├── mdviewer.swift          # Main application (single file)
├── assets/                 # CSS theme files
│   ├── github.css
│   ├── modern.css
│   ├── elegant.css
│   └── [13 other themes]
```

## Development Notes

- This is a single-file Swift application with no build system or package management
- All functionality is contained within `mdviewer.swift`
- CSS themes are standalone files that can be referenced via `--css` flag
- The application uses temporary files for pandoc HTML conversion
- WebKit security allows file:// URLs with appropriate read access permissions

## Testing the Application

Test with various file types:
```bash
swift mdviewer.swift "*.md" "*.html"
swift mdviewer.swift --css assets/modern.css README.md
swift mdviewer.swift test.md --output test.html  # Test output mode
```