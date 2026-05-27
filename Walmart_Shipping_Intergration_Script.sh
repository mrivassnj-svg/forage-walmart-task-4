# Save Walmart Integration Script as a PDF

Use the following Python script to generate a professional PDF document containing your Walmart shipment database integration code.

## Requirements

Install ReportLab first:

```bash
pip install reportlab
```

---

# Full Python PDF Generator Script

```python
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Preformatted, Spacer, Paragraph
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors
from reportlab.platypus.tables import Table, TableStyle
from reportlab.lib.units import inch

code_text = r'''
import csv
import sqlite3
import os
from collections import defaultdict

def populate_walmart_shipping_db():
    db_path = "shipment_database.db"
    csv0 = os.path.join("data", "shipping_data_0.csv")
    csv1 = os.path.join("data", "shipping_data_1.csv")
    csv2 = os.path.join("data", "shipping_data_2.csv")

    print(f"Connecting to database: {db_path}...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    unique_products = set()

    # =========================================================================
    # PART 1: PARSE ALL DATA SOURCES AND EXTRACT UNIQUE PRODUCTS
    # =========================================================================

    spreadsheet_0_rows = []
    print("Reading Spreadsheet 0...")
    with open(csv0, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            p_name = row.get('product')
            origin_val = row.get('origin_warehouse')
            dest_val = row.get('destination_store')
            qty_val = row.get('product_quantity')

            if p_name:
                unique_products.add(p_name.strip())

            spreadsheet_0_rows.append({
                'origin': origin_val.strip() if origin_val else None,
                'destination': dest_val.strip() if dest_val else None,
                'product_name': p_name.strip() if p_name else None,
                'quantity': int(qty_val) if qty_val else 0
            })

    print("Reading Spreadsheet 2 (Logistics Routes)...")
    routes = {}

    with open(csv2, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ship_id = row.get('shipment_identifier')
            origin_val = row.get('origin_warehouse')
            dest_val = row.get('destination_store')

            if ship_id:
                routes[ship_id] = {
                    'origin': origin_val.strip() if origin_val else None,
                    'destination': dest_val.strip() if dest_val else None
                }

    print("Reading and aggregating Spreadsheet 1 (Line Items)...")
    shipment_products = defaultdict(lambda: defaultdict(int))

    with open(csv1, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ship_id = row.get('shipment_identifier')
            p_name = row.get('product')

            if ship_id and p_name:
                p_cleaned = p_name.strip()
                unique_products.add(p_cleaned)
                shipment_products[ship_id][p_cleaned] += 1

    # =========================================================================
    # PART 2: POPULATE PRODUCT LOOKUP TABLE
    # =========================================================================

    print("\nPopulating the 'product' table...")

    product_inserts = [(name,) for name in sorted(unique_products)]

    cursor.executemany(
        "INSERT OR IGNORE INTO product (name) VALUES (?);",
        product_inserts
    )

    conn.commit()

    cursor.execute("SELECT id, name FROM product;")

    product_name_to_id = {
        name: id_ for id_, name in cursor.fetchall()
    }

    print(f"✔ Cached {len(product_name_to_id)} distinct products.")

    # =========================================================================
    # PART 3: PREPARE SHIPMENT FACT TABLE INSERTIONS
    # =========================================================================

    print("\nPreparing final normalized shipment rows...")

    final_shipment_inserts = []

    for item in spreadsheet_0_rows:
        prod_id = product_name_to_id.get(item['product_name'])

        if prod_id is not None and item['origin'] and item['destination']:
            final_shipment_inserts.append((
                prod_id,
                item['quantity'],
                item['origin'],
                item['destination']
            ))

    for ship_id, products in shipment_products.items():
        route = routes.get(ship_id, {
            'origin': None,
            'destination': None
        })

        if route['origin'] and route['destination']:
            for product_name, total_qty in products.items():
                prod_id = product_name_to_id.get(product_name)

                if prod_id is not None:
                    final_shipment_inserts.append((
                        prod_id,
                        total_qty,
                        route['origin'],
                        route['destination']
                    ))

    print(f"Executing insertion into shipment table ({len(final_shipment_inserts)} rows)...")

    cursor.executemany("""
        INSERT INTO shipment (
            product_id,
            quantity,
            origin,
            destination
        )
        VALUES (?, ?, ?, ?);
    """, final_shipment_inserts)

    conn.commit()
    conn.close()

    print("\n=========================================================")
    print("✔ DATABASE INTEGRITY COMPLIANT: DATA POPULATION COMPLETE.")
    print("=========================================================")

if __name__ == "__main__":
    populate_walmart_shipping_db()
'''

# =========================================================
# PDF DOCUMENT SETUP
# =========================================================

pdf_file = "Walmart_Shipping_Integration_Script.pdf"

doc = SimpleDocTemplate(
    pdf_file,
    pagesize=letter,
    rightMargin=0.75 * inch,
    leftMargin=0.75 * inch,
    topMargin=0.75 * inch,
    bottomMargin=0.75 * inch
)

styles = getSampleStyleSheet()

story = []

# =========================================================
# TITLE
# =========================================================

story.append(Paragraph(
    "<b>Walmart Shipping Database Integration Script</b>",
    styles['Title']
))

story.append(Spacer(1, 0.25 * inch))

story.append(Paragraph(
    "This document contains the normalized shipment database population script used "
    "to process Walmart logistics CSV datasets and populate the SQLite shipment database.",
    styles['BodyText']
))

story.append(Spacer(1, 0.3 * inch))

# =========================================================
# CODE BLOCK
# =========================================================

code_style = styles['Code']
code_style.fontName = 'Courier'
code_style.fontSize = 8
code_style.leading = 10

formatted_code = Preformatted(code_text, code_style)

code_table = Table([[formatted_code]], colWidths=[7.0 * inch])

code_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F4F6F8')),
    ('BOX', (0, 0), (-1, -1), 1, colors.grey),
    ('LEFTPADDING', (0, 0), (-1, -1), 12),
    ('RIGHTPADDING', (0, 0), (-1, -1), 12),
    ('TOPPADDING', (0, 0), (-1, -1), 10),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
]))

story.append(code_table)

# =========================================================
# BUILD PDF
# =========================================================

doc.build(story)

print(f"PDF generated successfully: {pdf_file}")
```

---

# How to Run

Save the script as:

```text
generate_pdf.py
```

Then run:

```bash
python generate_pdf.py
```

The generated file will be:

```text
Walmart_Shipping_Integration_Script.pdf
```
