# BunkerWeb Helm Chart Documentation

## Documentation Structure

```
docs/
├── README.md              # This file
└── values.md              # User guide + technical reference (generated)
```

## Generating Documentation

This chart includes tools for automatic documentation generation:

```bash
# Generate values reference from values.yaml
python3 scripts/generate-docs.py
```

## Contributing

When contributing to this chart, please:

1. Update relevant documentation
2. Run the documentation generator
3. Test examples and configurations
4. Follow the existing style and structure

## External Resources

- **[BunkerWeb Official Docs](https://docs.bunkerweb.io/)** - Complete product documentation
- **[GitHub Repository](https://github.com/bunkerity/bunkerweb)** - Source code and issues
- **[Community Forum](https://github.com/bunkerity/bunkerweb/discussions)** - Community support
- **[Helm Charts Repository](https://github.com/bunkerity/bunkerweb-helm)** - Chart source

## License

This documentation is part of the BunkerWeb Helm Chart project and follows the same licensing terms as the main project.
