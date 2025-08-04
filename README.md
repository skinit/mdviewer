# MDViewer

A lightweight, native macOS application for viewing Markdown and HTML files with elegant styling and powerful navigation features.

## Features

- **Multi-format support**: View `.md`, `.markdown`, `.html`, and `.htm` files
- **Beautiful themes**: 16 built-in CSS themes for different viewing preferences
- **Fast navigation**: Navigate between multiple files with keyboard shortcuts
- **Search functionality**: Find and navigate through text within documents
- **Print support**: Optimized printing with proper page formatting
- **Font control**: Adjust font size on the fly
- **File operations**: Save rendered HTML, open new files
- **Custom styling**: Use your own CSS files for personalized themes

## Installation

### Prerequisites

- macOS (any recent version)
- [Pandoc](https://pandoc.org/) for Markdown rendering:
  ```bash
  brew install pandoc
  ```

### Download and Run

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/mdviewer.git
   cd mdviewer
   ```

2. Make the script executable:
   ```bash
   chmod +x mdviewer.swift
   ```

3. Run the application:
   ```bash
   ./mdviewer.swift
   ```

## Usage

### Basic Usage

```bash
# Open file selector dialog
./mdviewer.swift

# View specific files
./mdviewer.swift README.md
./mdviewer.swift "*.md"
./mdviewer.swift "docs/*.html"

# Use custom CSS theme
./mdviewer.swift --css assets/github.css "*.md"

# Generate HTML output without opening viewer
./mdviewer.swift README.md --output rendered.html
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `j` | Previous file |
| `k` | Next file |
| `0` | First file |
| `$` | Last file |
| `o` | Open new files |
| `w` | Save current file as HTML |
| `p` | Print document |
| `q` | Quit application |
| `+` | Increase font size |
| `-` | Decrease font size |
| `=` | Reset font size |
| `/` | Search in document |
| `n` | Next search result |
| `N` | Previous search result |
| `Home` | Scroll to top |

### Built-in Themes

The application includes 16 beautiful themes in the `assets/` directory:

- `academic.css` - Clean academic style
- `amber.css` - Warm amber tones
- `business.css` - Professional business look
- `clean.css` - Minimal clean design
- `elegant.css` - Elegant serif typography
- `github.css` - GitHub-style formatting
- `gruvbox.css` - Popular retro color scheme
- `minimalistic.css` - Ultra-minimal design
- `modern.css` - Modern sans-serif styling
- `retro.css` - Vintage terminal look
- `sakura.css` - Gentle pink theme
- `sand.css` - Desert-inspired colors
- `scholary.css` - Academic paper style
- `synthwave.css` - Cyberpunk neon theme
- `tufte.css` - Edward Tufte-inspired layout
- `water.css` - Cool blue tones

Use any theme with:
```bash
./mdviewer.swift --css assets/github.css your-file.md
```

### Command Line Options

```
USAGE:
  mdviewer.swift [OPTIONS] [MASKS...]

OPTIONS:
  --help              Show help message and exit
  --css FILE          Use a custom CSS file for styling
  --output FILE       Write rendered HTML to FILE and exit (no window)

MASKS:
  One or more file patterns, e.g. *.md docs/*.html my*.*
  Only .html, .htm, .md, .markdown files are supported.
  If no masks provided, a file selector dialog appears.
```

## Examples

### View all Markdown files in current directory
```bash
./mdviewer.swift "*.md"
```

### Use a specific theme
```bash
./mdviewer.swift --css assets/synthwave.css README.md
```

### Generate HTML for web publishing
```bash
./mdviewer.swift --css assets/elegant.css --output website.html README.md
```

### View documentation files
```bash
./mdviewer.swift "docs/*.md" "*.markdown"
```

## Architecture

MDViewer is built as a single Swift file (`mdviewer.swift`) using:

- **Cocoa**: Native macOS windowing and UI
- **WebKit**: HTML rendering engine
- **Pandoc**: Markdown to HTML conversion
- **Swift**: Modern, safe systems programming

The application creates a native macOS window with a WebKit view for rendering content. Markdown files are converted to HTML using Pandoc with embedded resources for offline viewing.

## Development

### Project Structure
```
mdviewer/
├── mdviewer.swift          # Main application (single file)
├── assets/                 # CSS theme collection
│   ├── github.css
│   ├── modern.css
│   └── ...                 # 14 other themes
├── README.md               # This file
└── CLAUDE.md              # Development guidance
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with various file types and themes
5. Submit a pull request

### Adding New Themes

To add a new CSS theme:

1. Create a new `.css` file in the `assets/` directory
2. Follow the existing theme structure
3. Test with various Markdown content
4. Ensure print media queries work properly

## License

This project is open source. Feel free to use, modify, and distribute as needed.

## Screenshots

*Add screenshots here showing the application with different themes*

## Troubleshooting

### Pandoc not found
If you see a pandoc error, install it with:
```bash
brew install pandoc
```

### File permissions
If the script won't run, make it executable:
```bash
chmod +x mdviewer.swift
```

### Custom CSS not loading
Ensure your CSS file path is correct and readable:
```bash
ls -la path/to/your/custom.css
```

## Related Projects

- [Pandoc](https://pandoc.org/) - Universal document converter
- [Marked 2](https://marked2app.com/) - Commercial Markdown preview app
- [MacDown](https://macdown.uranusjr.com/) - Open source Markdown editor

---

**MDViewer** - Simple, elegant Markdown and HTML viewing for macOS