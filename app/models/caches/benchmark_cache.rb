# frozen_string_literal: true

module Caches
  # This class provides methods to benchmark the execution time of a block of code.
  # It caches the start time, end time, and elapsed time using thread-local variables.
  class BenchmarkCache
    # Benchmarks the execution time of a block of code and returns the elapsed time.
    # Purges the cached values after the block execution.
    #
    # @yield The block of code to benchmark.
    # @return [Float] The elapsed time in seconds.
    def self.with_benchmark(&block)
      benchmark(&block)
      elapsed_time = process_elapsed_time
      purge!
      elapsed_time
    end

    # Benchmarks the execution time of a block of code.
    # Caches the start time, end time, and elapsed time.
    #
    # @yield The block of code to benchmark.
    # @return [void]
    def self.benchmark
      cache_start_time
      yield
      cache_end_time
      cache_elapsed_time
    end

    # Caches the start time of the benchmark.
    #
    # @return [void]
    def self.cache_start_time
      Thread.current[:__benchmark_start_time] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Caches the end time of the benchmark.
    #
    # @return [void]
    def self.cache_end_time
      Thread.current[:__benchmark_end_time] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Caches the elapsed time of the benchmark.
    #
    # @return [void]
    def self.cache_elapsed_time
      Thread.current[:__benchmark_elapsed_time] = Thread.current[:__benchmark_end_time] - Thread.current[:__benchmark_start_time]
    end

    # Purges the cached start time, end time, and elapsed time.
    #
    # @return [void]
    def self.purge!
      Thread.current[:__benchmark_start_time] = nil
      Thread.current[:__benchmark_end_time] = nil
      Thread.current[:__benchmark_elapsed_time] = nil
    end

    # Returns the cached elapsed time of the benchmark.
    #
    # @return [Float, nil] The elapsed time in seconds, or nil if not cached.
    def self.process_elapsed_time
      Thread.current[:__benchmark_elapsed_time]
    end

    private_class_method :benchmark, :cache_start_time, :cache_end_time, :cache_elapsed_time, :purge!, :process_elapsed_time
  end
end
