@[Extern]
record MouseEvent, id : Int8, x : LibC::Int, y : LibC::Int, z : LibC::Int, bstate : UInt32

lib LibC
  LC_ALL = 6
  fun setlocale(category : LibC::Int, locale : Pointer(LibC::Char)) : Pointer(LibC::Char)
end

@[Link("ncursesw")]
lib LibNcurses
  alias Screen = Pointer(Void)
  alias ColorPair = LibC::Int

  $stdscr : Screen

  enum Keys : LibC::Int
    KEY_DOWN      = 0o402 # down-arrow key
    KEY_UP        = 0o403 # up-arrow key
    KEY_LEFT      = 0o404 # left-arrow key
    KEY_RIGHT     = 0o405 # right-arrow key
    KEY_HOME      = 0o406 # home key
    KEY_BACKSPACE = 0o407 # backspace key
    KEY_F0        = 0o410 # Function keys
    KEY_F1        = 0o411 #
    KEY_F2        = 0o412 #
    KEY_F3        = 0o413 #
    KEY_F4        = 0o414 #
    KEY_F5        = 0o415 #
    KEY_F6        = 0o416 #
    KEY_F7        = 0o417 #
    KEY_F8        = 0o420 #
    KEY_F9        = 0o421 #
    KEY_F10       = 0o422 #
    KEY_F11       = 0o423 #
    KEY_F12       = 0o424 #
    KEY_DL        = 0o510 # delete-line key
    KEY_IL        = 0o511 # insert-line key
    KEY_DC        = 0o512 # delete-character key
    KEY_IC        = 0o513 # insert-character key
    KEY_EIC       = 0o514 # sent by rmir or smir in insert mode
    KEY_CLEAR     = 0o515 # clear-screen or erase key
    KEY_EOS       = 0o516 # clear-to-end-of-screen key
    KEY_EOL       = 0o517 # clear-to-end-of-line key
    KEY_SF        = 0o520 # scroll-forward key
    KEY_SR        = 0o521 # scroll-backward key
    KEY_NPAGE     = 0o522 # next-page key
    KEY_PPAGE     = 0o523 # previous-page key
    KEY_STAB      = 0o524 # set-tab key
    KEY_CTAB      = 0o525 # clear-tab key
    KEY_CATAB     = 0o526 # clear-all-tabs key
    KEY_ENTER     = 0o527 # enter/send key
    KEY_PRINT     = 0o532 # print key
    KEY_LL        = 0o533 # lower-left key (home down)
    KEY_A1        = 0o534 # upper left of keypad
    KEY_A3        = 0o535 # upper right of keypad
    KEY_B2        = 0o536 # center of keypad
    KEY_C1        = 0o537 # lower left of keypad
    KEY_C3        = 0o540 # lower right of keypad
    KEY_BTAB      = 0o541 # back-tab key
    KEY_BEG       = 0o542 # begin key
    KEY_CANCEL    = 0o543 # cancel key
    KEY_CLOSE     = 0o544 # close key
    KEY_COMMAND   = 0o545 # command key
    KEY_COPY      = 0o546 # copy key
    KEY_CREATE    = 0o547 # create key
    KEY_END       = 0o550 # end key
    KEY_EXIT      = 0o551 # exit key
    KEY_FIND      = 0o552 # find key
    KEY_HELP      = 0o553 # help key
    KEY_MARK      = 0o554 # mark key
    KEY_MESSAGE   = 0o555 # message key
    KEY_MOVE      = 0o556 # move key
    KEY_NEXT      = 0o557 # next key
    KEY_OPEN      = 0o560 # open key
    KEY_OPTIONS   = 0o561 # options key
    KEY_PREVIOUS  = 0o562 # previous key
    KEY_REDO      = 0o563 # redo key
    KEY_REFERENCE = 0o564 # reference key
    KEY_REFRESH   = 0o565 # refresh key
    KEY_REPLACE   = 0o566 # replace key
    KEY_RESTART   = 0o567 # restart key
    KEY_RESUME    = 0o570 # resume key
    KEY_SAVE      = 0o571 # save key
    KEY_SBEG      = 0o572 # shifted begin key
    KEY_SCANCEL   = 0o573 # shifted cancel key
    KEY_SCOMMAND  = 0o574 # shifted command key
    KEY_SCOPY     = 0o575 # shifted copy key
    KEY_SCREATE   = 0o576 # shifted create key
    KEY_SDC       = 0o577 # shifted delete-character key
    KEY_SDL       = 0o600 # shifted delete-line key
    KEY_SELECT    = 0o601 # select key
    KEY_SEND      = 0o602 # shifted end key
    KEY_SEOL      = 0o603 # shifted clear-to-end-of-line key
    KEY_SEXIT     = 0o604 # shifted exit key
    KEY_SFIND     = 0o605 # shifted find key
    KEY_SHELP     = 0o606 # shifted help key
    KEY_SHOME     = 0o607 # shifted home key
    KEY_SIC       = 0o610 # shifted insert-character key
    KEY_SLEFT     = 0o611 # shifted left-arrow key
    KEY_SMESSAGE  = 0o612 # shifted message key
    KEY_SMOVE     = 0o613 # shifted move key
    KEY_SNEXT     = 0o614 # shifted next key
    KEY_SOPTIONS  = 0o615 # shifted options key
    KEY_SPREVIOUS = 0o616 # shifted previous key
    KEY_SPRINT    = 0o617 # shifted print key
    KEY_SREDO     = 0o620 # shifted redo key
    KEY_SREPLACE  = 0o621 # shifted replace key
    KEY_SRIGHT    = 0o622 # shifted right-arrow key
    KEY_SRSUME    = 0o623 # shifted resume key
    KEY_SSAVE     = 0o624 # shifted save key
    KEY_SSUSPEND  = 0o625 # shifted suspend key
    KEY_SUNDO     = 0o626 # shifted undo key
    KEY_SUSPEND   = 0o627 # suspend key
    KEY_UNDO      = 0o630 # undo key
    KEY_MOUSE     = 0o631 # Mouse event has occurred
    KEY_RESIZE    = 0o632 # Terminal resize event
    KEY_MAX       = 0o777 # Maximum key value is 0632

    # My own set of keys
    KEY_FS_CHANGE = 0o700 # Filesystem change occurred
  end

  fun initscr
  fun keypad(scr : Screen, flag : Bool)
  fun nonl
  fun cbreak
  fun noecho
  fun nodelay(scr : Screen, flag : Bool)
  fun timeout(LibC::Int)
  fun werase(Screen)
  fun wrefresh(Screen)
  fun endwin(Screen)

  fun has_colors
  fun start_color
  fun curs_set(LibC::Int)
  fun init_extended_color(ColorPair, LibC::Int, LibC::Int, LibC::Int)
  fun init_extended_pair(ColorPair, LibC::Int, LibC::Int)
  fun wbkgd(Screen, ColorPair)
  fun wbkgdset(Screen, ColorPair)
  fun COLOR_PAIR(LibC::Int) : ColorPair
  fun attron(LibC::Int)
  fun attroff(LibC::Int)
  fun putp(Pointer(LibC::Char))

  fun wgetch(Screen) : Char
  fun ungetch(LibC::Int)
  fun getmaxx(Screen) : UInt8
  fun getmaxy(Screen) : UInt8
  fun printw(string : Pointer(UInt8))

  fun getmouse(event : Pointer(MouseEvent))
  fun mousemask(LibC::Int, Pointer(Void))
