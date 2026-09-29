"""
Nguyen Du Tool - Universal Document Converter
Supports full bidirectional conversions between PDF, Word (.docx), Excel (.xlsx), and PowerPoint (.pptx).
"""

import os
import io
import sys
import argparse
import subprocess
from pathlib import Path

def convert_pdf_to_docx(input_path: str, output_path: str) -> bool:
    """Convert PDF to Word DOCX preserving text, tables, fonts, and layout."""
    print(f"[PDF -> DOCX] Converting: {input_path} -> {output_path}")

    # 1. Try high-level pdf2docx if available
    try:
        from pdf2docx import Converter
        cv = Converter(input_path)
        cv.convert(output_path, start=0, end=None)
        cv.close()
        print(f"[PDF -> DOCX] Successfully created via pdf2docx: {output_path}")
        return True
    except Exception as e:
        pass

    # 2. Resilient fallback using pdfplumber + python-docx
    try:
        import pdfplumber
        import docx
        from docx.shared import Pt, Inches, RGBColor

        doc = docx.Document()
        for s in doc.sections:
            s.top_margin = Inches(0.75)
            s.bottom_margin = Inches(0.75)
            s.left_margin = Inches(0.75)
            s.right_margin = Inches(0.75)

        with pdfplumber.open(input_path) as pdf:
            for page_idx, page in enumerate(pdf.pages):
                if page_idx > 0:
                    doc.add_page_break()

                tables = page.extract_tables()
                if tables:
                    for table_data in tables:
                        if not table_data:
                            continue
                        t = doc.add_table(rows=len(table_data), cols=len(table_data[0]))
                        t.style = 'Table Grid'
                        for r_idx, row in enumerate(table_data):
                            for c_idx, cell_val in enumerate(row):
                                t.cell(r_idx, c_idx).text = (cell_val or '').strip()
                        doc.add_paragraph()

                text = page.extract_text()
                if text and not tables:
                    for line in text.splitlines():
                        p = doc.add_paragraph(line)
                        p.paragraph_format.line_spacing = 1.15
                        p.paragraph_format.space_after = Pt(2)

        doc.save(output_path)
        print(f"[PDF -> DOCX] Successfully created via pdfplumber+docx: {output_path}")
        return True
    except Exception as err:
        print(f"[PDF -> DOCX] Error: {err}", file=sys.stderr)
        return False

def convert_pdf_to_xlsx(input_path: str, output_path: str) -> bool:
    """Extract tables from PDF into an Excel XLSX spreadsheet."""
    try:
        import pdfplumber
        import openpyxl
        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

        print(f"[PDF -> XLSX] Extracting tables: {input_path} -> {output_path}")
        wb = openpyxl.Workbook()
        default_sheet = wb.active

        header_font = Font(bold=True, color="FFFFFF", name="Arial", size=10)
        header_fill = PatternFill(start_color="1F4E79", end_color="1F4E79", fill_type="solid")
        cell_font = Font(name="Arial", size=10)
        thin_border = Border(
            left=Side(style='thin', color='D9D9D9'),
            right=Side(style='thin', color='D9D9D9'),
            top=Side(style='thin', color='D9D9D9'),
            bottom=Side(style='thin', color='D9D9D9')
        )

        table_found = False
        with pdfplumber.open(input_path) as pdf:
            for page_idx, page in enumerate(pdf.pages, start=1):
                tables = page.extract_tables()
                if not tables:
                    text = page.extract_text()
                    if text:
                        ws = wb.create_sheet(title=f"Page {page_idx} Text"[:31])
                        for r_idx, line in enumerate(text.splitlines(), start=1):
                            ws.cell(row=r_idx, column=1, value=line.strip())
                        table_found = True
                    continue

                for t_idx, table in enumerate(tables, start=1):
                    table_found = True
                    sheet_title = f"P{page_idx}_T{t_idx}" if len(tables) > 1 else f"Page {page_idx}"
                    ws = wb.create_sheet(title=sheet_title[:31])

                    for row_idx, row in enumerate(table, start=1):
                        for col_idx, cell_val in enumerate(row, start=1):
                            cell = ws.cell(row=row_idx, column=col_idx, value=cell_val or '')
                            cell.font = header_font if row_idx == 1 else cell_font
                            cell.border = thin_border
                            if row_idx == 1:
                                cell.fill = header_fill
                                cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
                            else:
                                cell.alignment = Alignment(vertical="center", wrap_text=True)

                    for col in ws.columns:
                        max_len = max(len(str(c.value or '')) for c in col)
                        col_letter = openpyxl.utils.get_column_letter(col[0].column)
                        ws.column_dimensions[col_letter].width = min(max(max_len + 3, 12), 50)

        if not table_found:
            print("[PDF -> XLSX] Warning: No tables or text found in PDF.")
            return False

        if default_sheet in wb.worksheets and len(wb.worksheets) > 1:
            wb.remove(default_sheet)

        wb.save(output_path)
        print(f"[PDF -> XLSX] Successfully created: {output_path}")
        return True
    except Exception as e:
        print(f"[PDF -> XLSX] Error: {e}", file=sys.stderr)
        return False

