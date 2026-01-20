---
name: pdfco
description: Connection skill for PDF.co MCP server. Provides guidance on HTML-to-PDF conversion, document manipulation, and best practices for reliable PDF generation.
metadata:
  version: 1.0.0
  category: development
  tags:
    - pdf
    - documents
    - conversion
    - html
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# PDF.co Integration

This skill provides behavioral guidance for interacting with the PDF.co MCP server.

## Tool Overview

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `html_to_pdf` | Convert HTML to PDF | Reports, quotes, invoices, certificates |
| `pdf_to_text` | Extract text from PDF | Document analysis, content extraction |
| `merge_pdfs` | Combine multiple PDFs | Consolidating documents |
| `split_pdf` | Extract pages from PDF | Breaking apart documents |
| `add_watermark` | Add watermark to PDF | Branding, draft marking |

## html_to_pdf (Primary Tool)

Converts HTML content to a downloadable PDF document.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `html` | Yes | - | HTML content (full document or fragment) |
| `name` | No | "document.pdf" | Output filename |
| `margins` | No | "10mm" | Page margins (CSS format) |
| `paperSize` | No | "Letter" | Paper size: Letter, A4, Legal, Tabloid |
| `orientation` | No | "Portrait" | Portrait or Landscape |
| `header` | No | - | HTML for page header |
| `footer` | No | - | HTML for page footer |

### HTML Best Practices

**CRITICAL: Use inline CSS.** External stylesheets will not load.

**Reliable HTML structure:**
```html
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 10px; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f5f5f5; font-weight: bold; }
    .total { font-weight: bold; background-color: #f9f9f9; }
  </style>
</head>
<body>
  <h1>Document Title</h1>
  <!-- Content here -->
</body>
</html>
```

### What Works Well

- **Tables** - Render reliably for invoices, quotes, data
- **Basic CSS** - Colors, fonts, borders, padding, margins
- **Images** - Use base64 data URLs or absolute URLs
- **Web-safe fonts** - Arial, Helvetica, Times New Roman, Georgia

### What May Have Issues

- **Flexbox/Grid** - Complex layouts may not render as expected
- **External resources** - Fonts, images from external URLs may fail
- **JavaScript** - Not executed
- **CSS variables** - May not be supported

### Document Type Patterns

**For Quotes/Invoices:**
```html
<table>
  <thead>
    <tr><th>Item</th><th>Qty</th><th>Price</th><th>Total</th></tr>
  </thead>
  <tbody>
    <tr><td>Product A</td><td>2</td><td>$50</td><td>$100</td></tr>
  </tbody>
  <tfoot>
    <tr class="total"><td colspan="3">Total</td><td>$100</td></tr>
  </tfoot>
</table>
```

**For Reports:**
```html
<h1>Monthly Report</h1>
<h2>Summary</h2>
<p>Key findings...</p>
<h2>Data</h2>
<table>...</table>
<h2>Recommendations</h2>
<ul><li>Action item 1</li></ul>
```

**For Certificates:**
```html
<div style="text-align: center; padding: 40px;">
  <h1 style="font-size: 36px;">Certificate of Completion</h1>
  <p style="font-size: 24px; margin: 40px 0;">This certifies that</p>
  <p style="font-size: 32px; font-weight: bold;">John Doe</p>
  <p style="margin-top: 40px;">has successfully completed the program.</p>
</div>
```

## Response Handling

**You do not need to handle file URLs.** The system automatically:
1. Detects file URLs in tool results
2. Downloads and stores files securely
3. Displays a download card to the user

**Correct response pattern:**
```
User: "Convert this quote to PDF"
You: [Call html_to_pdf with the HTML]
You: "Done! Your quote PDF is ready." (download card appears automatically)
```

**Do NOT:**
- Paste URLs in your response
- Say "Here's the download link: ..."
- Try to construct download URLs

## pdf_to_text

Extracts text content from PDF documents.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `url` | Yes | URL to the PDF file |
| `pages` | No | Page range: "1-3", "1,3,5", or "all" |

### Best For

- Text-based PDFs (not scanned images)
- Extracting content for analysis
- Converting PDF content to editable text

### Limitations

- Scanned documents need OCR (use `pdf_ocr` instead)
- Formatting is lost (tables become plain text)
- Complex layouts may have jumbled text order

## merge_pdfs

Combines multiple PDF files into a single document.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `urls` | Yes | Array of PDF URLs to merge |
| `name` | No | Output filename |

### Usage Notes

- PDFs merge in the order provided
- All page sizes are preserved
- Bookmarks may not transfer

## split_pdf

Extracts specific pages from a PDF.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `url` | Yes | URL to the PDF file |
| `pages` | Yes | Pages to extract: "1-3", "1,3,5", "1-3,7-9" |

## add_watermark

Adds text watermark to PDF pages.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `url` | Yes | URL to the PDF file |
| `text` | Yes | Watermark text (e.g., "DRAFT", "CONFIDENTIAL") |
| `pages` | No | Which pages (default: all) |
| `opacity` | No | 0-1, lower = more transparent |

## Error Recovery

### "HTML parsing failed"
- Check for unclosed tags
- Ensure valid HTML structure
- Remove problematic CSS

### "Timeout"
- HTML may be too complex
- Simplify styles and structure
- Split into multiple documents

### "Invalid URL"
- For pdf_to_text, merge, split: ensure URL is accessible
- Use publicly accessible URLs or presigned URLs

## Best Practices

1. **Start simple** - Basic HTML first, add styling incrementally
2. **Test structure** - Tables > divs for data layouts
3. **Inline everything** - CSS, small images as base64
4. **Set paper size** - Match intended print format
5. **Use margins** - Prevent content from touching edges