end

module Curses
  extend self

  @@colors = Hash(Int32, Int32).new

  enum Color
    None
    Background
    Command
    Regular
    Directory
    Cursor
  end

  enum Cursor
    Invisible = 0
    Regular   = 1
    Visible   = 2
  end

  module MouseButton
    extend self

    private def mouse_mask(m, b)
      m << ((b - 1) * 5)
    end

    BUTTON1_PRESSED  =       2
    BUTTON1_RELEASED =       1
    BUTTON2_PRESSED  =    2048
    BUTTON2_RELEASED =    1024
    SCROLL_UP        =   65536
    SCROLL_DOWN      = 2097152
    ALL_MOUSE_EVENTS =      -1
  end

  def mousemask(mask)
    LibNcurses.mousemask(mask, nil)
  end

  def putp(string)
    LibNcurses.putp(string.dup.to_unsafe)
  end

  def set_title(title)
    # putp("\x1b]0;#{title}\x07")
    :ok
  end

  def getmouse
    LibNcurses.getmouse(out mouse_event)
    mouse_event
  end

  def curs_set(mode : Cursor)
    LibNcurses.curs_set(mode.value)
  end

  def curs_set(mode : Int)
    LibNcurses.curs_set(mode.to_i32)
  end

  def color(i)
    if id = @@colors[i]?
      id
    else
      id = @@colors.size + 1
      rgb(id, i)
      @@colors[i] = id
      id
    end
  end

  private def do_color(i)
    ((i * 1000) / 255).round + 1
  end

  def rgb(index, rgb)
    b = rgb.remainder(256)
    rg = rgb // 256
    g = rg.remainder(256)
    r = rg // 256
    LibNcurses.init_extended_color(index, do_color(r), do_color(g), do_color(b))
  end

  def printw(string : String)
    LibNcurses.printw(string.dup.to_unsafe)
  end

  def erase
    LibNcurses.werase(LibNcurses.stdscr)
  end

  def xmax
    LibNcurses.getmaxx(LibNcurses.stdscr).to_i32
  end

  def ymax
    LibNcurses.getmaxy(LibNcurses.stdscr).to_i32
  end

  def init
    LibC.setlocale(LibC::LC_ALL, "".dup.to_unsafe)

    LibNcurses.initscr
    LibNcurses.timeout(100)
    LibNcurses.start_color

    LibNcurses.init_extended_pair(Color::Background, color(0x1a1a21), color(0x1a1a21))
    LibNcurses.init_extended_pair(Color::Command, color(0xb4b4b9), color(0x28282d))
    LibNcurses.init_extended_pair(Color::Regular, color(0xb4b4b9), color(0x1a1a21))
    LibNcurses.init_extended_pair(Color::Directory, color(0x99a4bc), color(0x1a1a21))
    LibNcurses.init_extended_pair(Color::Cursor, color(0x1a1a21), color(0x99a4bc))
    LibNcurses.wbkgd(LibNcurses.stdscr, pair(Color::Background))

    LibNcurses.keypad(LibNcurses.stdscr, true)
    LibNcurses.cbreak
    LibNcurses.noecho
    LibNcurses.nonl
    LibNcurses.wbkgd(LibNcurses.stdscr, pair(Color::Background))
    set_title("tcr///")
    mousemask(MouseButton::ALL_MOUSE_EVENTS)
  end

  def stop
    LibNcurses.endwin(LibNcurses.stdscr)
  end

  def screen
    LibNcurses.stdscr
  end

  def ungetch(key : LibNcurses::Keys)
    LibNcurses.ungetch(key.value)
  end

  def pair(color : Color)
    LibNcurses.COLOR_PAIR(color)
  end

  def withattr(attr, &)
    LibNcurses.attron(attr)
    yield
    LibNcurses.attroff(attr)
  end
end
