# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Caches::BenchmarkCache, type: :model do
  describe '.with_benchmark' do
    it 'returns the elapsed time and resets the cached values' do
      elapsed_time = described_class.with_benchmark { sleep(0.1) }
      expect(elapsed_time).to be_within(0.01).of(0.1)
      expect(Thread.current[:__benchmark_start_time]).to be_nil
      expect(Thread.current[:__benchmark_end_time]).to be_nil
      expect(Thread.current[:__benchmark_elapsed_time]).to be_nil
    end
  end
end
