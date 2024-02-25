@[Link("readline")]
lib LibReadline
  @[Raises]
  fun rl_callback_handler_install(Pointer(LibC::Char), f : Pointer(LibC::Char) -> Void)

  @[Raises]
  fun rl_callback_read_char

  fun rl_callback_handler_remove

  fun rl_parse_and_bind(Pointer(LibC::Char))

  $rl_catch_signals : LibC::Int
  $rl_catch_sigwinch : LibC::Int
  $rl_deprep_term_function : Pointer(Void)
  $rl_prep_term_function : Pointer(Void)
  $rl_change_environment : LibC::Int

  $rl_display_prompt : Pointer(LibC::Char)
  $rl_line_buffer : Pointer(LibC::Char)

  $rl_getc_function : Pointer(Void) -> LibC::Char
  $rl_input_available_hook : Void -> LibC::Int
  $rl_redisplay_function : Void -> Void

  $rl_point : LibC::Int
  $rl_end : LibC::Int
end

module Readline
  extend self

  @@input_avail : LibC::Int
  @@input_avail = 0

  @@input : LibC::Char
  @@input = 0.to_u8!

  def init(prompt, redisplay_hook, input_hook)
    configuration = %(
      set editing-mode emacs
    )

    readline_input_avail = ->(void : Void) { @@input_avail }

    readline_getc = ->(void : Pointer(Void)) { @@input_avail = 0; @@input }
    readline_redisplay = redisplay_hook
    readline_input_hook = input_hook

    LibReadline.rl_catch_signals = 0
    LibReadline.rl_catch_sigwinch = 0
    LibReadline.rl_deprep_term_function = nil
    LibReadline.rl_prep_term_function = nil
    LibReadline.rl_change_environment = 0
    LibReadline.rl_getc_function = readline_getc
    LibReadline.rl_input_available_hook = readline_input_avail
    LibReadline.rl_redisplay_function = readline_redisplay
    LibReadline.rl_callback_handler_install(prompt.dup.to_unsafe, readline_input_hook)
    parse_and_bind(configuration)
  end

  def parse_and_bind(configuration)
    LibReadline.rl_parse_and_bind(configuration.to_slice.clone.to_unsafe)
  end

  def deinit
    LibReadline.rl_callback_handler_remove
  end

  def forward_char(int : Int)
    forward_char(int.chr)
  end

  def forward_char(char : Char)
    @@input_avail = 1
    @@input = char.ord.to_u8!
    LibReadline.rl_callback_read_char
  end

  def display_prompt
    dp = LibReadline.rl_display_prompt
    if dp
      String.new(dp).dup
    end
  end

  def line_buffer
    lb = LibReadline.rl_line_buffer
    if lb
      String.new(lb).dup
    end
  end
end
