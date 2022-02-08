# assetcache_exporter

Prometheus exporter for macOS AssetCache

## Installation

```sh
brew tap reitermarkus/tap
brew install assetcache_exporter --HEAD
```

## Service

```sh
brew services start assetcache_exporter
``` 

## Scrape Configuration

```yaml
- job_name: assetcache
  static_configs:
    - targets:
        - 10.0.0.235:9923
```
