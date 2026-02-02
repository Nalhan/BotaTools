import os
import json
import gspread
from google.oauth2.service_account import Credentials

def escape_lua_string(s):
    """Escapes characters for a Lua string."""
    if not isinstance(s, str):
        return str(s)
    # Simple escape for double quotes and backslashes
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')

def main():
    # Load environment variables
    creds_json = os.environ.get('GCP_SERVICE_ACCOUNT_JSON')
    sheet_id = os.environ.get('SHEET_ID')

    if not creds_json:
        print("Error: GCP_SERVICE_ACCOUNT_JSON environment variable not set.")
        exit(1)
    if not sheet_id:
        print("Error: SHEET_ID environment variable not set.")
        exit(1)

    print("Authenticating with Google Sheets...")
    try:
        # Load credentials from JSON string
        creds_dict = json.loads(creds_json)
        # Define scopes
        scopes = ['https://www.googleapis.com/auth/spreadsheets.readonly']
        creds = Credentials.from_service_account_info(creds_dict, scopes=scopes)
        client = gspread.authorize(creds)
    except Exception as e:
        print(f"Authentication failed: {e}")
        exit(1)

    print(f"Opening sheet with ID: {sheet_id}")
    try:
        sh = client.open_by_key(sheet_id)
        # Assume data is in the first worksheet
        worksheet = sh.get_worksheet(0)
        # Get all records (assumes first row is header)
        records = worksheet.get_all_records()
    except Exception as e:
        print(f"Failed to fetch data from sheet: {e}")
        exit(1)

    print(f"Fetched {len(records)} rows from sheet.")

    # Generate Lua file content
    lua_lines = []
    lua_lines.append("-- Data.lua")
    lua_lines.append("local addonName, addonTable = ...")
    lua_lines.append("")
    lua_lines.append("-- Official set of eating lines")
    lua_lines.append("addonTable.OfficialLines = {")

    for row in records:
        text = row.get('text')
        # Skip empty rows or rows without text
        if not text:
            continue
            
        weight = row.get('weight')
        # Default weight to 10 if missing or invalid
        try:
            weight = int(weight)
        except (ValueError, TypeError):
            weight = 10

        escaped_text = escape_lua_string(text)
        # Format: { text = "...", weight = 10 },
        # calculate padding for alignment if desired, but simple format is functional
        line = f'    {{ text = "{escaped_text}", weight = {weight} }},'
        lua_lines.append(line)

    lua_lines.append("}")
    lua_lines.append("") # Trailing newline

    # Write to Data.lua
    # Assuming the script is run from the root of the repo or scripts dir
    # We'll try to find Data.lua in the parent dir if we are in scripts/
    output_path = 'Data.lua'
    if not os.path.exists(output_path) and os.path.exists('../Data.lua'):
        output_path = '../Data.lua'
    
    print(f"Writing to {output_path}...")
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lua_lines))
        print("Success!")
    except Exception as e:
        print(f"Failed to write file: {e}")
        exit(1)

if __name__ == '__main__':
    main()
