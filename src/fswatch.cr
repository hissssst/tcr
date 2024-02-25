# FSWatch binding

@[Link("fswatch")]
lib LibFSWatch
  alias FSW_STATUS = LibC::Int
  alias FSW_HANDLE = Pointer(Void)

  # void (fsw_cevent const *const events, const unsigned int event_num, void *data);
  alias FSW_CEVENT_CALLBACK = (Pointer(FSW_CEVENT), LibC::Int, Void*) -> Void

  # typedef struct fsw_cevent
  # {
  #   char * path;
  #   time_t evt_time;
  #   enum fsw_event_flag * flags;
  #   unsigned int flags_num;
  # } fsw_cevent;
  struct FSW_CEVENT
    path : LibC::Char*
    evt_time : LibC::Int
    flags : Pointer(LibC::Int)
    flags_num : LibC::Int
  end

  # typedef struct fsw_event_type_filter
  # {
  #   enum fsw_event_flag flag;
  # } fsw_event_type_filter;
  struct FSW_EVENT_TYPE_FILTER
    flag : LibC::Int
  end

  # typedef struct fsw_cmonitor_filter
  # {
  #   char * text;
  #   enum fsw_filter_type type;
  #   bool case_sensitive;
  #   bool extended;
  # } fsw_cmonitor_filter;
  struct FSW_CMONITOR_FILTER
    text : LibC::Char*
    type : LibC::Int
    case_sensitive : Bool
    extended : Bool
  end

  fun fsw_init_library : LibC::Int
  fun fsw_init_library : FSW_STATUS
  fun fsw_init_session(LibC::Int) : FSW_HANDLE
  fun fsw_add_path(FSW_HANDLE, path : LibC::Char*) : FSW_STATUS
  fun fsw_add_property(FSW_HANDLE, name : LibC::Char*, value : LibC::Char*) : FSW_STATUS
  fun fsw_set_allow_overflow(FSW_HANDLE, allow_overflow : Bool) : FSW_STATUS
  fun fsw_set_callback(FSW_HANDLE, callback : FSW_CEVENT_CALLBACK, data : Void*) : FSW_STATUS
  fun fsw_set_latency(FSW_HANDLE, latency : LibC::Double) : FSW_STATUS
  fun fsw_set_recursive(FSW_HANDLE, recursive : Bool) : FSW_STATUS
  fun fsw_set_directory_only(FSW_HANDLE, directory_only : Bool) : FSW_STATUS
  fun fsw_set_follow_symlinks(FSW_HANDLE, follow_symlinks : Bool) : FSW_STATUS
  fun fsw_add_event_type_filter(FSW_HANDLE, event_type : FSW_EVENT_TYPE_FILTER) : FSW_STATUS
  fun fsw_add_filter(FSW_HANDLE, filter : FSW_CMONITOR_FILTER) : FSW_STATUS
  fun fsw_start_monitor(FSW_HANDLE) : FSW_STATUS
  fun fsw_stop_monitor(FSW_HANDLE) : FSW_STATUS
  fun fsw_is_running(FSW_HANDLE) : Bool
  fun fsw_destroy_session(FSW_HANDLE) : FSW_STATUS
  fun fsw_last_error : FSW_STATUS
  fun fsw_is_verbose : Bool
  fun fsw_set_verbose(verbose : Bool)
end

class FSWatch
  enum Flag : LibC::Int
    NoOp               = 0       # No event has occurred.
    PlatformSpevvcific = 1 << 0  # Platform-specific placeholder for event type that cannot currently be mapped.
    Created            = 1 << 1  # An object was created.
    Updated            = 1 << 2  # An object was updated.
    Removed            = 1 << 3  # An object was removed.
    Renamed            = 1 << 4  # An object was renamed.
    OwnerModified      = 1 << 5  # The owner of an object was modified.
    AttributeModified  = 1 << 6  # The attributes of an object were modified.
    MovedFrom          = 1 << 7  # An object was moved from this location.
    MovedTo            = 1 << 8  # An object was moved to this location.
    IsFile             = 1 << 9  # The object is a file.
    IsDir              = 1 << 10 # The object is a directory.
    IsSymLink          = 1 << 11 # The object is a symbolic link.
    Link               = 1 << 12 # The link count of an object has changed.
    Overflow           = 1 << 13 # The event queue has overflowed.
  end

  class Event
    getter path : Path
    getter time : Time
    getter flags : Array(Array(Flag))

    def initialize(event : LibFSWatch::FSW_CEVENT)
      @path = Path.new String.new event.path

      @time = Time.unix(event.evt_time)
      @flags = Array(Array(Flag)).new(event.flags_num, [] of Flag)
      (0..(event.flags_num - 1)).each do |i|
        in_event = event.flags[i]
        Flag.each do |flag|
          if flag.value & in_event != 0
            flags[i].push(flag)
          end
        end
      end
    end
  end

  @box : Pointer(Void)?
  @session : LibFSWatch::FSW_HANDLE

  def initialize
    if LibFSWatch.fsw_init_library != 0
      raise "FSWatch init failed"
    end
    @session = LibFSWatch.fsw_init_session(0)
  end

  def finalize
    LibFSWatch.fsw_stop_monitor(@session)
    check LibFSWatch.fsw_destroy_session(@session)
  end

  def start_monitor
    check LibFSWatch.fsw_start_monitor(@session)
  end

  def add_event_type_filter(flags : Enumerable(Flag))
    flags.each do |flag|
      self.add_event_type_filter(flag)
    end
  end

  def add_event_type_filter(flags : Flag)
    self.add_event_type_filter(flags.value)
  end

  def add_event_type_filter(flags : Int)
    filter = uninitialized LibFSWatch::FSW_EVENT_TYPE_FILTER
    filter.flag = flags
    check LibFSWatch.fsw_add_event_type_filter(@session, filter)
  end

  def set_callback(&callback : Event ->)
    boxed_data = Box.box(callback)
    @box = boxed_data

    ccallback = ->(events : Pointer(LibFSWatch::FSW_CEVENT), event_num : LibC::Int, data : Pointer(Void)) {
      data_as_callback = Box(typeof(callback)).unbox(data)
      if event_num > 0
        (0..(event_num - 1)).each do |i|
          data_as_callback.call(Event.new(events[i]))
        end
      end
    }

    LibFSWatch.fsw_set_callback(@session, ccallback, boxed_data)
  end

  def add_path(path : String)
    check LibFSWatch.fsw_add_path(@session, path.dup.to_unsafe)
  end

  def set_recursive(flag : Bool)
    check LibFSWatch.fsw_set_recursive(@session, flag)
  end

  private def check(result : LibC::Int)
    if result != 0
      raise "Failed with #{result}"
    end
  end
end
