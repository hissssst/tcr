require "file_utils"
require "log"
require "option_parser"
require "system/user"
require "./config"
require "./curses"
require "./fswatch"
require "./message_box"
require "./readline"

class FileTree
  getter path : Path
  getter children : Array(FileTree)
  getter expanded : Bool
  getter kind : Symbol
  getter parent : Nil | FileTree
  getter hidden : Bool

  @@filter_hidden = true

  def initialize(parent : FileTree, path : Path)
    initialize(path)
    @parent = parent
  end

  def initialize(path : Path)
    @path = path.expand.normalize
    @children = [] of FileTree
    @expanded = false
    @kind = File.directory?(@path) ? :directory : :file
    @parent = nil
    @hidden = @path.basename[0]? == "."
  end

  def initialize(parent : FileTree, directory : Path)
    initialize(directory)
    @parent = parent
  end

  def toggle_filter_hidden
    @@filter_hidden = !@@filter_hidden
  end

  def reload
    if @expanded
      self.load_children
    else
      @children.clear
    end
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

  def expand_path(path)
    if path == @path || path.parents.includes?(@path)
      self.expand
      @children.find do |child|
        child.expand_path(path)
      end
      true
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

  def reorder_children
    @children = @children.sort_by do |child_tree|
      if child_tree.kind == :directory
        {-1, child_tree.path.basename}
      else
        {1, child_tree.path.basename}
      end
    end
  end

  def load_children
    children = Dir.new(@path).children
    children =
      if @@filter_hidden
        children.reject { |path| path[0]? == '.' }
      else
        children
      end
    children = children.map do |path|
      path = @path / Path.new path
      FileTree.new(self, path)
    end
    @children = children
    self.reorder_children
  end

  def expand
    if @kind == :directory && !@expanded
      if @children.size == 0
        self.load_children
      end

      @expanded = true
      true
    else
      false
    end
  end

  def expand_recursive
    changed = self.expand
    self.children.each do |child|
      child_changed = child.expand_recursive
      changed = changed || child_changed
    end
    changed
  end

  def inpand
    was = @expanded
    @expanded = false
    was
  end

  def rename(new_name)
    new_path = Path.new(@path.dirname) / Path.new(new_name)
    FileUtils.mv(@path, new_path)
    @path = new_path
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
  getter ymax : Int32
  getter xmax : Int32
  getter yoffset
  getter xoffset
  getter cursor

  def initialize(tree : FileTree)
    Curses.init
    Curses.erase
    x = Curses.xmax
    y = Curses.ymax

    @tree = tree
    @lines = [] of Line
    @cursor = 0
    @yoffset = 0
    @xoffset = 0
    @xmax = x
    @ymax = y - 1
    @mode = :normal
  end

  def resize(x, y)
    @xmax = x
    @ymax = y - 1
    if @cursor > @ymax - 1
      @yoffset += @cursor - (@ymax - 1)
      @cursor = @ymax - 1
    end
  end

  def ask(mode, prompt)
    @mode = mode
    Curses.curs_set(Curses::Cursor::Visible)
    result =
      Readline.ask(prompt, ->{
        Log.info { "Drawing" }
        self.render
        Curses.erase
        self.draw
        char = LibNcurses.wgetch(LibNcurses.stdscr)
        case char
        when LibNcurses::Keys::KEY_RESIZE.value.chr
          x = Curses.xmax
          y = Curses.ymax
          self.resize(x, y)
        when LibNcurses::Keys::KEY_BACKSPACE.value.chr
          Readline.forward_char(127)
        when LibNcurses::Keys::KEY_LEFT.value.chr
          Readline.forward_char(224)
          Readline.forward_char(75)
        when LibNcurses::Keys::KEY_DOWN.value.chr
          Readline.forward_char(224)
          Readline.forward_char(80)
        when LibNcurses::Keys::KEY_UP.value.chr
          Readline.forward_char(224)
          Readline.forward_char(72)
        when LibNcurses::Keys::KEY_RIGHT.value.chr
          Readline.forward_char(224)
          Readline.forward_char(77)
        when 27.chr
          Log.info { "Escape!" }
          Readline.forward_char(0)
        else
          if char.ord != -1
            Readline.forward_char(char)
          end
        end
      })

    Curses.curs_set(Curses::Cursor::Invisible)
    @mode = :normal
    result
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
        :break
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

  def select_path(path)
    found_at = -1
    steps = 0
    @tree.depth_traverse do |level, child|
      if found_at == -1 && child.path == path
        found_at = steps
      end
      steps += 1
      :continue
    end

    if found_at >= @ymax
      @yoffset = Math.min(found_at, steps - @ymax)
      @cursor = Math.max(0, found_at - @yoffset)
    else
      @cursor = Math.max(0, found_at)
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

  def add_path
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
        if i == @cursor && @mode == :rename
          Readline.line_buffer.as(String)
        elsif line.level == 0
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
    case @mode
    when :rename
      control_line = "#{@mode}///#{Readline.display_prompt}"
      Curses.withattr(Curses.pair(Curses::Color::Command)) do
        Curses.printw fill_trailing control_line
      end
    else
      Curses.withattr(Curses.pair(Curses::Color::Command)) do
        Curses.printw fill_trailing "#{@mode}"
      end
    end
  end
