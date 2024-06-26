#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'open3'
require 'json'

require 'prometheus_exporter'
require 'prometheus_exporter/server'
require 'prometheus_exporter/client'
require 'prometheus_exporter/instrumentation'

server = PrometheusExporter::Server::WebServer.new(bind: '0.0.0.0', port: ENV.fetch('PORT', 9923))
server.start

PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(collector: server.collector)

PrometheusExporter::Instrumentation::Process.start(type: 'assetcache_exporter')

metrics = {
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_bytes_limit', 'cache size limit',
  ) => lambda { |result|
    [[result.fetch('CacheLimit'), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_bytes_free', 'free cache size',
  ) => lambda { |result|
    [[result.fetch('CacheFree'), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_bytes_used_sum', 'total used cache size',
  ) => lambda { |result|
    [[result.fetch('CacheUsed'), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_ok', 'service status is OK',
  ) => lambda { |result|
    [[result.fetch('CacheStatus') == 'OK' ? 1 : 0, {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_active', 'service is active',
  ) => lambda { |result|
    [[result.fetch('Active') ? 1 : 0, {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_bytes_used', 'used cache size',
  ) => lambda { |result|
    cache_details = result.fetch('CacheDetails')

    [
      [cache_details.fetch('iCloud', 0), { cache_group: 'icloud' }],
      [cache_details.fetch('iOS Software', 0), { cache_group: 'ios' }],
      [cache_details.fetch('Mac Software', 0), { cache_group: 'macos' }],
      [cache_details.fetch('Apple TV Software', 0), { cache_group: 'tvos' }],
      [cache_details.fetch('Books', 0), { cache_group: 'books' }],
      [cache_details.fetch('Other', 0), { cache_group: 'other' }],
    ]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_bytes_used_actual', 'actual cache size',
  ) => lambda { |result|
    [[result.fetch('ActualCacheUsed', 0), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_personal_bytes_free', 'free personal cache size',
  ) => lambda { |result|
    [[result.fetch('PersonalCacheFree'), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_personal_bytes_limit', 'personal cache size limit',
  ) => lambda { |result|
    [[result.fetch('PersonalCacheLimit'), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_personal_bytes_used', 'used personal cache size',
  ) => lambda { |result|
    [[result.fetch('PersonalCacheUsed'), {}]]
  },
  PrometheusExporter::Metric::Gauge.new(
    'assetcache_start_time_seconds',
    'Unix time of when the service was started',
  ) => lambda { |result|
    [[DateTime.parse(result.fetch('TotalBytesAreSince')).to_time.to_i, {}]]
  },
  PrometheusExporter::Metric::Counter.new(
    'assetcache_bytes_dropped',
    'number of bytes dropped from cache since the service was started',
  ) => lambda { |result|
    [[result.fetch('TotalBytesDropped'), {}]]
  },
  PrometheusExporter::Metric::Counter.new(
    'assetcache_bytes_imported',
    'number of bytes imported into the cache since the service was started',
  ) => lambda { |result|
    [[result.fetch('TotalBytesImported'), {}]]
  },
  PrometheusExporter::Metric::Counter.new(
    'assetcache_bytes_served',
    'total bytes served since the service was started',
  ) => lambda { |result|
    [
      [result.fetch('TotalBytesReturnedToClients'), { to: 'clients' }],
      [result.fetch('TotalBytesReturnedToPeers'), { to: 'peers' }],
      [result.fetch('TotalBytesReturnedToChildren'), { to: 'children' }],
    ]
  },
  PrometheusExporter::Metric::Counter.new(
    'assetcache_bytes_stored',
    'total bytes stored since the service was started',
  ) => lambda { |result|
    [
      [result.fetch('TotalBytesStoredFromOrigin'), { from: 'origin' }],
      [result.fetch('TotalBytesStoredFromParents'), { from: 'parents' }],
      [result.fetch('TotalBytesStoredFromPeers'), { from: 'peers' }],
    ]
  },
}

metrics.each_key do |metric|
  server.collector.register_metric(metric)
end

def asset_cache_status
  out, err, status = Open3.capture3('AssetCacheManagerUtil', 'status', '--json')

  unless status.success?
    warn err
    return
  end

  JSON.parse(out)
end

loop do
  status = asset_cache_status

  next sleep 5 if status.nil?

  result = status.fetch('result')

  server_guid = result.fetch('ServerGUID')

  metrics.each do |metric, resolver|
    resolver.call(result).each do |args, options|
      metric.observe(*args, **options, server_guid: server_guid)
    end
  end

  sleep 5
end
