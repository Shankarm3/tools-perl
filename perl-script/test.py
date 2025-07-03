import os
import json
import re
from collections import defaultdict
from typing import Dict, Any

def parse_xml_with_regex(content: str) -> Dict[str, Any]:
    result = defaultdict(lambda: {
        "attributes": defaultdict(lambda: defaultdict(int)),
        "parents": set()
    })
    
    tag_stack = []
    sno_values = set()
    
    tag_pattern = re.compile(r'<([^>]+)>')
    attr_pattern = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
    
    for match in tag_pattern.finditer(content):
        tag_content = match.group(1)
        if tag_content.startswith(('!', '?')):
            continue
            
        for attr_match in attr_pattern.finditer(tag_content):
            attr_name, attr_value = attr_match.groups()
            if attr_name == 'sno' and attr_value.isdigit():
                sno_values.add(int(attr_value))
    
    sequential_snos = set()
    if sno_values:
        sorted_snos = sorted(sno_values)
        start = sorted_snos[0]
        prev = start
        
        for num in sorted_snos[1:]:
            if num == prev + 1:
                sequential_snos.add(prev)
                sequential_snos.add(num)
            prev = num
    
    for match in tag_pattern.finditer(content):
        tag_content = match.group(1)
        if tag_content.startswith('!'):
            continue
            
        if tag_content.startswith('/'):
            if tag_stack:
                tag_stack.pop()
            continue
            
        tag_name = tag_content.split()[0].strip()
        if tag_name.startswith('?'):
            continue
            
        attrs = {}
        for attr_match in attr_pattern.finditer(tag_content):
            attr_name, attr_value = attr_match.groups()
            attrs[attr_name] = attr_value
            
        if tag_stack:
            parent_tag = tag_stack[-1]
            result[tag_name]["parents"].add(parent_tag)
            
        if not tag_content.endswith('/') and not tag_name.startswith('?'):
            tag_stack.append(tag_name)
            
        for attr_name, attr_value in attrs.items():
            if 'id' not in attr_name.lower():
                if attr_name == 'sno' and attr_value.isdigit() and int(attr_value) in sequential_snos:
                    continue
                result[tag_name]["attributes"][attr_name][attr_value] += 1
                
    return result

def process_xml_file(file_path: str) -> Dict[str, Any]:
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        return parse_xml_with_regex(content)
    except Exception as e:
        print(f"Error processing file: {e}")
        return {}

def main():
    xml_files = [f for f in os.listdir('.') if f.lower().endswith('.xml')]
    
    if not xml_files:
        print("No XML files found in the current directory.")
        return
    
    file_path = xml_files[0]
    print(f"Processing file: {file_path}")
    
    result = process_xml_file(file_path)
    
    def convert_sets(obj):
        if isinstance(obj, dict):
            return {k: convert_sets(v) for k, v in obj.items()}
        elif isinstance(obj, set):
            return list(obj)
        elif isinstance(obj, defaultdict):
            return {k: convert_sets(v) for k, v in obj.items()}
        return obj
    
    print(json.dumps(convert_sets(result), indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()