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
      output_folder = APP_CONFIG['output_folder']
      Dir.mkdir(output_folder) if not Dir.exists?(output_folder)

      if @worker.status != AbfWorker::BaseWorker::BUILD_CANCELED
        prepare_script
        exit_status = nil
        final_command = 'cd ' + ENV['HOME'] + '/iso_builder;' + @params + ' ABF=1 /bin/bash ' + @command
        process = IO.popen(final_command, 'r', :err=>[:child, :out]) do |io|
          while true
            begin
              break if io.eof
              line = io.gets
              puts line
              @worker.logger.log(line)
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
      end
    end

    private

    def save_results
      command = "cd #{ENV['HOME']}/iso_builder;"\
                "tar -zcvf ../output/archives.tar.gz archives;"\
                "sudo mv results/* ../output;"\
                "cd ..;"\
                "sudo rm -rf iso_builder"
      system command
    end

    def prepare_script
      file_name = @srcpath.match(/archive\/(.*)/)[1]
      folder_name = @srcpath.match(/.*\/(.*)\/archive/)[1]
      branch = file_name.gsub('.tar.gz', '')

      command = "cd #{ENV['HOME']};"\
                "curl -O -L #{@srcpath};"\
                "tar -zxf #{file_name};"\
                "mv #{folder_name}-#{branch} iso_builder;"\
                "rm -rf #{file_name}"
      system command
    end

  end
end
