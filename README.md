# worker_pool

Allocates a fixed pool of fibers for performing work.
This reduces the overhead of allocating stacks and helps limit memory usage.

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

10_000.times do
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

- [Stephen von Takach](https://github.com/stakach) - creator and maintainer
