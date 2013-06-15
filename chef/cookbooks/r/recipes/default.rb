#
# Cookbook Name:: r
# Recipe:: default
#
# Copyright 2012, Michael Linderman
#

include_recipe "build-essential"

case node['platform']
when "ubuntu"
	include_recipe "apt"

	# Key obtained from CRAN Ubuntu README
	execute "gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && gpg -a --export E084DAB9 | sudo apt-key add -" do
		not_if "apt-key list | grep 'E084DAB9'"
		notifies :run, resources(:execute => "apt-get update"), :immediately
	end

	# apt_repository "CRAN" do
	# 	uri "http://#{node[:R][:CRAN][:default]}/bin/linux/ubuntu"
	# 	distribution "#{node[:lsb][:codename]}/"
	# 	action :add
	# end

	%w{ r-base r-base-dev }.each do |p|
		package p do
			action :install
		end
	end

when "debian"
	include_recipe "apt"

	# Key obtained from CRAN Ubuntu README
	execute "gpg --keyserver keyserver.ubuntu.com --recv-key 381BA480 && gpg -a --export 381BA480 | sudo apt-key add -" do
		not_if "apt-key list | grep '381BA480'"
		notifies :run, resources(:execute => "apt-get update"), :immediately
	end

	apt_repository "CRAN" do
		uri "http://#{node[:R][:CRAN][:default]}/bin/linux/debian"
		distribution "#{node[:lsb][:codename]}-cran/"
		action :add
	end

	# Need to use specific repository to get backported R...
	execute "install R" do
		command "apt-get -t #{node[:lsb][:codename]}-cran install --yes --force-yes r-base r-base-dev"
	end

	execute "install GMT package" do
		command "sudo /usr/bin/R -e \"install.packages('gmt')\""
	end

when "centos","redhat","fedora"
	remote_file "/tmp/R-latest.tar.gz" do
		source "http://#{node[:R][:CRAN][:default]}/src/base/R-latest.tar.gz"
		backup false
	end

	# Also installs X, X-devel and fortran compiler (mandatory packages from
	# 'X Window System' and 'X Software Development')

	%w{ gcc-gfortran tcl tk tcl-devel tk-devel }.each do |p|
		package p do
			action :install
		end
	end

	bash "install_R_from_source" do
		user "root"
		code <<-EOH
		set -e
		yum -y groupinstall 'X Window System'
		yum -y groupinstall 'X Software Development'
		cd /tmp
		tar -xzf R-latest.tar.gz
		BASE=`tar tzf R-latest.tar.gz | sed -e 's@/.*@@' | uniq`
		cd $BASE
		./configure
		make && make install
		rm -rf /tmp/$BASE /tmp/R-latest.tar.gz
		EOH
		not_if do
			File.exists? "/usr/local/bin/R"
		end
	end
end

# Setup a default CRAN repository
# It would be better to make this a template, but we don't know the
# target directory until convergence time and so have to use this approach
bash "Set_R_site_profile" do
	user "root"
	code <<-EOH
	cat <<-EOF > $(R RHOME)/etc/Rprofile.site
	## Rprofile.site generated by Chef for #{node[:fqdn]}
	local({
		r <- getOption("repos")
		r["CRAN"] <- "http://#{node[:R][:CRAN][:default]}";
		options(repos = r)
	})
	EOF
	EOH
end

node[:R][:packages].each do |p|

	include_recipe "r::#{p}" rescue ArgumentError

	r_package p do
		action :install
  end
end