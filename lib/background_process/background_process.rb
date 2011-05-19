class BackgroundProcess
  attr_reader :stdin, :stdout, :stderr, :pid

  # Initialize a BackgroundProcess task. Don't do this.  Use BackgroundProcess.run or BackgroundProcess.run_pty instead
  def initialize(pid, stdin, stdout, stderr = nil)
    @pid, @stdin, @stdout, @stderr = pid, stdin, stdout, stderr
    ObjectSpace.define_finalizer(self) { kill }
  end


  # Run a command, connecting it's IO streams (stdin, sterr, stdout) via IO pipes,
  # which are not tty IO streams.
  #
  # Because of this, some programs (like ruby) will buffer their output and only
  # make it available when it's explicitely flushed (with IO#flush or when the
  # buffer gets full). This behavior can be overridden by setting the streams to
  # sync, like this:
  #
  # STDOUT.sync, STDERR.sync = true, true
  #
  # If you can't control the program and have it explicitly flush its output when it
  # should, or you can't tell the streams to run in sync mode, see
  # PTYBackgroundProcess.run for a workaround.
  def self.run(*command_with_args)
    command = sanitize_command(command_with_args)
    child_stdin, parent_stdin = IO::pipe
    parent_stdout, child_stdout = IO::pipe
    parent_stderr, child_stderr = IO::pipe

    pid = Kernel.fork do
      [parent_stdin, parent_stdout, parent_stderr].each { |io| io.close }

      STDIN.reopen(child_stdin)
      STDOUT.reopen(child_stdout)
      STDERR.reopen(child_stderr)

      [child_stdin, child_stdout, child_stderr].each { |io| io.close }

      exec command
    end

    [child_stdin, child_stdout, child_stderr].each { |io| io.close }
    parent_stdin.sync = true

    new(pid, parent_stdin, parent_stdout, parent_stderr)
  end

  # send a signal to the process. If the processes and running, do nothing.
  # Valid signals are those in Signal.list. Default is "TERM"
  def kill(signal = 'TERM')
    if running?
      Process.kill(Signal.list[signal], @pid)
      true
    end
  end

  # Sends the interrupt signal to the process. The equivalent of pressing control-C in it.
  def interrupt
    kill('INT')
  end

  # asks the operating system is the process still exists.
  def running?
    return false unless @pid
    Process.getpgid(@pid)
    true
  rescue Errno::ESRCH
    false
  end

  # waits for the process to finish. Freeze the process so it can rest in peace.
  # You should call this on every background job you create to avoid a flood of
  # zombie processes. (Processes won't go away until they are waited on)
  def wait(timeout = nil)
    @exit_status ||= Timeout.timeout(timeout) do
      Process.wait(@pid)
      $?
    end
  rescue Timeout::Error
    nil
  end

  # Waits for the process to terminate, and then returns the exit status
  def exitstatus
    wait && wait.exitstatus
  end

  # Calls block each time a line is available in the specified output buffer(s) and returns the first non-false value
  # By default, both stdout and stderr are monitored.
  #
  # Args:
  # * which: which streams to monitor. valid values are :stdout, :stderr, or :both.
  # * timeout: Total time in seconds to run detect for. If result not found within this time, abort and return nil. Pass nil for no timeout.
  # * &block: the block to call.  If block takes two arguments, it will pass both the stream that received the input (an instance of IO, not the symbol), and the line read from the buffer.
  def detect(which = :both, timeout = nil, &block)
    streams = select_streams(which)
    BackgroundProcess::IOHelpers.detect(streams, timeout, &block)
  end

  protected
  # It's protected. What do you care? :P
  def self.sanitize_command(*args)
    command_and_args = args.flatten
    return command_and_args.first if command_and_args.length == 1
    command_and_args.map { |p| p.gsub(' ', '\ ') }.join(" ")
  end

  def select_streams(which)
    case which
    when :stdout then [stdout]
    when :stderr then [stderr]
    when :both   then [stdout, stderr]
    else raise(ArgumentError, "invalid stream specification: #{which}")
    end.compact
  end
end
