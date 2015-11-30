metadata    :name        => "SimpleRPC Agent For Multi-Package Management",
            :description => "Agent to manage multiple packages",
            :author      => "Jens Braeuer <braeuer.jens@gmail.com>",
            :license     => "ASL2",
            :version     => "1.3",
            :url         => "https://github.com/jbraeuer/mcollective-plugins",
            :timeout     => 660

["uptodate"].each do |act|
    action act, :description => "#{act.capitalize} a package" do
      input :packages,
            :prompt => "Package names",
            :description => "Packages to #{act.capitalize}",
            :type => :Array,
            :validation => '.',
            :optional => false,
            :maxlength => 90

        output :status,
               :description => "Status Code",
               :display_as  => "Status"

        output :packages,
               :description => "Properties of the package after #{act.sub(/e$/, '')}ing",
               :display_as  => "Properties"
    end
end

