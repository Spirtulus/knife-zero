require 'chef/knife'
require 'chef/knife/zero_base'
require 'knife-zero/bootstrap_ssh'
require 'knife-zero/helper'

class Chef
  class Knife
    class ZeroConverge < Chef::Knife::BootstrapSsh
      include Chef::Knife::ZeroBase
      deps do
        require 'chef/run_list/run_list_item'
        Chef::Knife::BootstrapSsh.load_deps
        require "knife-zero/helper"
      end

      banner "knife zero converge QUERY (options)"

      self.options = Ssh.options.merge(self.options)
      self.options[:use_sudo_password] = Bootstrap.options[:use_sudo_password]


      option :use_sudo,
        :long => "--[no-]sudo",
        :description => "Execute the chef-client via sudo (true by default)",
        :boolean => true,
        :default => true,
        :proc => lambda { |v| Chef::Config[:knife][:use_sudo] = v }


      option :override_runlist,
        :short        => "-o RunlistItem,RunlistItem...",
        :long         => "--override-runlist RunlistItem,RunlistItem...",
        :description  => "Replace current run list with specified items for a single run. It skips save node.json on local",
        :default => nil,
        :proc => lambda { |o| o.to_s }

      ## For support policy_document_databag(old style)
      option :named_run_list,
        :short        => "-n NAMED_RUN_LIST",
        :long         => "--named-run-list NAMED_RUN_LIST",
        :description  => "Use a policyfile's named run list instead of the default run list"

      option :client_version,
        :long         => "--client-version [latest|VERSION]",
        :description  => "Up or downgrade omnibus chef-client before converge.",
        :default => nil,
        :proc => lambda { |o|
          if ::Knife::Zero::Helper.chef_version_available?(o)
            o.to_s
          else
            ui.error "Client version #{o} is not found."
            exit 1
          end
        }

      def initialize(argv=[])
        super
        self.configure_chef

        ## Command hook before_converge (Before launched Chef-Zero)
        if Chef::Config[:knife][:before_converge]
          ::Knife::Zero::Helper.hook_shell_out!("before_converge", ui, Chef::Config[:knife][:before_converge])
        end

        validate_options!

        @name_args = [@name_args[0], start_chef_client]
      end

      def start_chef_client
        client_path = @config[:use_sudo] || Chef::Config[:knife][:use_sudo] ? 'sudo ' : ''
        client_path = @config[:chef_client_path] ? "#{client_path}#{@config[:chef_client_path]}" : "#{client_path}chef-client"
        s = String.new("#{client_path}")
        s << ' -l debug' if @config[:verbosity] and @config[:verbosity] >= 2
        s << " -S http://127.0.0.1:#{::Knife::Zero::Helper.zero_remote_port}"
        s << " -o #{@config[:override_runlist]}" if @config[:override_runlist]
        s << " -W" if @config[:why_run]
        Chef::Log.info "Remote command: " + s
        s
      end

      ## For support policy_document_databag(old style)
      def validate_options!
        if override_and_named_given?
          ui.error("--override_runlist and --named_run_list are exclusive")
          exit 1
        end
        true
      end
      # True if policy_name and run_list are both given
      def override_and_named_given?
        override_runlist_given? && named_run_list_given?
      end

      def override_runlist_given?
        !config[:run_list].nil? && !config[:run_list].empty?
      end

      def named_run_list_given?
        !config[:run_list].nil? && !config[:run_list].empty?
      end

    end
  end
end
