require "logger"

class SwitchFile
  TEST_DIR = {
    "controllers" => "functional",
    "helpers"     => "unit/helpers",
    "mailers"     => "functional",
    "models"      => "unit"
  }

  APP_DIR = {
    "functional"   => ["controllers", "mailers"],
    "unit"         => "models",
    "unit/helpers" => "helpers"
  }

  attr_accessor :project_dir
  attr_accessor :full_path
  attr_accessor :path

  def self.switch!
    new.detect!
  end

  def log
    @log ||= Logger.new("/tmp/tm-switch.log")
  end

  def initialize
    @project_dir = ENV["TM_PROJECT_DIRECTORY"]
    @full_path = ENV["TM_FILEPATH"]

    unless project_dir
      puts "This command requires a project"
      exit 1
    end

    @path = full_path.gsub(/^#{Regexp.escape(project_dir)}\//, "")
  end

  def rails?
    File.file?(File.join(project_dir, "config", "boot.rb"))
  end

  def detect!
    if path =~ /^test\/.*?$/
      switch_to_file!
    else
      switch_to_test!
    end
  end

  def open_file(file)
    %x{ "$TM_SUPPORT_PATH/bin/mate" "#{file}" }
  end

  def switch_to_file!
    _, app_dir, relative_path = *path.match(/^test\/(.*?)\/(.*?)$/)

    unless app_dir && relative_path
      puts "The source file for #{full_path} wasn't found"
      exit 1
    end

    relative_path.gsub!(/_test\.rb$/, ".rb")

    files = [APP_DIR[app_dir], File.dirname(relative_path)].flatten.compact.collect do |d|
      File.join(project_dir, "app", d, File.basename(relative_path))
    end

    target = files.find do |f|
      File.file?(f)
    end

    unless target
      puts "The source file #{full_path} wasn't found"
      exit 1
    end

    open_file target
  end

  def switch_to_test!
    _, app_dir, relative_path = *path.match(/^app\/(.*?)\/(.*?)$/)

    unless app_dir && relative_path
      puts "The test file for #{full_path} wasn't found"
      exit 1
    end

    relative_path.gsub!(/\.rb$/i, "_test.rb")

    test_dir = [TEST_DIR[app_dir], "unit/#{app_dir}", "unit"].compact.find do |d|
      File.directory?(File.join(project_dir, "test", d))
    end

    unless test_dir
      puts "The test file for #{full_path} wasn't found"
      exit 1
    end

    target = File.join(project_dir, "test", test_dir, relative_path)

    unless File.file?(target)
      puts "#{target} file not found"
      exit 1
    end

    open_file target
  end
end
