module AbfWorker::Runners
  class IsoRunner

    attr_accessor :exit_status

    def initialize(worker, options)
      @worker       = worker
      @params       = options['params']
      @srcpath      = options['srcpath']
      @command      = options['main_script']
    end

    def run_script()
      puts "Run " + @command

      if @worker.status != AbfWorker::BaseWorker::BUILD_CANCELED
        prepare_script
        exit_status = nil
        final_command = 'cd ' + ENV['HOME'] + '/iso_builder; sudo ' + @params + ' ABF=1 /bin/bash ' + @command
        process = IO.popen(final_command, 'r', :err=>[:child, :out]) do |io|
          while true
            begin
              break if io.eof
              line = io.gets
              puts line
              @worker.live_logger.log(line)
              @worker.file_logger.log(line)
            rescue => e
              break
            end
          end
          Process.wait(io.pid)
          @exit_status = $?.exitstatus
        end
        if @worker.status != AbfWorker::BaseWorker::BUILD_CANCELED
          if @exit_status.nil? or @exit_status != 0
            @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
          else
            @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
          end
          save_results
        end
	system "sudo rm -rf #{ENV['HOME']}/iso_builder"
      end
    end

    private

    def save_results
      command = "cd #{ENV['HOME']}/iso_builder;"\
                "sudo mv results/* ../output;"
      system command
    end

    def prepare_script
      file_name = @srcpath.match(/archive\/(.*)/)[1]
      folder_name = @srcpath.match(/.*\/(.*)\/archive/)[1]
      branch = file_name.gsub('.tar.gz', '')

      command = "cd #{ENV['HOME']};"\
                "curl -O -L #{@srcpath};"\
                "tar -zxf #{file_name};"\
                "sudo rm -rf iso_builder;"\
                "mv #{folder_name}-#{branch} iso_builder;"\
                "rm -rf #{file_name}"
      system command
    end

  end
end
