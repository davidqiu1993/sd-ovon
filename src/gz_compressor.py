import gzip
import json

input_file_path = '/home/jacobi/workspace/sdovmm-ws/sd-ovon/data/export/data/datasets/objectnav/sd-ovon/val/val.json'
with open(input_file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data)

output_file_path = '/home/jacobi/workspace/sdovmm-ws/sd-ovon/data/export/data/datasets/objectnav/sd-ovon/val/val.json.gz'
with gzip.open(output_file_path, 'wt', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=4)
