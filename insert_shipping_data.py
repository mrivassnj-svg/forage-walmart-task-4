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
    
    # Read Spreadsheet 0 (Self-contained)
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

    # Read Spreadsheet 2 (Logistics Routing Context)
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

    # Read Spreadsheet 1 (Line Items) and aggregate matching products inside the same shipment
    print("Reading and aggregating Spreadsheet 1 (Line Items)...")
    shipment_products = defaultdict(lambda: defaultdict(int))
    with open(csv1, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ship_id = row.get('shipment_identifier')
            p_name = row.get('product')
            
            # Spreadsheet 1 doesn't have an explicit quantity column per item row; 
            # each occurrence of a product within a shipment counts as 1 unit.
            if ship_id and p_name:
                p_cleaned = p_name.strip()
                unique_products.add(p_cleaned)
                shipment_products[ship_id][p_cleaned] += 1

    # =========================================================================
    # PART 2: POPULATE THE PRODUCT LOOKUP TABLE (Dimension Table)
    # =========================================================================
    print("\nPopulating the 'product' table...")
    product_inserts = [(name,) for name in sorted(unique_products)]
    cursor.executemany("INSERT OR IGNORE INTO product (name) VALUES (?);", product_inserts)
    conn.commit()

    # Create key map for dynamic ID retrieval
    cursor.execute("SELECT id, name FROM product;")
    product_name_to_id = {name: id_ for id_, name in cursor.fetchall()}
    print(f"✔ Cached {len(product_name_to_id)} distinct products from database metadata tracking.")

    # =========================================================================
    # PART 3: PREPARE AND INSERT FINAL SHIPMENT VALUES (Fact Table)
    # =========================================================================
    print("\nPreparing final normalized database transaction rows...")
    final_shipment_inserts = []

    # Map Spreadsheet 0 items
    for item in spreadsheet_0_rows:
        prod_id = product_name_to_id.get(item['product_name'])
        if prod_id is not None and item['origin'] and item['destination']:
            final_shipment_inserts.append((
                prod_id,
                item['quantity'],
                item['origin'],
                item['destination']
            ))

    # Map combined Spreadsheet 1 + 2 items
    for ship_id, products in shipment_products.items():
        route = routes.get(ship_id, {'origin': None, 'destination': None})
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

    print(f"Executing insertion into 'shipment' table ({len(final_shipment_inserts)} total valid rows)...")
    cursor.executemany("""
        INSERT INTO shipment (product_id, quantity, origin, destination) 
        VALUES (?, ?, ?, ?);
    """, final_shipment_inserts)

    conn.commit()
    conn.close()
    print("\n=========================================================")
    print("✔ DATABASE INTEGRITY COMPLIANT: DATA POPULATION COMPLETE.")
    print("=========================================================")

if __name__ == "__main__":
    populate_walmart_shipping_db()