def convert_pdf_to_pptx(input_path: str, output_path: str) -> bool:
    """Convert PDF pages to PowerPoint presentation slides."""
    try:
        from pptx import Presentation
        from pptx.util import Inches

        print(f"[PDF -> PPTX] Converting pages to slides: {input_path} -> {output_path}")
        prs = Presentation()
        prs.slide_width = Inches(10)
        prs.slide_height = Inches(7.5)
        blank_slide_layout = prs.slide_layouts[6]

        # Try pypdfium2 first
        try:
            import pypdfium2 as pdfium
            pdf = pdfium.PdfDocument(input_path)
            for page in pdf:
                pil_image = page.render(scale=2.0).to_pil()
                img_stream = io.BytesIO()
                pil_image.save(img_stream, format="PNG")
                img_stream.seek(0)

                slide = prs.slides.add_slide(blank_slide_layout)
                slide.shapes.add_picture(img_stream, Inches(0), Inches(0), width=prs.slide_width, height=prs.slide_height)

            prs.save(output_path)
            print(f"[PDF -> PPTX] Successfully created: {output_path}")
            return True
        except Exception:
            pass

        # Fallback to PyMuPDF fitz
        import fitz
        doc = fitz.open(input_path)
        for page_num in range(len(doc)):
            page = doc[page_num]
            zoom = 200 / 72
            mat = fitz.Matrix(zoom, zoom)
            pix = page.get_pixmap(matrix=mat)
            img_data = pix.tobytes("png")

            slide = prs.slides.add_slide(blank_slide_layout)
            img_stream = io.BytesIO(img_data)
            slide.shapes.add_picture(img_stream, Inches(0), Inches(0), width=prs.slide_width, height=prs.slide_height)

        prs.save(output_path)
        print(f"[PDF -> PPTX] Successfully created: {output_path}")
        return True
    except Exception as e:
        print(f"[PDF -> PPTX] Error: {e}", file=sys.stderr)
        return False

def convert_office_to_pdf_libreoffice(input_path: str, output_path: str) -> bool:
    """Convert any Office format (docx, xlsx, pptx) to PDF via LibreOffice headless if present."""
    soffice_paths = [
        r"C:\Program Files\LibreOffice\program\soffice.exe",
        r"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
        "soffice"
    ]
    soffice_cmd = None
    for p in soffice_paths:
        if os.path.exists(p) or p == "soffice":
            try:
                res = subprocess.run([p, "--version"], capture_output=True, text=True, timeout=5)
                if res.returncode == 0:
                    soffice_cmd = p
                    break
            except Exception:
                continue

    if not soffice_cmd:
        return False

    out_dir = str(Path(output_path).parent.resolve())
    cmd = [soffice_cmd, "--headless", "--convert-to", "pdf", "--outdir", out_dir, input_path]
    print(f"[Office -> PDF] Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        base_name = Path(input_path).stem + ".pdf"
        generated = os.path.join(out_dir, base_name)
        if generated != output_path and os.path.exists(generated):
            if os.path.exists(output_path):
                os.remove(output_path)
            os.rename(generated, output_path)
        print(f"[Office -> PDF] Successfully created: {output_path}")
        return True
    return False

def convert_docx_to_pdf(input_path: str, output_path: str) -> bool:
    """Convert DOCX to PDF using LibreOffice, docx2pdf, or Word COM."""
    if convert_office_to_pdf_libreoffice(input_path, output_path):
        return True
    try:
        from docx2pdf import convert
        print(f"[DOCX -> PDF] Converting via docx2pdf: {input_path} -> {output_path}")
        convert(input_path, output_path)
        return True
    except Exception as e:
        print(f"[DOCX -> PDF] Fallback failed: {e}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description="Nguyen Du Universal Document Converter")
    parser.add_argument("input", help="Path to input file (.pdf, .docx, .xlsx, .pptx)")
    parser.add_argument("-o", "--output", help="Path to output file")
    parser.add_argument("-t", "--to", choices=["docx", "xlsx", "pptx", "pdf"], help="Target format")
    args = parser.parse_args()

    input_file = Path(args.input)
    if not input_file.exists():
        print(f"Error: Input file does not exist: {input_file}", file=sys.stderr)
        sys.exit(1)

    in_ext = input_file.suffix.lower().lstrip(".")
    target = args.to

    if not target:
        if args.output:
            target = Path(args.output).suffix.lower().lstrip(".")
        elif in_ext == "pdf":
            target = "docx"
        else:
            target = "pdf"

    output_file = args.output or str(input_file.with_suffix(f".{target}"))

    success = False
    if in_ext == "pdf":
        if target == "docx":
            success = convert_pdf_to_docx(str(input_file), output_file)
        elif target == "xlsx":
            success = convert_pdf_to_xlsx(str(input_file), output_file)
        elif target == "pptx":
            success = convert_pdf_to_pptx(str(input_file), output_file)
        else:
            print(f"Unsupported conversion from PDF to {target}", file=sys.stderr)
    elif target == "pdf":
        if in_ext == "docx":
            success = convert_docx_to_pdf(str(input_file), output_file)
        elif in_ext in ["xlsx", "pptx"]:
            success = convert_office_to_pdf_libreoffice(str(input_file), output_file)
        else:
            print(f"Unsupported conversion from {in_ext} to PDF", file=sys.stderr)
    else:
        print(f"Unsupported conversion pair: {in_ext} -> {target}", file=sys.stderr)

    if success:
        print(f"\n[SUCCESS] Output saved to: {output_file}")
        sys.exit(0)
    else:
        print(f"\n[FAILURE] Conversion failed.", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()
