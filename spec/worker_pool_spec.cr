require "./spec_helper"

describe WorkerPool do
  it "works in tracking mode" do
    pool = WorkerPool.new(2, tracking: true)

    pool.running?.should be_true
    pool.size.should eq 2
    pool.available.should eq 0
    pool.would_block?.should be_true

    Fiber.yield

    pool.running?.should be_true
    pool.size.should eq 2
    pool.available.should eq 2
    pool.would_block?.should be_false

    task_1 = false
    pool.perform do
      sleep 1
      task_1 = true
    end
    Fiber.yield

    pool.available.should eq 1
    pool.would_block?.should be_false

    task_2 = false
    pool.perform do
      sleep 1
      task_2 = true
    end
    Fiber.yield

    pool.available.should eq 0
    pool.would_block?.should be_true

    # task 3 will block until a fiber is available
    task_3 = false
    pool.perform { task_3 = true }
    pool.stop

    task_1.should be_true
    task_2.should be_true
    task_3.should be_true
  end

  it "works in performance mode" do
    pool = WorkerPool.new(2, tracking: false)

    pool.running?.should be_true
    pool.size.should eq 2
    pool.available.should eq 0
    pool.would_block?.should be_true

    Fiber.yield

    pool.running?.should be_true
    pool.size.should eq 2
    pool.available.should eq 0
    pool.would_block?.should be_true

    task_1 = false
    pool.perform do
      sleep 1
      task_1 = true
    end
    Fiber.yield

    task_2 = false
    pool.perform do
      sleep 1
      task_2 = true
    end
    Fiber.yield

    task_3 = false
    pool.perform { task_3 = true }
    pool.stop

    # stop in untracked doesn't wait for completion
    task_1.should be_false
    task_2.should be_false
    task_3.should be_false
  end

  it "waits for running tasks to complete in tracking mode" do
    pool = WorkerPool.new(2, tracking: true)

    task_1 = false
    pool.perform do
      sleep 1
      task_1 = true
    end
    Fiber.yield

    task_2 = false
    pool.perform do
      sleep 1
      task_2 = true
    end

    task_3 = false
    pool.perform do
      sleep 1
      task_3 = true
    end

    task_1.should be_false
    task_2.should be_false
    task_3.should be_false
    pool.stop
    task_1.should be_true
    task_2.should be_true
    task_3.should be_true
  end

  it "handles errors" do
    pool = WorkerPool.new(1)
    pool.perform { raise "testing error" }

    task_1 = false
    pool.perform { task_1 = true }
    Fiber.yield

    task_1.should be_true
  end
end
