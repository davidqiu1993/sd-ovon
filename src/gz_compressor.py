import os, argparse
import gzip
import json


parser = argparse.ArgumentParser()
parser.add_argument('-i', '--input-json', type=str, required=True)
parser.add_argument('-o', '--output-json-gz', type=str, required=True)
args = parser.parse_args()

with open(args.input_json, 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data)

with gzip.open(args.output_json_gz, 'wt', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=4)
