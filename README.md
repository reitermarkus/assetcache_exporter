# assetcache-exporter

Prometheus exporter for macOS AssetCache

## Installation

```sh
brew tap reitermarkus/tap
brew install assetcache-exporter
```

## Service

```sh
brew services start assetcache-exporter
``` 

## Scrape Configuration

```yaml
- job_name: assetcache
  static_configs:
    - targets:
        - 10.0.0.235:9923
```
