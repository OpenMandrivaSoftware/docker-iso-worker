require 'abf-worker/runners/iso'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class IsoWorker < BaseWorker
    @queue = :iso_worker

    attr_accessor :runner

    def self.perform(options)
      self.new(options).perform
    end

    def logger
      @logger
    end

    protected

    def initialize(options)
      @observer_queue       = 'iso_worker_observer'
      @observer_class       = 'AbfWorker::IsoWorkerObserver'
      super options
      @runner = AbfWorker::Runners::IsoRunner.new(self, options)
      init_live_logger("abfworker::iso-worker-#{@build_id}")
      initialize_live_inspector(options['time_living'])
    end

    def send_results
      update_build_status_on_abf({
        results: upload_results_to_file_store,
        exit_status: @runner.exit_status
      })
    end

  end

end
