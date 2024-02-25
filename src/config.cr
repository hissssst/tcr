require "ini"
require "log"

class Config
  getter bindings
  getter config

  def initialize(path = default_path)
    if File.exists?(path)
      fconfig = INI.parse File.read path
      @bindings = fconfig["bindings"]? || Hash(String, String).new
      @config = fconfig["config"]? || Hash(String, String).new
    else
      @bindings = Hash(String, String).new
      @config = Hash(String, String).new
    end
  end

  def default_path
    path = Path.new(ENV["XDG_CONFIG_HOME"]? || "~/.config") / "tcr.ini"
    path.expand(home: true)
  end

  def enter(path : Path)
    command = @bindings["enter"]? || "kcr edit $"
    Log.info { "Command: #{command}" }
    cmd = command.sub("$", path)
    Log.info { "CMD #{cmd}" }
    process = Process.new("sh", ["-c", cmd])
    process.wait.success?
  end
end
