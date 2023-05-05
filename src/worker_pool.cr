require "log"

class WorkerPool
  Log = ::Log.for(self)
  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}

  def initialize(@size, @same_thread = true, @tracking = true)
    capacity = @size // 3
    capacity = 1 if capacity <= 0

    @pool = Channel(Proc(Nil)).new(capacity)

    if tracking?
      size.times { tracked_fiber }
    else
      size.times { performance_fiber }
    end
  end

  # number of fibers in the pool
  getter size : Int32

  # number of fibers currently available
  getter available : Int32 = 0

  # are fibers all running on the same thread?
  getter? same_thread : Bool

  # are we tracking fiber usage
  getter? tracking : Bool

  @mutex = Mutex.new
  @pool : Channel(Proc(Nil))

  # is the fiber pool running
  def running?
    !@pool.closed?
  end

  # is there an available fiber or would we block waiting for a fiber
  def would_block?
    available == 0
  end

  protected def tracked_fiber
    spawn(same_thread: @same_thread) do
      loop do
        begin
          @mutex.synchronize { @available += 1 }
          proc = @pool.receive
          @mutex.synchronize { @available -= 1 }
          proc.call
        rescue error : Channel::ClosedError
          break if @pool.closed?
          handle_error(error)
        rescue error
          handle_error(error)
        end
      end
    end
  end

  protected def performance_fiber
    spawn(same_thread: @same_thread) do
      loop do
        begin
          @pool.receive.call
        rescue error : Channel::ClosedError
          break if @pool.closed?
          handle_error(error)
        rescue error
          handle_error(error)
        end
      end
    end
  end

  protected def handle_error(error)
    Log.error(exception: error) { "unhandled exception in fiber pool" }
  end

  # perform a task using the pool
  def perform(&block : Proc(Nil))
    @pool.send(block)
  end

  # blocks until all the fibers complete if tracking
  def stop
    return unless running?

    @pool.close

    if tracking?
      while available != size
        Fiber.yield
      end
    end
  end

  # ensure the fibers complete if the pool goes out of scope
  def finalize
    return unless running?
    @pool.close
  end
end
