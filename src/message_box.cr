# Message box like in erlang
# Sorry, I am not used to Crystal's ipc primitives and Channel was blocking

class MessageBox(T)
  @lock = Mutex.new
  @queue = [] of T

  def send(message : T)
    @lock.lock
    @queue.push(message)
    @lock.unlock
  end

  def take
    @lock.lock
    result = @queue.dup
    @queue = [] of T
    @lock.unlock
    result
  end

  def receive
    @lock.lock
    if @queue.size == 0
      @lock.unlock
      nil
    else
      result = @queue.pop
      @lock.unlock
      result
    end
  end
end
