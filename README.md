# Seira

An opinionated library for building applications on Kubernetes. 

This library builds a framework for doing deployments, secrets management, managing memcached, managing redis, managing and accessing pods, bootstraping new apps and clusters, and more. It makes decisions about how to run the apps and cluster to make managing the cluster easier.

The vision for Seira is to produce a CLI and set of guidelines that makes deploying apps on Kubernetes as easy as Heroku.

## What does the name mean?

Following Kubernetes naming pattern, Seira (Seirá) is greek for "order" or "the state of being well arranged".

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'seira'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install seira

The `gem install seira` option may be preferred for shorter typing, or generating a binstub is also an option.

## Usage

This library only currently works with `gcloud` and `kubectl`, meaning Google Container Engine and Kubernetes.

All commands follow a pattern:

`seira <cluster> <app> <category> <param1> <param2> <..>`

The only exception is commands on the cluster itself, which does not take an `<app>`. By making sure to take in a cluster as the first parameter to every command, the intent is to reduce mistake commands on the wrong cluster.

### Configuration File

A configuration file is expected at `.seira.yml` relative path. Below is an example file.

```
seira:
  organization_id: "11111"
  default_zone: "us-central1-a"
  clusters:
    internal:
      project: org-internal
      cluster: gke_org-internal_us-central1-a_internal
      aliases:
        - "i"
    staging:
      project: org-staging
      cluster: gke_org-staging_us-central1-a_staging
      aliases:
        - "s"
    demo:
      project: org-demo
      cluster: gke_org-demo_us-central1-a_demo
      aliases:
        - "d"
    production:
      project: org-production
      cluster: gke_org-production_us-central1-a_production
      aliases:
        - "p"
  valid_apps:
    - app1
    - app2
```

This specification is read in and used to determine what `gcloud` context to use and what `kubectl` cluster to use when operating commands. For example, `seira internal` will connect to `org-internal` gcloud configuration and `gke_org-internal_us-central1-a_internal` kubectl cluster. For shorthand, `seira i` shorthand is specified as an alias.

### Manifest Files

Seira expects your Kubernetes manifests to exist in the "kubernetes/<cluster>/<app>" directory. When a deploy is run on `foo` app in `staging` cluster, it looks to `kubernetes/staging/foo` directory for the manifest files.

### Initial Setup

In order to use Seira, an initial setup is needed. Use the `seira setup` command to set up each of your clusters in your configuration file.

## Example functionality

### Running Proxy UI

Easily run a proxy UI (`kubectl proxy`) by using `seira staging proxy` shorthand.

### Applying New Manifest Files

By using `seira staging app-name app apply`, Seira will find/replace the string "REVISION" in your manifests with the value in the `REVISION` environment variable and apply the new configs to the cluster. If `REVISION` is nil, it will ask to use the tag currently being used by the current `web` deployment.

### Setting Secrets

All secrets are stored in `appname-secrets` Secret object. They are expected to be used via `envFrom` in manifest files.

`seira staging app-name secrets list`
`seira staging app-name secrets set KEY value`
`seira staging app-name secrets get KEY`

### Pods

Pods can be listed and also exec'd into.

`seira staging app-name pods list`
`seira staging app-name pods run`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joinhandshake/seira.

## Roadmap

Future roadmap has plans for:

- Create CLI help commands and improve general CLI usability
- Cloud SQL Postgres Management (credentials, processes, diagnostics, psql, etc)
- Smooth application restarts, including such as after changing secrets
- Better redis and memcached production-level management
- More functionality for managing pods
- Maintenance page mode
- Quickly scaling up/down deployments
- SSL Certificate inspection and observability through kube-lego
- More seamless `seira setup` script


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

