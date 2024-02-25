require "option_parser"
require "log"
require "system/user"
require "./curses"
require "./readline"
require "./fswatch"
require "./message_box"
require "./config"

lib LibC
  LC_ALL = 6
  fun setlocale(category : LibC::Int, locale : Pointer(LibC::Char)) : Pointer(LibC::Char)
end

class FileTree
  getter path : Path
  getter children : Array(FileTree)
  getter expanded : Bool
  getter kind : Symbol
  getter parent : Nil | FileTree
  getter hidden : Bool

  def initialize(parent : FileTree, path : Path)
    initialize(path)
    @parent = parent
  end

  def initialize(path : Path)
    @path = path.expand
    @children = [] of FileTree
    @expanded = false
    @kind = File.directory?(@path) ? :directory : :file
    @parent = nil
    @hidden = @path.basename[0] == "."
  end

  def initialize(parent : FileTree, directory : Path)
    initialize(directory)
    @parent = parent
  end

  def handle_changes(changes)
    if changes.size > 0
      result = false
      changes.each do |event|
        flags = event.flags[0]
        if flags.includes?(FSWatch::Flag::Created)
          added = self.add_path(event.path)
          result = result || added
        elsif flags.includes?(FSWatch::Flag::Removed)
          removed = self.remove_path(event.path)
          result = result || removed
        end
      end
      result
    else
      false
    end
  end

  def add_path(path : Path)
    self.add_path_parts path_parts path
  end

  def add_path_parts(parts : Array(String))
    if @expanded
      if head = parts.pop?
        if child = find_child(head)
          child.add_path_parts(parts)
        else
          child = FileTree.new(@path / head)
          child.add_path_parts(parts)
          @children.push(child)
          true
        end
      end
    end
  end

  def remove_path(path : Path)
    self.remove_path_parts path_parts path
  end

  def remove_path_parts(parts : Array(String))
    if @expanded
      if head = parts.pop?
        if child = find_child(head)
          if parts.size == 0
            @children.delete(child)
            true
          else
            child.remove_path_parts(parts)
          end
        end
      end
    end
  end

  def find_child(name)
    @children.find do |child|
      child.path.basename == name
    end
  end

  def force_expand
    Dir.new(@path).each_child do |path|
      path = @path / Path.new path
      @children.push FileTree.new(self, path)
    end
  end

  def expand
    if @kind == :directory && !@expanded
      if @children.size == 0
        self.force_expand
      end

      @expanded = true
      true
    else
      false
    end
  end

  def inpand
    was = @expanded
    @expanded = false
    was
  end

  def depth_traverse(level = 0_u8, &block : UInt8, FileTree -> Symbol)
    case yield level, self
    when :continue
      level += 1
      if @expanded
        @children.each do |child|
          child.depth_traverse(level) do |level, child|
            block.call(level, child)
          end
        end
      end
    else
      return
    end
  end

  private def path_parts(path)
    path.expand.relative_to(@path).parts.reverse
  end
end

