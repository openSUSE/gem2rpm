require 'erb'
require 'socket'
require 'gem2rpm/package'
require 'gem2rpm/distro'
require 'gem2rpm/format'
require 'gem2rpm/spec_fetcher'
require 'gem2rpm/specification'

module Gem2Rpm
  Gem2Rpm::VERSION = "0.10.1"

  class Exception < RuntimeError; end
  class DownloadUrlError < Exception; end

  def self.find_download_url(name, version)
    dep = Gem::Dependency.new(name, "=#{version}")
    fetcher = Gem2Rpm::SpecFetcher.new(Gem::SpecFetcher.fetcher)

    spec_and_source, errors = fetcher.spec_for_dependency(dep, false)

    raise DownloadUrlError.new(errors.first.error.message) unless errors.empty?

    spec, source = spec_and_source.first

    if source && source.uri
      download_path = source.uri.to_s
      download_path += "gems/"
    end

    download_path
  end

  def Gem2Rpm.convert(fname, template=TEMPLATE, out=$stdout,
                      nongem=true, local=false, doc_subpackage = true, oldlicense=nil, config={})
    package = Gem2Rpm::Package.new(fname)
    # Deprecate, kept just for backward compatibility.
    format = Gem2Rpm::Format.new(package)
    spec = Gem2Rpm::Specification.new(package.spec)
    if spec.licenses.empty? && oldlicense
      spec.licenses = oldlicense.split(' and ')
    end
    config ||= {}
    download_path = ""
    unless local
      begin
        download_path = find_download_url(spec.name, spec.version)
      rescue DownloadUrlError => e
        $stderr.puts "Warning: Could not retrieve full URL for #{spec.name}\nWarning: Edit the specfile and enter the full download URL as 'Source0' manually"
        $stderr.puts e.inspect
      end
    end
    erb_instance = if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6')
      ERB.new(str=template, trim_mode='-')
    else
      ERB.new(str=template, safe_mode=0, trim_mode='-')
    end
    out.puts erb_instance.result(binding)
  rescue Gem::Exception => e
    puts e
  end

  # Returns the email address of the packager (i.e., the person running
  # gem2spec).  Taken from RPM macros if present, constructed from system
  # username and hostname otherwise.
  def Gem2Rpm.packager()
    packager = `rpmdev-packager`.chomp rescue ''

    if packager.empty?
      packager = `rpm --eval '%{packager}'`.chomp rescue ''
    end

    if packager.empty? or packager == '%{packager}'
      passwd_entry = Etc::getpwnam(Etc::getlogin)
      packager = "#{(passwd_entry && passwd_entry.gecos) || Etc::getlogin } <#{Etc::getlogin}@#{Socket::gethostname}>"
    end

    packager
  end

  def Gem2Rpm.template_dir
    File.join(File.dirname(__FILE__), '..', 'templates')
  end

  TEMPLATE = File.read File.join(template_dir, "#{Distro.nature.to_s}.spec.erb")
end

# Local Variables:
# ruby-indent-level: 2
# End:
