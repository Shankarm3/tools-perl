import re
import json
from pathlib import Path

def log_info(msg):
    print(msg, file=sys.stdout)

def main():
    try:
        with open('input.xml', 'r', encoding='utf-8') as f:
            xml = f.read()
    except IOError as e:
        log_info(f"Can't open file: {e}")
        return 1

    xml = xml.replace('\r\n', '\n')
    xml_working = xml   

    normalized_words = ['x axis', 'broad band', 'spin down']

    separators = [
        ' ',         # regular space
        '-',         # hyphen
        '&ndash;',   # ndash entity
        '&mdash;',   # mdash entity
        '--',        # double hyphen
        '&nbsp;',    # non-breaking space
        '&nbsp;&nbsp;', # double non-breaking space
        '&#x00A0;',  # hex non-breaking space
        '&#160;',    # decimal non-breaking space
        '&#xa0;',    # lower hex non-breaking space
        '&#xA0;',    # upper hex non-breaking space
        r"-\s*\n\s*",  # hyphen + line break (soft hyphenation)
        r"\s*\n\s*"  # hyphen + line break (soft hyphenation)
    ]

    results = {}

    for norm in normalized_words:
        first, second = norm.split(maxsplit=1)
        
        for sep in separators:
            form = f"{first}{sep}{second}"
            
            if r"\n" in sep:
                pattern = form
            else:
                pattern = re.escape(form)
            
            working_copy = xml_working
            count = 0
            
            for _ in re.finditer(pattern, working_copy, re.IGNORECASE):
                count += 1
                print(f"Index=============>{_.end()}")
                working_copy = working_copy[_.end():]
                log_info(working_copy)
            if count > 0:
                results[form] = count

    #print("{\n" + ",\n".join(f'    "{k}": {v}' for k, v in results.items()) + "\n}")

if __name__ == "__main__":
    import sys
    sys.exit(main())