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

  describe "#detect" do
    it "calls the provided block for every line outputted, and returns the first non-false value" do
      process = BackgroundProcess.run("bash -c 'a=0; while sleep 0.1; do a=$(($a + 1)); echo $a; done'")
      result = process.detect do |line|
        "golden" if line.strip == "3"
      end
      result.should == "golden"
      process.kill
    end

    it "yields the stream if two parameters are provided on the block" do
      process = BackgroundProcess.run("bash -c 'a=0; while sleep 0.1; do a=$(($a + 1)); echo $a 1>&2; done'")
      result = process.detect(:both, 1) do |stream, line|
        "golden" if stream == process.stderr && line.strip == "3"
      end
      result.should == "golden"
      process.kill
    end

    it "aborts if the provided timeout is reached" do
      process = BackgroundProcess.run("sleep 2")
      result = process.detect(:both, 0.1) do |stream, line|
        true
      end
      result.should be_nil
      process.kill
    end

    it "monitors the specified stream" do
      process = BackgroundProcess.run("bash -c 'a=0; while sleep 0.1; do a=$(($a + 1)); echo $a; echo $a 1>&2; done'")
      output = []
      process.detect(:stdout) do |line|
        output << line.to_i
        true if line.to_i == 3
      end

      process.detect(:stderr) do |line|
        output << line.to_i
        true if line.to_i == 3
      end

      output.should == [1, 2, 3, 1, 2, 3]
    end

    it "never yields if nothing occurs on specified streams" do
      process = BackgroundProcess.run("bash -c 'a=0; while sleep 0.1; do a=$(($a + 1)); echo $a; done'")
      process.detect(:stderr, 1) do |line|
        raise(Spec::Expectations::ExpectationNotMetError, "expected to not yield the block")
      end
    end

    it "quits when the process does" do
      process = BackgroundProcess.run("sleep 0.3")
      started_waiting = Time.now
      result = process.detect(:both, 1) do |line|
        line.should_not be_nil
      end
      result.should be_nil
      (Time.now - started_waiting).should < 0.4
    end

    it "yields the very last bit of the process output" do
      process = BackgroundProcess.run("echo hello; printf hi")
      process.detect(:both, 1) { |line| line == "hi" }.should == true
    end
  end
end
