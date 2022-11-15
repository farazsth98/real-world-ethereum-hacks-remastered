import sys
import requests
from pathlib import Path
import os
import json

def print_usage():
    print(f'''Etherscan Verified Contract Downloader
Usage: 
* python3 {sys.argv[0]} <contract_address>
* python3 {sys.argv[0]} -f <filename.txt>

filename.txt must contain contract addresses, one on each line.
''')

# Read the ETHERSCAN_API_KEY from .env
def get_api_key():
    with open('.env', 'r') as f:
        env_contents = f.read()
    
    variables = env_contents.split('\n')
    
    for v in variables:
        [name, value] = v.split('=')
        if name == 'ETHERSCAN_API_KEY':
            return value

ENDPOINT = "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={}&apikey={}"
API_KEY = get_api_key()

def download_contract(address):
    Path("downloaded_contracts").mkdir(parents=True, exist_ok=True)
    data = requests.get(ENDPOINT.format(address, API_KEY)).json()
    if data["status"] != '1':
        print(f"[ERROR] Failed to fetch contract for address {address}")
    else:
        # Get the source code of each file
        sources = json.loads(data["result"][0]['SourceCode'][1:-1])['sources']

        # First, make a directory for this contract by using the first filename
        # we encounter, skipping the .sol extension
        # TODO: Handle directory name collisions here
        directory_name = list(sources.keys())[0].split('/')[-1][:-4]
        Path(f'downloaded_contracts/{directory_name}').mkdir(parents=True, exist_ok=True)

        for key in sources.keys():
            filename = key.split('/')[-1]
            content = sources[key]['content']

            with open(f"downloaded_contracts/{directory_name}/{filename}", 'w') as f:
                f.write(content)

        #source = source.replace('\\\\n', '\\n')
        #print(sources)
        print(f"[SUCCESS] Fetched contract from address {address}")

def main():
    args = sys.argv
    using_file = False
    api_key = ""
    address_count = 0
    addresses = None

    # If the user specifies -f, we have three arguments. Else we have two
    if '-f' in args and len(args) != 3:
        print_usage()
        exit(0)
    elif '-f' not in args and len(args) != 2:
        print_usage()
        exit(0)
    
    using_file = '-f' in args

    # Get the address or addresses of the contracts
    if not using_file:
        addresses = [args[1]]
    else:
        with open(args[2], 'r') as f:
            addresses = f.read().split('\n')  
    
    # The addresses array might have an empty string at the end
    if addresses[-1] == '':
        addresses = addresses[:-1]
    
    for address in addresses:
        download_contract(address)

if __name__ == '__main__':
    main()