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

  def execute(char, path : Path)
    binding = char_to_bind(char)
    if command = @bindings[binding]? || default(binding)
      Log.info { "Executing #{command}" }
      process = Process.new(command, shell: true, env: {"tcr_path" => path.to_s})
      spawn same_thread: false do
        while !process.terminated?
          sleep(1)
        end
        Log.info { "Command \"#{command}\" finished with #{process.wait.exit_status}" }
      end
    end
  end

  def char_to_bind(char)
    case char
    when '\r'
      "enter"
    else
      char.to_s
    end
  end

  def default(binding)
    case binding
    when "enter"
      "kcr edit $tcr_path"
    else
      nil
    end
  end
end
