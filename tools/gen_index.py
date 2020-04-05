import sys
from pathlib import Path
import json

if __name__ == "__main__":
    try:
        root_dir = sys.argv[1]
    except:
        sys.exit(-1)

    result = {}
    for p in Path(root_dir).glob('*/*/*.json'):
        date, lang, f = str(p).split('/')[-3:]
        result.setdefault(date, {}).setdefault(lang, []).append(f)
    print(json.dumps(result, indent=4))