end

module Tree
  extend self

  def start(dir, log_to, path_to_select)
    tree = FileTree.new Path.new dir
    view = View.new(tree)
    if path_to_select
      Log.info { "Started with #{dir} selected #{path_to_select}" }
      path_to_select = path_to_select.expand.normalize
      tree.expand_path(path_to_select)
      view.select_path(path_to_select)
    end

    fswatch_mbox = start_fswatch()
    config = Config.new

    loop(config, tree, view, fswatch_mbox)
  end

  private def start_fswatch
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

    return fswatch_mbox
  end

  private def loop(config, tree, view, fswatch_mbox)
    changed = true
    while true
      if changed
        Log.info { "Changed" }
        view.render
        Curses.erase
        view.draw
        Curses.set_title("tcr")
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
      when 'q'
        Curses.stop
        exit(0)
      when 'o'
        changed = view.lines[view.cursor].tree.expand_recursive
      when 'r'
        new_name = view.ask(:rename, "Rename #{view.lines[view.cursor].tree.path.basename}> ")
        changed = view.lines[view.cursor].tree.rename(new_name)
      when 'i'
        tree.toggle_filter_hidden
        tree.reload
        changed = true
      when 'a'
        view.add_path
        changed = true
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
      else
        if char.ord != -1
          Log.info { "Char #{char}" }
          path = view.lines[view.cursor].tree.path
          config.execute(char, path)
        end
        changed = false
      end
      tree_changed = tree.handle_changes(fswatch_mbox.take)
      changed = changed || tree_changed
    end
  end

  OptionParser.parse do |parser|
    Log.setup(:error)
    parser.banner = "Usage: tcr [flags] directory\n"

    path_to_select = nil
    log_to = nil

    parser.on "-s FILE", "--select=FILE", "Open and select this path" do |path|
      path_to_select = Path.new path
    end

    parser.on "-l FILE", "--log=FILE", "Log to" do |filename|
      log_to = Path.new filename
      file = File.new(filename, "a+")
      backend = Log::IOBackend.new(io: file, dispatcher: Log::SyncDispatcher.new)
      Log.setup(:info, backend)
      Log.info { "Logging to #{filename}" }
    end

    parser.on "-v", "--version", "Show version" do
      puts "1.0"
      exit
    end

    parser.on "-h", "--help", "Show help" do
      puts parser
      exit
    end

    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end

    parser.unknown_args do |args|
      dir = args[0]? || "."
      start(dir: dir, log_to: log_to, path_to_select: path_to_select)
    end
  end
end
