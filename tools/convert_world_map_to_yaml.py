#!/usr/bin/env python3
"""Convert godot/data/world_map.json to godot/data/world_map.yaml."""

import json
import os


def _yaml_value(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) or isinstance(value, float):
        return str(value)
    return '"%s"' % str(value).replace('\\', '\\\\').replace('"', '\\"')


def _emit_yaml(obj, indent=0):
    lines = []
    prefix = "  " * indent
    if isinstance(obj, dict):
        for key, value in obj.items():
            # Skip empty collections to keep YAML clean; loaders use defaults for missing keys
            if isinstance(value, (dict, list)) and not value:
                continue
            if isinstance(value, (dict, list)):
                lines.append("%s%s:" % (prefix, key))
                lines.extend(_emit_yaml(value, indent + 1))
            else:
                lines.append("%s%s: %s" % (prefix, key, _yaml_value(value)))
    elif isinstance(obj, list):
        for item in obj:
            if isinstance(item, dict):
                # First key on same line as '-'
                keys = list(item.keys())
                if keys:
                    first_key = keys[0]
                    first_value = item[first_key]
                    # Skip empty collections; loaders use defaults for missing keys
                    if isinstance(first_value, (dict, list)) and not first_value:
                        lines.append("%s- %s:" % (prefix, first_key))
                    elif isinstance(first_value, (dict, list)):
                        lines.append("%s- %s:" % (prefix, first_key))
                        lines.extend(_emit_yaml(first_value, indent + 2))
                    else:
                        lines.append("%s- %s: %s" % (prefix, first_key, _yaml_value(first_value)))
                    for key in keys[1:]:
                        value = item[key]
                        # Skip empty collections; loaders use defaults for missing keys
                        if isinstance(value, (dict, list)) and not value:
                            continue
                        if isinstance(value, (dict, list)):
                            lines.append("%s  %s:" % (prefix, key))
                            lines.extend(_emit_yaml(value, indent + 2))
                        else:
                            lines.append("%s  %s: %s" % (prefix, key, _yaml_value(value)))
                else:
                    lines.append("%s-" % prefix)
            elif isinstance(item, list):
                lines.append("%s-" % prefix)
                lines.extend(_emit_yaml(item, indent + 2))
            else:
                lines.append("%s- %s" % (prefix, _yaml_value(item)))
    return lines


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    json_path = os.path.join(repo_root, "godot", "data", "world_map.json")
    yaml_path = os.path.join(repo_root, "godot", "data", "world_map.yaml")

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    lines = ["# World Map Data", "# Cities/forts/villages, positions, factions, and connection overrides"]
    lines.extend(_emit_yaml(data))

    with open(yaml_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
        f.write("\n")

    print("Converted %s to %s" % (json_path, yaml_path))


if __name__ == "__main__":
    main()
