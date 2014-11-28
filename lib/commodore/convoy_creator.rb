require 'navy'

module Commodore
  class ConvoyCreator
    attr_reader :convoy, :manifest

    def initialize(name, manifest)
      @manifest = manifest
      @convoy = name
    end

    def create!(params)
      etcd = params[:etcd]
      cluster = params[:cluster]
      env = params[:env]
      set_actual_manifest(etcd)
      config = Navy::Configuration.from_string(manifest)
      config.set_env(env)
      queue_desired_dependencies(etcd, config, cluster)
      queue_desired_applications(etcd, config, cluster)
    end

    private

    def set_actual_manifest(etcd)
      key = "/navy/convoys/#{convoy}/manifest"
      etcd.set(key, manifest)
    end

    def queue_desired_applications(etcd, config, cluster)
      config.apps do |app|
        if app.modes
          app.modes.each do |mode, cmd|
            queue_desired_app(app, etcd, config, :mode => mode, :scale => 1, :cluster => cluster)
          end
        else
          queue_desired_app(app, etcd, config, :scale => 1, :cluster => cluster)
        end
        builder = Navy::TaskContainerBuilder.new(app, config, :cluster => cluster, :convoy => convoy)
        queue_desired_task(builder.build_pre, etcd)
        queue_desired_task(builder.build_post, etcd)
      end
    end

    def queue_desired_dependencies(etcd, config, cluster)
      config.dependencies do |dep|
        queue_desired_app(dep, etcd, config, :cluster => cluster)
      end
    end

    def queue_desired_task(container, etcd)
      return unless container
      name = container.specification[:container_name]
      desired = {
        :state => :completed,
        :dependencies => container.dependencies,
        :specification => container.specification
      }
      queue_container(name, desired, etcd)
    end

    def queue_desired_app(app, etcd, config, options={})
      options = options.merge :convoy => convoy
      container = Navy::AppContainerBuilder.new(app, config, options).build
      name = container.specification[:container_name]
      desired = {
        :state => :running,
        :dependencies => container.dependencies,
        :specification => container.specification
      }
      queue_container(name, desired, etcd)
    end

    def queue_container(name, desired, etcd)
      etcd.queueJSON('/navy/queues/containers', :request => :create,
                                                :name => name,
                                                :desired => desired)
      etcd.set("/navy/convoys/#{convoy}/containers/#{name}", "")
      etcd.set("/navy/convoy_names/#{name}", convoy)
    end
  end
end
