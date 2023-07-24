require "log"

# a pool of fibers ready to execute tasks
# there is no bound on growth so long running tasks like websockets
# can run without starving other tasks. The aim of this pool is to
# reduce the impact of fiber allocation to a typical workload
class WorkerPool
  Log = ::Log.for(self)
  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}

  def initialize(@initial_size, @reap_period : Time::Span = 15.seconds)
    @size = @initial_size
    @work = Channel(Proc(Nil)).new(1)
    @workers = Array(Fiber).new(@size) { Fiber.new { worker_loop } }

    {% if flag?(:preview_mt) %}
      spawn(same_thread: true) { allocater_loop }
    {% end %}
    spawn(same_thread: true) { reaper }
  end

  # number of fibers in the pool
  getter size : Int32
  getter initial_size : Int32

  # the work being allocated to the worker loop
  @current_work : Proc(Nil)? = nil

  # a worker fiber
  private def worker_loop
    worker_fiber = Fiber.current
    work_channel = @work
    workers = @workers

    loop do
      begin
        # look for any current work
        if work = @current_work
          @current_work = nil
          work.call
        else # we are discarding this fiber
          break
        end
      rescue error
        handle_error(error)
      end

      break if work_channel.closed?
      workers << worker_fiber
      sleep
    end
  end

  # the fiber that allocates work to fibers
  private def allocater_loop
    allocater_fiber = Fiber.current
    work_channel = @work
    workers = @workers

    loop do
      begin
        proc = work_channel.receive
        @current_work = proc
        allocater_fiber.enqueue
        workers.pop {
          @size += 1
          Fiber.new { worker_loop }
        }.resume
      rescue error : Channel::ClosedError
        break if work_channel.closed?
        handle_error(error)
      rescue error
        handle_error(error)
      end
    end
  end

  # the pool will resize to handle load, this cleans up fibers
  # once load has subsided
  private def reaper
    sleep_for = @reap_period
    reaper_fiber = Fiber.current
    work_channel = @work
    workers = @workers

    # we will accept a 10% buffer over initial size
    buffer_size = @initial_size // 10
    buffer_size = 1 if buffer_size == 0

    ignore_size = initial_size + buffer_size

    # 20% over capacity is our breakpoint
    breakpoint = buffer_size * 2

    loop do
      sleep sleep_for
      break if work_channel.closed?
      next if ignore_size >= @size

      # we'll reduce the pool size by 10%
      if available >= breakpoint
        @size -= buffer_size
        reaping = workers.pop(buffer_size)
        reaping.each do |worker_fiber|
          reaper_fiber.enqueue
          worker_fiber.resume
        end
      end
    end

    # cleanup when channel closed
    workers.each do |worker_fiber|
      reaper_fiber.enqueue
      worker_fiber.resume
    end
  end

  protected def handle_error(error)
    Log.error(exception: error) { "unhandled exception in fiber pool" }
  end

  # number of workers waiting to be allocated work
  def available
    @workers.size
  end

  # is the fiber pool running
  def running?
    !@work.closed?
  end

  {% begin %}
    # perform a task using the pool
    def perform(&block : Proc(Nil))
      {% if flag?(:preview_mt) %}
        @work.send(block)
      {% else %}
        @current_work = block
        Fiber.current.enqueue
        @workers.pop {
          @size += 1
          Fiber.new { worker_loop }
        }.resume
      {% end %}
    end
  {% end %}

  # fibers are discarded once they complete and no new work will be accepted
  def close
    return unless running?
    @work.close
  end

  # ensure the fibers complete if the pool goes out of scope
  def finalize
    return unless running?
    @work.close
  end
end
