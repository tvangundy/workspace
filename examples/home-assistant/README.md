# Home Assistant Example

A complete home automation setup that includes container-based deployment, SSL/TLS configuration, persistent storage management, add-on integration, and monitoring.

## Requirements

Before you begin, ensure you have:

- Valid domain name (for SSL)
- Open port 8123
- Basic understanding of Home Assistant concepts
- For Zigbee integration:
  - USB Zigbee adapter
  - Appropriate permissions for USB access

# Quick Start

```
windsor init local
windsor up --install
kubectl port-forward --address 0.0.0.0 svc/home-assistant -n home-assistant 8123:8123

Visit: http://localhost:8123

windsor down 
```

## Documentation

For detailed documentation, visit the [Home Assistant Example Guide](../docs/examples/home-assistant.md).

## Getting Help

- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)

## Configuration

The example uses the following configuration:

```yaml
# windsor.yaml
version: '1.0'
services:
  home-assistant:
    image: home-assistant/home-assistant:latest
    ports:
      - "8123:8123"
    volumes:
      - ./config:/config
    environment:
      - TZ=UTC
```

## Notes

- Initial setup may take several minutes
- First-time access requires creating an account
- SSL certificates are automatically managed
- Add-ons can be installed through the Home Assistant UI 
