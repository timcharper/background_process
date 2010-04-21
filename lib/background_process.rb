class BackgroundProcess
  attr_reader :stdin, :stdout, :stderr, :pid

  # Initialize a BackgroundProcess task. Don't do this.  Use BackgroundProcess.run instead
  def initialize(pid, stdin, stdout, stderr)
    @pid, @stdin, @stdout, @stderr = pid, stdin, stdout, stderr
    ObjectSpace.define_finalizer(self) { kill }
  end

	# Run a BackgroundProcess
  def self.run(command)
    command = sanitize_params(command) if command.is_a?(Array)
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

  protected
  # It's protected. What do you care? :P
  def self.sanitize_params(params)
    params.map { |p| p.gsub(' ', '\ ') }.join(" ")
  end
end
