#!/usr/bin/env python3
"""
BunkerWeb Helm Chart Values Documentation Generator (Enhanced)

This script generates comprehensive markdown documentation from the values.yaml file
with support for nested structures and deep parameter analysis.

Features:
- Recursive parsing of nested YAML structures
- Comment extraction for all levels
- Support for scheduler.features and other deep structures
- Enhanced formatting with proper indentation

Usage:
    python3 scripts/generate-docs.py
"""

import yaml
import re
import os
from typing import Dict, Any, List, Tuple

def get_yaml_type(value: Any) -> str:
    """Get the YAML type of a value."""
    if isinstance(value, bool):
        return "bool"
    elif isinstance(value, int):
        return "int"
    elif isinstance(value, str):
        return "string"
    elif isinstance(value, list):
        return "list"
    elif isinstance(value, dict):
        return "object"
    else:
        return "mixed"

def get_default_value(value: Any) -> str:
    """Get a string representation of the default value."""
    if isinstance(value, str):
        if value == "":
            return '`""`'
        else:
            return f'`"{value}"`'
    elif isinstance(value, bool):
        return f"`{str(value).lower()}`"
    elif isinstance(value, (int, float)):
        return f"`{value}`"
    elif isinstance(value, list):
        if not value:
            return "`[]`"
        else:
            return f"`{value}`"
    elif isinstance(value, dict):
        if not value:
            return "`{}`"
        else:
            return "See nested values"
    else:
        return f"`{str(value)}`"

def find_key_line(lines: List[str], key: str, parent_path: str = "") -> int:
    """Find the line number where a specific key is defined."""
    # Calculate expected indentation level
    indent_level = len(parent_path.split('.')) if parent_path else 0
    expected_indent = '  ' * indent_level
    
    search_pattern = f"{expected_indent}{key}:"
    
    for i, line in enumerate(lines):
        if line.rstrip() == search_pattern or line.rstrip().startswith(search_pattern + " "):
            return i
    return -1

def extract_comments_for_key(lines: List[str], key_line: int) -> Tuple[str, List[str]]:
    """Extract comments associated with a specific key."""
    if key_line < 0:
        return "", []
    
    description_lines = []
    examples = []
    
    # Look backwards for comments
    j = key_line - 1
    while j >= 0:
        line = lines[j].strip()
        if line.startswith('#'):
            comment_text = line[1:].strip()
            # Skip separator lines
            if '=======' in comment_text or '-----' in comment_text:
                break
            if comment_text.lower().startswith('example'):
                examples.insert(0, comment_text)
            elif comment_text:  # Non-empty comment
                description_lines.insert(0, comment_text)
        elif line == '':
            # Empty line - continue looking
            j -= 1
            continue
        else:
            # Non-comment, non-empty line - stop looking
            break
        j -= 1
    
    description = ' '.join(description_lines) if description_lines else ""
    return description, examples

def parse_values_recursive(data: Any, lines: List[str], prefix: str = "", level: int = 0) -> Dict[str, Any]:
    """Recursively parse YAML structure and extract parameters with comments."""
    parameters = {}
    
    if isinstance(data, dict):
        for key, value in data.items():
            current_path = f"{prefix}.{key}" if prefix else key
            
            # Find the line number for this key
            key_line = find_key_line(lines, key, prefix)
            
            # Extract comments for this key
            description, examples = extract_comments_for_key(lines, key_line)
            
            # Store parameter info
            parameters[current_path] = {
                'description': description or f"Configuration for {key}",
                'examples': examples,
                'type': get_yaml_type(value),
                'default': get_default_value(value),
                'path': current_path,
                'level': level,
                'key': key
            }
            
            # Recursively parse nested structures (but not too deep to avoid noise)
            if isinstance(value, dict) and value and level < 3:
                nested = parse_values_recursive(value, lines, current_path, level + 1)
                parameters.update(nested)
    
    return parameters

def parse_values_yaml_enhanced(file_path: str) -> Dict[str, Any]:
    """
    Enhanced parser for values.yaml file with recursive structure support.
    
    Args:
        file_path: Path to the values.yaml file
    
    Returns:
        Dictionary containing parameter information
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Load the YAML structure
    with open(file_path, 'r', encoding='utf-8') as f:
        try:
            yaml_data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            print(f"Error parsing YAML: {e}")
            return {}
    
    # Start recursive parsing
    parameters = parse_values_recursive(yaml_data, lines)
    return parameters

def generate_enhanced_reference(parameters: Dict[str, Any], output_path: str):
    """Generate enhanced values reference documentation."""
    
    # Define global parameters that should be grouped together
    global_params = ['fullnameOverride', 'nameOverride', 'namespaceOverride', 'imagePullSecrets', 'nodeSelector', 'tolerations', 'topologySpreadConstraints']
    
    # Group parameters by top-level section
    sections = {}
    global_section_params = []
    
    for path, param in parameters.items():
        top_level = path.split('.')[0]
        
        # Group global parameters under "Global Settings"
        if top_level in global_params:
            global_section_params.append((path, param))
        else:
            if top_level not in sections:
                sections[top_level] = []
            sections[top_level].append((path, param))
    
    # Add the global section if we have global parameters
    if global_section_params:
        sections['Global Settings'] = global_section_params
    
    content = """# BunkerWeb Helm Chart - Enhanced Values Reference

