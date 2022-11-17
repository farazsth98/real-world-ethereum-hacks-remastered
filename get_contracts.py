import sys
import requests
from pathlib import Path
import json
import argparse

def print_usage():
    print(f'''Verified Contract Downloader
Usage: 
* python3 {sys.argv[0]} -e [etherscan|snowtrace] <contract_address>
* python3 {sys.argv[0]} -e [etherscan|snowtrace] -f <filename.txt>

filename.txt must contain contract addresses, one on each line.
''')

# Read the ETHERSCAN_API_KEY from .env
def get_api_key(endpoint):
    # Get the API key name
    if endpoint == ETHERSCAN_ENDPOINT:
        api_key_name = 'ETHERSCAN_API_KEY'
    else:
        api_key_name = 'AVALANCHE_API_KEY'
    
    with open('.env', 'r') as f:
        env_contents = f.read()
    
    variables = env_contents.split('\n')
    
    for v in variables:
        [name, value] = v.split('=')
        if name == api_key_name:
            return value

ETHERSCAN_ENDPOINT = "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={}&apikey={}"
AVALANCHE_ENDPOINT = "https://api.snowtrace.io/api?module=contract&action=getsourcecode&address={}&apikey={}"

def download_contract(endpoint, api_key, address):
    Path("downloaded_contracts").mkdir(parents=True, exist_ok=True)
    data = requests.get(endpoint.format(address, api_key)).json()
    if data["status"] != '1':
        print(f"[ERROR] Failed to fetch contract for address {address}")
    else:
        # There might be one source file, or multiple. In the case of one file,
        # this json.loads() will fail
        try:
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
        except:
            source = data["result"][0]['SourceCode']
            
            # Ask the user what filename they want I guess
            filename = input("What do you want to name this contract? (add .sol extension): ")
            
            directory_name = filename[:-4]
            Path(f'downloaded_contracts/{directory_name}').mkdir(parents=True, exist_ok=True)

            with open(f"downloaded_contracts/{directory_name}/{filename}", 'w') as f:
                f.write(source)

        #source = source.replace('\\\\n', '\\n')
        #print(sources)
        print(f"[SUCCESS] Fetched contract from address {address}")

def main():
    api_key = None
    addresses = None
    
    # Setup argument parser
    parser = argparse.ArgumentParser(description='Verified Contract Downloader')
    parser.add_argument('-a', '--address', type=str, help='Address of verified contract')
    parser.add_argument('-e', '--endpoint', type=str, choices=['etherscan', 'snowtrace'], help='\'etherscan\' or \'snowtrace\'')
    parser.add_argument('-f', '--filename', type=str, help='file with list of contract addresses')

    args = parser.parse_args()

    # Endpoint is required
    if args.endpoint is None:
        print("[ERROR] An endpoint is required")
        parser.print_help()
        exit(1)

    # Either an address or a file with addresses is required
    if args.address is None and args.filename is None:
        print("[ERROR] Need a filename with addresses, or an address by itself")
        parser.print_help()
        exit(1)

    # If a file and an address are both provided, use file
    if args.filename is not None:
        with open(args[2], 'r') as f:
            addresses = f.read().split('\n') 
    else:
        addresses = [args.address]
    
    # The addresses array might have an empty string at the end
    if addresses[-1] == '':
        addresses = addresses[:-1]
    
    # Get the correct endpoint
    if args.endpoint == 'etherscan':
        endpoint = ETHERSCAN_ENDPOINT
    else:
        endpoint = AVALANCHE_ENDPOINT
    
    api_key = get_api_key(endpoint)

    for address in addresses:
        download_contract(endpoint, api_key, address)

if __name__ == '__main__':
    main()