class View
  record Line, level : UInt8, tree : FileTree

  getter tree : FileTree
  getter lines : Array(Line)
  getter ymax
  getter xmax
  getter yoffset
  getter xoffset
  getter cursor

  def initialize(tree : FileTree)
    @tree = tree
    @lines = [] of Line
    @cursor = 0
    @ymax = 0
    @xmax = 0
    @yoffset = 0
    @xoffset = 0
  end

  def resize(x, y)
    @xmax = x
    @ymax = y - 1
    @cursor = Math.min(Math.min(@ymax - 1 + @yoffset, @cursor), @ymax)
  end

  def home
    if @cursor > 0 || @yoffset > 0
      @yoffset = 0
      @cursor = 0
      true
    end
  end

  def endd
    steps = 0
    @tree.depth_traverse do |level, child|
      steps += 1
      :continue
    end

    new_yoffset = Math.max(0, steps - (@ymax - 1))
    new_cursor = Math.min(steps, @ymax) - 1

    if new_cursor != @cursor || new_yoffset != @yoffset
      @cursor = new_cursor
      @yoffset = new_yoffset
      true
    end
  end

  def up(n : Int)
    if @cursor > 0
      @cursor = Math.max(0, @cursor - n)
      true
    elsif @yoffset > 0
      @yoffset = Math.max(0, @yoffset - n)
      true
    end
  end

  def right
    @lines[@cursor].tree.expand
  end

  def left
    node = @lines[@cursor].tree
    if node.kind == :directory && node.expanded
      node.inpand
      old_yoffset = @yoffset
      self.render
      if old_yoffset != @yoffset
        @cursor = @cursor - (@yoffset - old_yoffset)
      end
      true
    elsif parent = node.parent
      steps = 0
      found = false
      @tree.depth_traverse do |level, child|
        if found
          :break
        elsif child.path == parent.path
          found = true
          :break
        else
          steps += 1
          :continue
        end
      end

      if steps >= @yoffset
        new_yoffset = @yoffset
        new_cursor = steps - @yoffset
      else
        new_cursor = 0
        new_yoffset = steps
      end

      if new_cursor != @cursor || new_yoffset != @yoffset
        @cursor = new_cursor
        @yoffset = new_yoffset
        true
      end
    end
  end

  def down(n)
    if @cursor == @lines.size - 1
      if @cursor >= @ymax - 1
        @yoffset += n
        true
      end
    elsif @cursor < @lines.size - 1
      @cursor = Math.min(@cursor + n, @lines.size - 1)
      true
    end
  end

  def click(y)
    new_cursor = Math.min(y, @ymax - 1)
    if new_cursor != @cursor
      @cursor = new_cursor
      true
    end
  end

  def render
    @lines = [] of Line
    steps = @ymax + @yoffset
    @tree.depth_traverse do |level, child|
      if steps == 0
        :stop
      elsif steps > @ymax
        steps -= 1
        :continue
      else
        @lines.push(Line.new level, child)
        steps -= 1
        :continue
      end
    end

    if steps > 0 && @yoffset > 0
      @yoffset = Math.max(@yoffset - steps, 0)
      self.render
    end
  end

  def fill_trailing(line)
    if line.size < @xmax
      size = @xmax - line.size
      "#{line}#{" " * size}"
    else
      line
    end
  end

  def draw
    # Printing tree
    @lines.each_index do |i|
      line = lines[i]
      tree = line.tree
      prefix =
        case tree.kind
        when :directory
          tree.expanded ? "/ " : "//"
        when :file
          "  "
        end

      color =
        if i == @cursor
          Curses::Color::Cursor
        elsif tree.kind == :directory
          Curses::Color::Directory
        else
          Curses::Color::Regular
        end

      basename =
        if line.level == 0
          home = Path.home
          expanded = tree.path.expand(home: true)
          if relative = expanded.relative_to?(home)
            "~/#{relative}"
          else
            expanded
          end
        else
          tree.path.basename
        end

      line = fill_trailing "#{"  " * line.level}#{prefix}#{basename}"
      Curses.withattr(Curses.pair(color)) do
        Curses.printw(line[0..(@xmax - 1)])
      end
    end

    if @lines.size < @ymax
      (@lines.size..(@ymax - 1)).each do |i|
        Curses.printw fill_trailing("")[0..(@xmax - 1)]
      end
    end

    # Printing readline or status bar
    control_line = "#{Readline.display_prompt}#{Readline.line_buffer}"
    Curses.withattr(Curses.pair(Curses::Color::Command)) do
      Curses.printw fill_trailing control_line
    end
  end
end

