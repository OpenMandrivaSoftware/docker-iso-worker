require 'abf-worker/live_logger'
require 'abf-worker/file_logger'

module AbfWorker
  class BaseWorker

    BUILD_COMPLETED = 0
    BUILD_FAILED    = 1
    BUILD_PENDING   = 2
    BUILD_STARTED   = 3
    BUILD_CANCELED  = 4
    TWO_IN_THE_TWENTIETH = 2**20

    attr_accessor :status,
                  :build_id,
                  :live_inspector

    def initialize(options)
      Thread.current[:subthreads] ||= []
      @options  = options
      @status     = BUILD_STARTED
      @build_id   = options['id']
      update_build_status_on_abf
    end

    def perform
      @runner.run_script
      send_results
      Thread.current[:subthreads].each { |thread| thread.kill }
    end

    protected

    def init_live_logger(key_name)
      @live_logger = AbfWorker::LiveLogger.new(key_name)
    end

    def init_file_logger(file_path)
      @file_logger = AbfWorker::FileLogger.new(file_path)
    end

    def initialize_live_inspector(time_living)
      @live_inspector = AbfWorker::Inspectors::LiveInspector.new(self, time_living)
      @live_inspector.run
    end

    def file_store_token
      @file_store_token ||= APP_CONFIG['file_store']['token']
    end

    def upload_file_to_file_store(path, file_name)
      path_to_file = path + '/' + file_name
      return unless File.file?(path_to_file)

      # Compress the log when file size more than 10MB
      file_size = (File.size(path_to_file).to_f / TWO_IN_THE_TWENTIETH).round(2)
      if file_name =~ /.log$/ && file_size >= 10
        system "tar -zcvf #{path_to_file}.tar.gz #{path_to_file}"
        File.delete path_to_file
        path_to_file << '.tar.gz'
        file_name << '.tar.gz'
      end

      sha1 = Digest::SHA1.file(path_to_file).hexdigest

      if %x[ curl #{APP_CONFIG['file_store']['url']}.json?hash=#{sha1} ] == '[]'
        command = 'curl --user '
        command << file_store_token
        command << ': -POST -F "file_store[file]=@'
        command << path_to_file
        command << '" '
        command << APP_CONFIG['file_store']['create_url']
        command << ' --connect-timeout 5 --retry 5'
        %x[ #{command} ]
      end

      system "sudo rm -rf #{path_to_file}"
      {:sha1 => sha1, :file_name => file_name, :size => file_size}
    end

    def upload_results_to_file_store
      uploaded = []
      results_folder = APP_CONFIG["output_folder"]
      if File.exists?(results_folder) && File.directory?(results_folder)
        Dir.new(results_folder).entries.each do |f|
          uploaded << upload_file_to_file_store(results_folder, f)
        end
      end
      uploaded.compact
    end

    def update_build_status_on_abf(args = {})
      worker_args = [{
        id:     @build_id,
        status: @status,
      }.merge(args)]

      Sidekiq::Client.push(
        'queue' => @observer_queue,
        'class' => @observer_class,
        'args'  => worker_args
      )
    end
      
  end
end
