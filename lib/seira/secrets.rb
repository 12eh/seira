require 'json'
require 'base64'

# Example usages:
# seira staging specs secret set RAILS_ENV staging
# seira demo tracking secret unset DISABLE_SOME_FEATURE
# seira staging importer secret list
# TODO: Multiple secrets in one command
# TODO: Can we avoid writing to disk completely and instead pipe in raw json?
module Seira
  class Secrets
    VALID_ACTIONS = %w[get set unset list list-decoded create-pgbouncer-secret].freeze
    PGBOUNCER_SECRETS_NAME = 'pgbouncer-secrets'.freeze

    attr_reader :app, :action, :key, :value, :args, :context

    def initialize(app:, action:, args:, context:)
      @app = app
      @action = action
      @args = args
      @key = args[0]
      @value = args[1]
      @context = context
    end

    def run
      case action
      when 'get'
        perform_key_validation
        run_get
      when 'set'
        perform_key_validation
        run_set
      when 'unset'
        perform_key_validation
        run_unset
      when 'list'
        run_list
      when 'list-decoded'
        run_list_decoded
      when 'create-pgbouncer-secret'
        run_create_pgbouncer_secret
      when 'bootstrap-cluster'
        run_bootstrap_cluster
      else
        fail "Unknown command encountered"
      end
    end

    def copy_secret_across_namespace(key:, to:, from:)
      puts "Copying the #{key} secret from namespace #{from} to #{to}."
      json_string = `kubectl get secret #{key} --namespace #{from} -o json`
      secrets = JSON.parse(json_string)

      # At this point we would preferably simply do a write_secrets call, but the metadata is highly coupled to old
      # namespace so we need to clear out the old metadata
      new_secrets = Marshal.load(Marshal.dump(secrets))
      new_secrets.delete('metadata')
      new_secrets['metadata'] = {
        'name' => key,
        'namespace' => to
      }
      write_secrets(secrets: new_secrets, secret_name: key)
    end

    def main_secret_name
      "#{app}-secrets"
    end

    private

    def perform_key_validation
      if key.nil? || key.strip == ""
        puts "Please specify a key in all caps and with underscores"
        exit(1)
      end
    end

    def run_get
      secrets = fetch_current_secrets
      puts "#{key}: #{Base64.decode64(secrets['data'][key])}"
    end

    def run_set
      fail "Please specify a value as the third argument" if value.nil? || value.strip == ""
      secrets = fetch_current_secrets
      secrets['data'][key] = Base64.encode64(value)
      write_secrets(secrets: secrets)
    end

    def run_unset
      secrets = fetch_current_secrets
      secrets['data'].delete(key)
      write_secrets(secrets: secrets)
    end

    def run_list
      secrets = fetch_current_secrets
      puts "Base64 encoded keys for #{app}:"
      secrets['data'].each do |k, v|
        puts "#{k}: #{v}"
      end
    end

    def run_list_decoded
      secrets = fetch_current_secrets
      puts "Decoded (raw) keys for #{app}:"
      secrets['data'].each do |k, v|
        puts "#{k}: #{Base64.decode64(v)}"
      end
    end

    def run_create_pgbouncer_secret
      db_user = args[0]
      db_password = args[1]
      puts `kubectl create secret generic #{PGBOUNCER_SECRETS_NAME} --namespace #{app} --from-literal=DB_USER=#{db_user} --from-literal=DB_PASSWORD=#{db_password}`
    end

    # In the normal case the secret we are updating is just main_secret_name,
    # but in special cases we may be doing an operation on a different secret
    def write_secrets(secrets:, secret_name: main_secret_name)
      file_name = "tmp/temp-secrets-#{Seira::Cluster.current_cluster}-#{secret_name}.json"
      File.open(file_name, "wb") do |f|
        f.write(secrets.to_json)
      end

      # The command we use depends on if it already exists or not
      secret_exists = system("kubectl get secret #{secret_name} --namespace #{app} > /dev/null")
      command = secret_exists ? "replace" : "create"

      if system("kubectl #{command} --namespace #{app} -f #{file_name}")
        puts "Successfully created/replaced #{secret_name} secret #{key} in cluster #{Seira::Cluster.current_cluster}"
      else
        puts "Failed to update secret"
      end

      File.delete(file_name)
    end

    # Returns the still-base64encoded secrets hashmap
    def fetch_current_secrets
      json_string = `kubectl get secret #{main_secret_name} --namespace #{app} -o json`
      json = JSON.parse(json_string)
      fail "Unexpected Kind" unless json['kind'] == 'Secret'
      json
    end
  end
end