module Tree
  extend self

  def ls(directory)
    return `ls #{directory}`[0..-2]
  end

  def ctrl(key : Char)
    (key.ord & 0x1f).chr
  end

  @@readline_result = nil

  def ask(view, prompt)
    Curses.curs_set(Curses::Cursor::Invisible)
    callback =
      ->(s : Pointer(LibC::Char)) {
        @@readline_result = s ? String.new(s) : ""
      }

    Readline.init(prompt, ->(void : Void) {}, callback)
    while true
      view.render
      Curses.erase
      view.draw
      char = LibNcurses.wgetch(LibNcurses.stdscr)
      case char
      when LibNcurses::Keys::KEY_RESIZE.value.chr
        x = Curses.xmax
        y = Curses.ymax
        view.resize(x, y)
      when LibNcurses::Keys::KEY_BACKSPACE.value.chr
        Readline.forward_char(127)
      when LibNcurses::Keys::KEY_LEFT.value.chr
        Readline.forward_char(224)
        Readline.forward_char(75)
      else
        Readline.forward_char(char)
      end

      if @@readline_result != nil
        Readline.deinit
        break
      end
    end

    result = @@readline_result
    @@readline_result = nil
    result
  end

  def ui(dir : Path)
    fswatch_mbox = MessageBox(FSWatch::Event).new
    spawn same_thread: false do
      fswatch = FSWatch.new
      fswatch.add_path(".")
      fswatch.set_recursive(true)
      fswatch.add_event_type_filter [
        FSWatch::Flag::Created,
        FSWatch::Flag::Removed,
      ]

      fswatch.set_callback do |event|
        fswatch_mbox.send(event)
      end
      fswatch.start_monitor
    end

    LibC.setlocale(LibC::LC_ALL, "".dup.to_unsafe)

    tree = FileTree.new(dir)
    view = View.new(tree)
    Curses.init

    Curses.erase
    x = Curses.xmax
    y = Curses.ymax
    view.resize(x, y)
    changed = true
    config = Config.new

    while true
      if changed
        Log.info { "Changed" }
        view.render
        Curses.erase
        view.draw
      end

      char = LibNcurses.wgetch(LibNcurses.stdscr)
      case char
      # Navigation
      when LibNcurses::Keys::KEY_HOME.value.chr
        changed = view.home
      when LibNcurses::Keys::KEY_END.value.chr
        changed = view.endd
      when LibNcurses::Keys::KEY_UP.value.chr
        changed = view.up(1)
      when LibNcurses::Keys::KEY_DOWN.value.chr
        changed = view.down(1)
      when 'h'
        changed = view.left
      when 'j'
        changed = view.down(1)
      when 'k'
        changed = view.up(1)
      when 'l'
        changed = view.right
      when LibNcurses::Keys::KEY_PPAGE.value.chr
        changed = view.up(view.lines.size)
      when LibNcurses::Keys::KEY_NPAGE.value.chr
        changed = view.down(view.lines.size)
      when LibNcurses::Keys::KEY_RIGHT.value.chr
        changed = view.right
      when LibNcurses::Keys::KEY_LEFT.value.chr
        changed = view.left
        # Special
      when LibNcurses::Keys::KEY_RESIZE.value.chr
        x = Curses.xmax
        y = Curses.ymax
        view.resize(x, y)
        changed = true
      when LibNcurses::Keys::KEY_MOUSE.value.chr
        event = Curses.getmouse
        changed =
          case event.bstate
          when Curses::MouseButton::BUTTON1_PRESSED
            view.click(event.y)
          when Curses::MouseButton::SCROLL_UP
            view.up(1)
          when Curses::MouseButton::SCROLL_DOWN
            view.down(1)
          else
            false
          end
        # Bindings
      when '\r'
        path = view.lines[view.cursor].tree.path
        config.enter path
      else
        changed = false
      end
      changed = changed || tree.handle_changes(fswatch_mbox.take)
    end
  end

  OptionParser.parse do |parser|
    Log.setup(:error)
    parser.banner = "Usage: tcr [flags] directory\n"

    parser.on "-v", "--version", "Show version" do
      puts "1.0"
      exit
    end

    parser.on "-h", "--help", "Show help" do
      puts parser
      exit
    end

    parser.on "-l FILE", "--log=FILE", "Log to" do |filename|
      file = File.new(filename, "a+")
      backend = Log::IOBackend.new(io: file, dispatcher: Log::SyncDispatcher.new)
      Log.setup(:info, backend)
      Log.info { "Logging to #{filename}" }
    end

    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end

    parser.unknown_args do |args|
      dir = args[0]? || "."
      ui Path.new dir
    end
  end
end
