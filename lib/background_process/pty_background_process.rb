require 'pty'

class PTYBackgroundProcess < BackgroundProcess
  # Runs a subprocess in a pseudo terminal, tricking a program into not
  # buffering its output.
  #
  # A great write up on pseudo-terminals here:
  # http://stackoverflow.com/questions/1154846/continuously-read-from-stdout-of-external-process-in-ruby
  #
  # It has the following disadvantages:
  # * You can't get the exit status
  # * When the process dies, whatever output you haven't read yet is lost.
  # * stderr is merged into stdout
  def self.run(*command_with_args)
    command = sanitize_command(command_with_args)
    thread = Thread.new do # why run PTY separate thread? When a PTY instance
                           # dies, it raises PTY::ChildExited on the thread that
                           # spawned it, interrupting whatever happens to be
                           # running at the time
      PTY.spawn(command) do |output, input, pid|
        begin
          bp = new(pid, input, output)
          Thread.current[:background_process] = bp
          bp.wait
        rescue Exception => e
          puts e
          puts e.backtrace
        end
      end
    end
    sleep 0.01 until thread[:background_process]
    thread[:background_process]
  end

  def stderr
    raise ArgumentError, "stderr is merged into stdout with PTY subprocesses"
  end

  def wait(timeout = nil)
    begin
      Timeout.timeout(timeout) do
        Process.wait(@pid)
      end
    rescue Timeout::Error
      nil
    rescue PTY::ChildExited
      true
    rescue Errno::ECHILD
      true
    end
  end

  def exitstatus
    raise ArgumentError, "exitstatus is not available for PTY subprocesses"
  end

protected
  def select_streams(which)
    case which
    when :stderr        then stderr # let stderr throw the exception
    when :stdout, :both then [stdout]
    else raise(ArgumentError, "invalid stream specification: #{which}")
    end.compact
  end
end