require "./spec_helper"

describe WorkerPool do
  it "works" do
    pool = WorkerPool.new(2)
    pool.running?.should be_true
    pool.size.should eq 2
    pool.available.should eq 2

    task_1 = false
    pool.perform do
      sleep 1
      task_1 = true
    end
    Fiber.yield

    pool.available.should eq 1

    task_2 = false
    pool.perform do
      sleep 1
      task_2 = true
    end
    Fiber.yield

    pool.available.should eq 0

    # task 3 will create a new fiber
    task_3 = false
    pool.perform { task_3 = true }
    sleep 1.2

    pool.size.should eq 3
    pool.available.should eq 3
    pool.initial_size.should eq 2

    pool.close
    task_1.should be_true
    task_2.should be_true
    task_3.should be_true
  end

  it "handles errors" do
    pool = WorkerPool.new(1)
    pool.perform { raise "testing error handler" }
    sleep 0.2

    task_1 = false
    pool.perform { task_1 = true }
    Fiber.yield

    task_1.should be_true
    pool.size.should eq 1
    pool.close
  end

  it "reaps excess workers" do
    pool = WorkerPool.new(1, reap_period: 2.second)
    pool.perform { sleep 1 }
    pool.perform { sleep 1 }
    pool.perform { sleep 1 }
    pool.perform { sleep 1 }

    sleep 0.2

    pool.size.should eq 4
    pool.available.should eq 0
    pool.initial_size.should eq 1

    sleep 2

    pool.size.should eq 3
    pool.available.should eq 3
    pool.initial_size.should eq 1

    sleep 2

    pool.size.should eq 2
    pool.available.should eq 2
    pool.initial_size.should eq 1

    sleep 2

    pool.size.should eq 2
    pool.available.should eq 2
    pool.initial_size.should eq 1

    pool.close
  end
end
