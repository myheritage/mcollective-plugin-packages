class MCollective::Application::Packages<MCollective::Application
  description "Generic Package Manager"
    usage <<-END_OF_USAGE
mco packages [OPTIONS] <ACTION> <PACKAGE> <PACKAGE> ..."

The ACTION can be one of the following:

    uptodate  - install/downgrade/update PACKAGE

PACKAGES can be in the form NAME[/VERSION[/REVISION]]

    examples would be:
        - "yum"
        - "yum/3.2.29/1.el6"

    END_OF_USAGE

  option :batch,
    :description => "Batch-mode. Don't ask for confirmation",
    :arguments => ["--batch"],
    :type => :bool

  def post_option_parser(configuration)
    if ARGV.length < 2
      raise "Please specify action and one or more packages"
    end

    configuration[:action] = ARGV.shift
    unless configuration[:action] =~ /^(uptodate)$/
      raise "Action has to be uptodate"
    end

    configuration[:packages] = ARGV.map do |elem|
      items = elem.split("/")
      raise "Package must be given as <name>/[<version>[/<release>]]" unless (1..3) === items.length
      Hash[["name", "version", "release"].zip(items)]
    end
  end

  def validate_configuration(configuration)
    if MCollective::Util.empty_filter?(options[:filter]) and not configuration[:batch]
      print("Do you really want to operate on packages unfiltered? (y/n): ")
      STDOUT.flush

      exit unless STDIN.gets.chomp =~ /^y$/
    end
  end

  def valid_resp_data?(data)
    unless data.is_a? Hash and data.include?(:packages) and data[:packages].is_a? Array
      return false
    end
    data[:packages].each do |p|
      return false unless p.keys.sort == ["name", "version", "release", "status", "tries"].sort
    end
    return true
  end

  def _main
    require 'json'

    pkg = rpcclient("packages", :options => options)
    rcs = [ 0 ]

    active_nodes = []
    output = []
    discovered_nodes = pkg.discover :verbose => true
    resps = pkg.send(configuration[:action], {:packages => configuration[:packages]})
    resps.each do |resp|
      if resp[:statuscode] != 0
        output << sprintf("%-40s = STATUSCODE %s\n", resp[:sender], resp[:statuscode])
        rcs << 2
      else
        unless valid_resp_data? resp[:data]
          output << sprintf("%-40s = INVALID %s\n", resp[:sender], resp[:data].to_json)
          rcs << 2
        else
          if resp[:data][:status] != 0
            output << sprintf("%-40s = ERR %s ::: %s :::\n", resp[:sender], resp[:data][:status], resp[:data][:packages].to_json)
            rcs << 1
          else
            output << sprintf("%-40s = OK ::: %s :::\n", resp[:sender], resp[:data][:packages].to_json)
          end
        end
      end
      active_nodes << resp[:sender]
    end
    discovered_nodes.each do |node|
      if !active_nodes.include? node
        output << sprintf("%-40s = TIMEOUT REACHED\n", node )
        resps << { :sender => node, :statuscode => 2, :statusmsg => 'TIMEOUT', :data => {}, :action => configuration[:action],:agent => 'packages'}
        rcs << 2
      end
    end
    if options[:output_format] == :json
      printrpc resps
    else
      puts output
    end
    return rcs.max
  end

  def main
    rc = _main

    # As of MCollective 1.2.x setting the overall exit-code is not possible for a agent. So be brutal...
    if rc != 0
      MCollective::PluginManager["connector_plugin"].disconnect rescue true
      Kernel.exit! rc
    end
  end
end
# vi:tabstop=2:expandtab:ai
