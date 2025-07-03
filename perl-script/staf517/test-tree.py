from collections import defaultdict
from defusedxml.ElementTree import fromstring
import json

# Define the nested defaultdict structure
result = {
    "tags": defaultdict(lambda: {
        "attributes": defaultdict(lambda: defaultdict(int)),
        "parents": set()
    })
}

# Sample XML content
xml = """
<root>
    <section class="highlight" id="intro">
        <p class="text">Welcome</p>
        <p class="text">More text</p>
    </section>
    <section class="highlight">
        <div class="box">Content</div>
    </section>
</root>
"""

root = fromstring(xml)

def walk(node, parent_tag=None):
    tag_info = result["tags"][node.tag]

    if parent_tag:
        tag_info["parents"].add(parent_tag)

    for attr_name, attr_value in node.attrib.items():
        tag_info["attributes"][attr_name][attr_value] += 1

    for child in node:
        walk(child, node.tag)
    return result

walk(root)


def clean(obj):
    if isinstance(obj, defaultdict):
        return {k: clean(v) for k, v in obj.items()}
    elif isinstance(obj, dict):
        return {k: clean(v) for k, v in obj.items()}
    elif isinstance(obj, set):
        return list(obj)
    elif isinstance(obj, list):
        return [clean(i) for i in obj]
    else:
        return obj


print(json.dumps(clean(result), indent=2))
