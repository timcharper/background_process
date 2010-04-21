require 'spec_helper'

describe BackgroundProcess do
  describe ".run" do
    it "runs a command and returns a background process with properly attached IO pipes" do
      process = BackgroundProcess.run("printf 'hi'")
      process.stdout.readline.should == "hi"

      process = BackgroundProcess.run("printf 'hi' 1>&2")
      process.stderr.readline.should == "hi"

      process = BackgroundProcess.run(%(sh -c 'read hi; printf "$hi"'))
      process.stdin.puts "hello, world"
      process.stdin.flush
      process.stdout.readline.should == "hello, world"
    end

    it "accepts an array, and properly handles spaces" do
      process = BackgroundProcess.run(['sh', '-c', 'printf hi'])
      process.stdout.readline.should == "hi"
    end
  end

  describe "#running?" do
    it "reports when the process is running" do
      process = BackgroundProcess.run("sleep 0.1")
      process.should be_running
      process.wait
      sleep 0.1
      process.should_not be_running
    end
  end

  describe "#kill" do
    it "kills a process" do
      started_at = Time.now
      process = BackgroundProcess.run("sleep 4")
      sleep(0.1)
      process.kill("KILL")
      process.wait
      (Time.now - started_at).should < 4.0
      process.should_not be_running
    end
  end

  describe "#exitstatus" do
    it "returns the exit status of a process after it exits." do
      process = BackgroundProcess.run("bash -c 'sleep 1; exit 1'")
      process.exitstatus.should == 1
      process.exitstatus.should == 1
    end
  end

  describe "#wait" do
    it "waits for a process with timeout" do
      process = BackgroundProcess.run("sleep 3")
      started_waiting = Time.now
      process.wait(0.5).should be_false
      (Time.now - started_waiting).should be_close(0.5, 0.1)
    end
  end
end
