require 'spec_helper'

describe BackgroundProcess::IOHelpers do
  describe "#detect" do
    it "iterates over the lines from each stream as they are available, and returns when a non-false value is reached" do
      process = BackgroundProcess.run("bash -c 'a=0; while sleep 0.1; do a=$(($a + 1)); echo $a; echo $a 1>&2; done'")
      outputs = {:out => [], :err => []}

      result = BackgroundProcess::IOHelpers.detect([process.stderr, process.stdout], 1) do |io, line|
        outputs[io == process.stderr ? :err : :out] << line.to_i
        true if outputs.values.map {|o| o.length }.uniq == [5]
      end
      outputs[:out].should == (1..5).to_a
      outputs[:err].should == (1..5).to_a
      result.should be_true
    end

    it "gives up after the timeout is reached" do
      process = BackgroundProcess.run("bash -c 'sleep 2; echo done'")
      started_at = Time.now

      result = BackgroundProcess::IOHelpers.detect([process.stderr, process.stdout], 0.5) do |io, line|
        true if line.strip == "done"
      end
      result.should be_nil
      (Time.now - started_at).should < 0.6
      process.kill
    end
  end
end