Comprehensive reference for all configuration values available in the BunkerWeb Helm chart, including nested structures.

> ⚠️ **Auto-generated**: This file is automatically generated from `values.yaml`. Do not edit manually.
> 🔧 **Enhanced**: This version includes deep analysis of nested structures like `scheduler.features`.

## Table of Contents

"""
    
    # Define custom section ordering - Global Settings first, then BunkerWeb components
    bunkerweb_sections = ['bunkerweb', 'ui', 'scheduler', 'controller']
    infrastructure_sections = ['mariadb', 'redis', 'grafana', 'prometheus']
    
    # Filter out sections that don't exist and create the ordered list
    ordered_sections = []
    
    # Add Global Settings first if it exists
    if 'Global Settings' in sections:
        ordered_sections.append('Global Settings')
    
    # Add BunkerWeb sections in preferred order
    for section in bunkerweb_sections:
        if section in sections:
            ordered_sections.append(section)
    
    # Add infrastructure sections
    for section in infrastructure_sections:
        if section in sections:
            ordered_sections.append(section)
    
    # Add remaining sections alphabetically (excluding Global Settings and already added ones)
    remaining_sections = [s for s in sections.keys() if s not in ordered_sections]
    ordered_sections.extend(sorted(remaining_sections))
    
    # Generate table of contents
    for section in ordered_sections:
        section_params = sections[section]
        main_param = next(((path, p) for path, p in section_params if '.' not in path), None)
        description = main_param[1]['description'] if main_param else f"Configuration for {section}"
        content += f"- [{section}](#{section.lower().replace('_', '-')}) - {description}\n"
    
    content += "\n---\n\n"
    
    # Generate detailed sections
    for section in ordered_sections:
        section_params = sections[section]
        
        content += f"## {section}\n\n"
        
        # Add main description
        main_param = next(((path, p) for path, p in section_params if '.' not in path), None)
        if main_param:
            content += f"{main_param[1]['description']}\n\n"
        
        # Create table
        content += "| Parameter | Description | Type | Default |\n"
        content += "|-----------|-------------|------|---------|\n"
        
        # Sort parameters by path for logical ordering
        sorted_params = sorted(section_params, key=lambda x: (x[1]['level'], x[0]))
        
        for path, param in sorted_params:
            # Format parameter name with dotted notation
            display_name = path
            
            description = param['description'][:100] + "..." if len(param['description']) > 100 else param['description']
            content += f"| `{display_name}` | {description} | `{param['type']}` | {param['default']} |\n"
        
        content += "\n"
        content += "---\n\n"
    
    # Write the file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    """Main function to generate enhanced documentation."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    chart_dir = os.path.join(script_dir, '..', 'charts', 'bunkerweb')
    values_file = os.path.join(chart_dir, 'values.yaml')
    docs_dir = os.path.join(script_dir, '..', 'docs')
    
    if not os.path.exists(values_file):
        print(f"❌ Error: values.yaml not found at {values_file}")
        return 1
    
    print(f"Parsing {values_file}...")
    
    # Parse the values.yaml file
    parameters = parse_values_yaml_enhanced(values_file)
    
    print(f"Found {len(parameters)} parameters (including nested)")
    
    # Ensure docs directory exists
    os.makedirs(docs_dir, exist_ok=True)
    
    # Generate enhanced reference
    reference_file = os.path.join(docs_dir, 'values.md')
    generate_enhanced_reference(parameters, reference_file)
    
    print(f"✅ Enhanced reference documentation: {reference_file}")
    
    # Show some statistics
    levels = {}
    for param in parameters.values():
        level = param['level']
        levels[level] = levels.get(level, 0) + 1
    
    print("📊 Parameter distribution by depth:")
    for level in sorted(levels.keys()):
        indent = "  " * level
        print(f"{indent}Level {level}: {levels[level]} parameters")
    
    print("🎉 Enhanced documentation generation complete!")
    return 0

if __name__ == "__main__":
    exit(main())
