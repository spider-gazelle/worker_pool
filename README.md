# worker_pool

Allocates a minimum number fibers for performing work

* grows and shrinks the pool as required
* reduces the overhead of allocating stacks for repetitive, bursty, work
* handles long running tasks like websockets

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     worker_pool:
       github: spider-gazelle/worker_pool
   ```

2. Run `shards install`

## Usage

```crystal
require "worker_pool"

pool = WorkerPool.new(100)

100.times do
  pool.perform { my_task }
end
```

## Contributing

1. Fork it (<https://github.com/spider-gazelle/worker_pool/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

* [Stephen von Takach](https://github.com/stakach) - creator and maintainer
