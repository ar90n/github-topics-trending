import sys
from pathlib import Path
import json

if __name__ == "__main__":
    try:
        root_dir = sys.argv[1]
    except:
        sys.exit(-1)

    result = {}
    for p in Path(root_dir).glob('*/*/*/*/*.json'):
        year, month, day, lang, f = str(p).split('/')[-5:]
        key = f'{year}-{month}-{day}'
        result.setdefault(key, {}).setdefault(lang, []).append(f)
    print(json.dumps(result, indent=4))
